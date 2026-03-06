-- Analytics presenter to display statistics
local M = {}

local function create_analytics_buffer()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "actions-tracker-analytics")
	vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
	vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
	vim.api.nvim_buf_set_option(buf, 'swapfile', false)
	return buf
end

local function render_section(buf, lines, folded)
	for _, line in ipairs(lines) do
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { line })
	end
	if folded then
		local start_line = vim.api.nvim_buf_line_count(buf) - #lines
		vim.api.nvim_buf_set_option(buf, 'foldmethod', 'marker')
		vim.api.nvim_buf_set_lines(buf, start_line, start_line, false, { '{{{' })
		vim.api.nvim_buf_set_lines(buf, start_line + #lines + 1, start_line + #lines + 1, false, { '}}}' })
	end
end

local function find_analytics_buf()
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(b)
		if name == "actions-tracker-analytics" or name:match("actions%-tracker%-analytics$") then
			return b
		end
	end
	return nil
end

local function find_buf_window(buf)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			return win
		end
	end
	return nil
end

function M.show_analytics(sql_repo)
	if not sql_repo then
		vim.notify("SQL repository not initialized", vim.log.levels.ERROR)
		return
	end

	local buf = find_analytics_buf()

	if buf then
		local win = find_buf_window(buf)
		if win then
			vim.api.nvim_set_current_win(win)
			return
		end
	else
		buf = create_analytics_buffer()
	end

	vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = math.floor(vim.o.columns * 0.8),
		height = math.floor(vim.o.lines * 0.8),
		row = math.floor(vim.o.lines * 0.1),
		col = math.floor(vim.o.columns * 0.1),
		style = 'minimal',
		border = 'rounded',
	})

	vim.api.nvim_buf_set_keymap(buf, 'n', 'za', 'za', { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', 'zR', 'zR', { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', 'zM', 'zM', { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		'# Actions Tracker Analytics',
		'',
	})
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
		'Press `za` to toggle folds, `zR` to open all, `zM` to close all, `q` to close.',
		'',
	})

	local total_keys = sql_repo:get_total_key_events()
	local total_commands = sql_repo:get_total_command_events()
	local total_bindings = sql_repo:get_total_binding_events()
	local overall_lines = {
		'',
		'## Overall Statistics',
		'',
		string.format('- Total key events: %d', total_keys),
		string.format('- Total command events: %d', total_commands),
		string.format('- Total binding events: %d', total_bindings),
		''
	}
	render_section(buf, overall_lines, false)

	local mode_stats = sql_repo:get_mode_statistics()
	local mode_lines = { '## Mode Statistics', '' }
	if #mode_stats == 0 then
		table.insert(mode_lines, 'No data available')
	else
		for _, stat in ipairs(mode_stats) do
			table.insert(mode_lines, string.format('- %s: %d events', stat.mode, stat.count))
		end
	end
	table.insert(mode_lines, '')
	render_section(buf, mode_lines, true)

	local command_stats = sql_repo:get_command_statistics()
	local command_lines = { '## Command Statistics', '' }
	if #command_stats == 0 then
		table.insert(command_lines, 'No data available')
	else
		for _, stat in ipairs(command_stats) do
			table.insert(command_lines, string.format('- %s: %d times', stat.command, stat.count))
		end
	end
	table.insert(command_lines, '')
	render_section(buf, command_lines, true)

	local binding_stats = sql_repo:get_binding_statistics()
	local binding_lines = { '## Binding Statistics', '' }
	if #binding_stats == 0 then
		table.insert(binding_lines, 'No data available')
	else
		for _, stat in ipairs(binding_stats) do
			table.insert(binding_lines, string.format('- %s -> %s: %d times', stat.lhs, stat.rhs, stat.count))
		end
	end
	table.insert(binding_lines, '')
	render_section(buf, binding_lines, true)

	vim.cmd('setlocal foldlevel=1')
end

return M
