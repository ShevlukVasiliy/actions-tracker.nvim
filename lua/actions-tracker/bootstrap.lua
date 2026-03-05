local M = {}

function M.setup()
    -- 1. Попытка загрузить sqlite.lua (зависимость nvim-плагина)
    local ok, sqlite = pcall(require, 'sqlite')
    if not ok then
        vim.notify(
            "[actions-tracker] Ошибка: sqlite.lua не найден.\n" ..
            "Пожалуйста, установите 'kkharji/sqlite.lua' в вашу папку pack/*/start/",
            vim.log.levels.ERROR
        )
        return
    end

    -- 2. Путь к базе данных
    local db_path = vim.fn.stdpath('data') .. '/actions-tracker.sqlite3'

    -- 3. Открытие соединения (sqlite.lua сам управляет FFI-биндингом)
    local db = sqlite.db.open(db_path)
    if not db then
        vim.notify("[actions-tracker] Не удалось открыть базу данных по пути: " .. db_path, vim.log.levels.ERROR)
        return
    end

    -- 4. Загрузка репозитория (передаем объект БД из sqlite.lua)
    local SQLRepo = require('actions-tracker.infrastructure.SQLRepo')
    local sql_repo = SQLRepo:new(db)

    -- 5. Загрузка трекера
    local tracker = require("actions-tracker.presenters.tracker")
    tracker.setup(sql_repo)

    -- 6. Регистрация команд
    vim.api.nvim_create_user_command("ActionsTrackerStart", function()
        tracker.setup(sql_repo)
    end, { desc = "Start tracking Neovim actions" })

    vim.api.nvim_create_user_command("ActionsTrackerCollectMappings", function()
        sql_repo:collect_and_save_all_mappings()
        print("[actions-tracker] Mappings collected and saved")
    end, { desc = "Collect and save all current key mappings" })

    vim.api.nvim_create_user_command("ActionsTrackerAnalytics", function()
        local analytics = require("actions-tracker.presenters.analytics")
        analytics.show_analytics(sql_repo)
    end, { desc = "Show analytics dashboard" })

    -- 7. Упрощенная диагностика
    vim.api.nvim_create_user_command("ActionsTrackerDiagnose", function()
        print("=== Actions Tracker Diagnosis ===")
        print("✓ sqlite.lua: " .. (package.loaded['sqlite'] and "Loaded" or "Not Loaded"))
        print("✓ DB Path: " .. db_path)
        print("✓ DB Connected: " .. tostring(not db:isclosed()))
        
        -- Тестовый запрос через eval (интерфейс sqlite.lua)
        local test = db:eval("SELECT sqlite_version() as ver")
        if test and test[1] then
            print("✓ SQLite Version: " .. test[1].ver)
        end
    end, { desc = "Diagnose plugin issues" })

    print("[actions-tracker] Plugin initialized with sqlite.lua")
end

return M
