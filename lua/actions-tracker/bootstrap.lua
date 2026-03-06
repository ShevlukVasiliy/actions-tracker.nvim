local M = {}

function M.setup()
	local ok, sqlite = pcall(require, 'sqlite')
	if not ok then
		vim.notify(
			"[actions-tracker] Error: sqlite.lua not found.\n" ..
			"Please install 'kkharji/sqlite.lua'",
			vim.log.levels.ERROR
		)
		return
	end

	local db_path = vim.fn.stdpath('data') .. '/actions-tracker.sqlite3'

	local db = sqlite:open(db_path)
	if not db then
		vim.notify("[actions-tracker] Failed to open database at path: " .. db_path, vim.log.levels.ERROR)
		return
	end

	-- sql repo
	local SQLRepo = require('actions-tracker.infrastructure.SQLRepo')
	local sql_repo = SQLRepo:new(db)

	-- tracker
	local tracker = require("actions-tracker.presenters.tracker")
	tracker.setup(sql_repo)

	-- commands
	vim.api.nvim_create_user_command("ActionsTrackerStart", function()
		tracker.setup(sql_repo)
	end, { desc = "Start tracking Neovim actions" })

	vim.api.nvim_create_user_command("ActionsTrackerCollectMappings", function()
		sql_repo:collect_and_save_all_mappings()
	end, { desc = "Collect and save all current key mappings" })

	vim.api.nvim_create_user_command("ActionsTrackerAnalytics", function()
		local analytics = require("actions-tracker.presenters.analytics")
		analytics.show_analytics(sql_repo)
	end, { desc = "Show analytics dashboard" })

	vim.api.nvim_create_user_command("ActionsTrackerDiagnose", function()
		db:eval("SELECT sqlite_version() as ver")
	end, { desc = "Diagnose plugin issues" })
end

return M
