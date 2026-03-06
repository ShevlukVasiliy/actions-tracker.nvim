local M = {}
local event_tracker = require("actions-tracker.domain.services.event_tracker")

function M.start_tracking(sql_repo)
    vim.on_key(function(key)
        local mode = vim.api.nvim_get_mode().mode
        if key and #key > 0 then
            pcall(function()
                local event = event_tracker.track_key_press(mode, vim.fn.keytrans(key))
                sql_repo:save_key_event(event)
            end)
        end
    end)

    vim.api.nvim_create_autocmd("CmdlineLeave", {
        pattern = ":",
        callback = function()
            local cmd = vim.fn.getcmdline()
            if cmd and #cmd > 0 then
                pcall(function()
                    local event = event_tracker.track_command_input(cmd)
                    sql_repo:save_command_event(event)
                end)
            end
        end
    })
end

function M.collect_mappings(sql_repo)
    pcall(function()
        sql_repo:collect_and_save_all_mappings()
    end)
end

function M.setup(sql_repo)
    if not sql_repo then
        return
    end

    M.start_tracking(sql_repo)
    M.collect_mappings(sql_repo)
end

return M
