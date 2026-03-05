-- Bootstrap the application
local M = {}

function M.setup()
	-- Add common LuaRocks paths to package.cpath and package.path
	local home = os.getenv("HOME") or os.getenv("USERPROFILE")
	if home then
		-- Common LuaRocks paths for macOS/Linux
		local rocks_paths = {
			home .. "/.luarocks/lib/lua/5.4/?.so",
			home .. "/.luarocks/lib/lua/5.4/?.dylib",
			home .. "/.luarocks/lib/lua/5.3/?.so",
			home .. "/.luarocks/lib/lua/5.3/?.dylib",
			home .. "/.luarocks/lib/lua/5.2/?.so",
			home .. "/.luarocks/lib/lua/5.2/?.dylib",
			home .. "/.luarocks/lib/lua/5.1/?.so",
			home .. "/.luarocks/lib/lua/5.1/?.dylib",
			"/opt/homebrew/lib/lua/5.4/?.so",
			"/opt/homebrew/lib/lua/5.4/?.dylib",
			"/usr/local/lib/lua/5.4/?.so",
			"/usr/local/lib/lua/5.4/?.dylib",
		}

		for _, path in ipairs(rocks_paths) do
			if not package.cpath:find(path, 1, true) then
				package.cpath = package.cpath .. ";" .. path
			end
		end
	end

	-- Try to load lsqlite3
	local sqlite_module
	local ok

	-- First try normal require
	ok, sqlite_module = pcall(require, 'lsqlite3')

	if not ok then
		-- Try loading it directly
		vim.notify("Attempting to find lsqlite3 library...", vim.log.levels.INFO)

		-- Try package.loadlib for common names
		local libnames = { "lsqlite3", "sqlite3", "liblsqlite3", "libsqlite3" }
		local extensions = { ".so", ".dylib" }

		for _, lib in ipairs(libnames) do
			for _, ext in ipairs(extensions) do
				local fullname = lib .. ext
				local func = package.loadlib(fullname, "luaopen_lsqlite3")
				if func then
					sqlite_module = func()
					break
				end
			end
			if sqlite_module then break end
		end

		if not sqlite_module then
			vim.notify(
				"lsqlite3 not found.\n" ..
				"Please ensure it's installed with:\n" ..
				"  luarocks install lsqlite3\n" ..
				"Current package.cpath:\n" .. package.cpath,
				vim.log.levels.ERROR
			)
			return
		end
	end

	-- Load local modules
	local SQLRepo = require('actions-tracker.infrastructure.SQLRepo')
	local utils = require('actions-tracker.infrastructure.utils')

	-- Debug: print module type and keys
	print("[actions-tracker] lsqlite3 module type: " .. type(sqlite_module))
	if type(sqlite_module) == "table" then
		local keys = {}
		for k, _ in pairs(sqlite_module) do
			table.insert(keys, k)
		end
		print("[actions-tracker] module keys: " .. table.concat(keys, ", "))
	end

	-- Initialize database connection
	local db_path = vim.fn.stdpath('data') .. '/actions-tracker.sqlite3'
	local db

	-- Helper to attempt opening
	local function try_open(open_func, ...)
		if type(open_func) == "function" then
			local success, result = pcall(open_func, ...)
			if success and result then
				return result
			end
		end
		return nil
	end

	-- Attempt to open database using various patterns
	if type(sqlite_module) == "table" then
		-- Pattern 1: sqlite_module.open
		db = try_open(sqlite_module.open, db_path)
		-- Pattern 2: sqlite_module.sqlite3.open
		if not db and sqlite_module.sqlite3 then
			db = try_open(sqlite_module.sqlite3.open, db_path)
		end
		-- Pattern 3: any function in the table that returns a db when called with path
		if not db then
			for _, value in pairs(sqlite_module) do
				if type(value) == "function" then
					db = try_open(value, db_path)
					if db then break end
				end
			end
		end
	elseif type(sqlite_module) == "function" then
		-- The module itself is a function that opens a database
		db = try_open(sqlite_module, db_path)
	end

	if db then
		print("[actions-tracker] Database opened successfully")
	end

	if not db then
		vim.notify(
			"\nlsqlite3 module type: " .. type(sqlite_module) ..
			"\nPlease ensure lsqlite3 is properly installed and accessible.",
			vim.log.levels.ERROR
		)
		return
	end

	-- Create repository instance with the connection
	local sql_repo = SQLRepo:new(db)

	-- Load tracker
	local tracker = require("actions-tracker.presenters.tracker")

	-- Initialize tracker with repository
	tracker.setup(sql_repo)

	-- Provide commands for the user
	vim.api.nvim_create_user_command("ActionsTrackerStart", function()
		tracker.setup(sql_repo)
	end, { desc = "Start tracking Neovim actions" })

	vim.api.nvim_create_user_command("ActionsTrackerCollectMappings", function()
		sql_repo:collect_and_save_all_mappings()
		print("[actions-tracker] Mappings collected and saved")
	end, { desc = "Collect and save all current key mappings" })

	-- Add analytics command
	vim.api.nvim_create_user_command("ActionsTrackerAnalytics", function()
		local analytics = require("actions-tracker.presenters.analytics")
		analytics.show_analytics(sql_repo)
	end, { desc = "Show analytics dashboard" })

	-- Add a diagnostic command
	vim.api.nvim_create_user_command("ActionsTrackerDiagnose", function()
		print("=== Actions Tracker Diagnosis ===")
		print("Package.cpath:", package.cpath)
		print("Package.path:", package.path)

		-- Try to load lsqlite3
		local ok, sqlite_module = pcall(require, 'lsqlite3')
		if ok then
			print("✓ lsqlite3 loaded successfully via require")
			print("  Module type:", type(sqlite_module))
			if type(sqlite_module) == "table" then
				print("  Table contents:")
				for k, v in pairs(sqlite_module) do
					print("    " .. k .. ": " .. type(v))
				end
			end
		else
			print("✗ lsqlite3 not found via require:", sqlite_module)
		end

		-- Also test opening a database
		if ok then
			local db_path = vim.fn.stdpath('data') .. '/test-diagnostic.sqlite3'
			local db
			if type(sqlite_module) == "table" and sqlite_module.open then
				db = sqlite_module.open(db_path)
				if db then
					print("✓ Successfully opened test database")
					db:close()
					os.remove(db_path)
				else
					print("✗ Failed to open test database")
				end
			end
		end
	end, { desc = "Diagnose plugin issues" })

	print("[actions-tracker] Plugin initialized")
end

return M
