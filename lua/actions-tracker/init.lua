local actions_tracker = {}

function actions_tracker.setup()
	local project_root = vim.fn.fnamemodify(vim.fn.expand('<sfile>:p'), ':h:h')
	package.path = package.path .. ";" .. project_root .. "/lua/?.lua"

	-- Require the bootstrap module
	local ok, bootstrap = pcall(require, "actions-tracker.bootstrap")
	if not ok then
		vim.notify("Failed to load actions-tracker: " .. bootstrap, vim.log.levels.ERROR)
		return
	end

	-- Setup the plugin
	bootstrap.setup()
end

return actions_tracker
