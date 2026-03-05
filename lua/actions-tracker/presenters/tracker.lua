-- Tracker presenter to coordinate between layers
local M = {}
local event_tracker = require("actions-tracker.domain.services.event_tracker")

local function wrap_existing_mappings(sql_repo)
	local modes = { 'n', 'i', 'v', 'x', 's', 'o', 'c', 't' }

	for _, mode in ipairs(modes) do
		local mappings = vim.api.nvim_get_keymap(mode)
		for _, map in ipairs(mappings) do
			local lhs = map.lhs or ""
			local rhs = map.rhs or ""
			local opts = {
				noremap = map.noremap == 1,
				silent = map.silent == 1,
				expr = map.expr == 1,
				desc = map.desc,
			}

			-- Wrap with tracking
			local original_rhs = map.callback or rhs
			vim.keymap.set(mode, lhs, function()
				local event = event_tracker.track_binding_trigger(mode, lhs, rhs)
				sql_repo:save_binding_event(event)

				if type(original_rhs) == "function" then
					original_rhs()
				elseif type(original_rhs) == "string" and #original_rhs > 0 then
					vim.api.nvim_feedkeys(
						vim.api.nvim_replace_termcodes(original_rhs, true, false, true),
						mode,
						false
					)
				end
			end, opts)
		end
	end
end

local function hook_keymap_set(sql_repo)
	local original_set = vim.keymap.set
	vim.keymap.set = function(mode, lhs, rhs, opts)
		opts = opts or {}

		local modes = type(mode) == "table" and mode or { mode }
		for _, m in ipairs(modes) do
			local tracked_rhs
			if type(rhs) == "function" then
				tracked_rhs = function()
					local event = event_tracker.track_binding_trigger(m, lhs, tostring(rhs))
					sql_repo:save_binding_event(event)
					rhs()
				end
			else
				tracked_rhs = rhs
			end
			original_set(m, lhs, tracked_rhs, opts)
		end
	end
end

function M.start_tracking(sql_repo)
	vim.on_key(function(key)
		local mode = vim.api.nvim_get_mode().mode
		if #key > 0 then
			local event = event_tracker.track_key_press(mode, vim.fn.keytrans(key))
			sql_repo:save_key_event(event)
		end
	end)

	vim.api.nvim_create_autocmd("CmdlineLeave", {
		pattern = ":",
		callback = function()
			local cmd = vim.fn.getcmdline()
			if cmd and #cmd > 0 then
				local event = event_tracker.track_command_input(cmd)
				sql_repo:save_command_event(event)
			end
		end
	})

	wrap_existing_mappings(sql_repo)
	hook_keymap_set(sql_repo)
end

function M.collect_mappings(sql_repo)
	sql_repo:collect_and_save_all_mappings()
end

function M.setup(sql_repo)
	if not sql_repo then
		error("SQL repository is required")
	end

	M.start_tracking(sql_repo)
	M.collect_mappings(sql_repo)

	print("[actions-tracker] Tracking started")
end

return M
