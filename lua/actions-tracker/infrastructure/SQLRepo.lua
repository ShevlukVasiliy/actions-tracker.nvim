local SQLRepo = {}
SQLRepo.__index = SQLRepo

function SQLRepo:new(db_path)
    local ok, sqlite = pcall(require, "sqlite")
    if not ok then
        error("sqlite.lua not found! Install 'kkharji/sqlite.lua'")
    end

    local instance = setmetatable({}, self)
    -- sqlite.open возвращает объект БД
    instance.db = sqlite.open(db_path)
    instance:_create_tables()
    return instance
end

function SQLRepo:_create_tables()
    -- В sqlite.lua :eval() выполняет сырой SQL
    self.db:eval [[
        CREATE TABLE IF NOT EXISTS key_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            key TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS command_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            command TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS binding_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            lhs TEXT NOT NULL,
            rhs TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS key_mappings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            lhs TEXT NOT NULL,
            rhs TEXT NOT NULL,
            desc TEXT,
            timestamp INTEGER NOT NULL
        );
    ]]
end

-- В sqlite.lua биндинг идет через таблицу во втором аргументе
function SQLRepo:save_key_event(event)
    self.db:eval("INSERT INTO key_events (mode, key, timestamp) VALUES (?, ?, ?)", 
        { event.mode, event.key, event.timestamp })
    return self.db:last_insert_rowid()
end

function SQLRepo:save_command_event(event)
    self.db:eval("INSERT INTO command_events (command, timestamp) VALUES (?, ?)", 
        { event.command, event.timestamp })
    return self.db:last_insert_rowid()
end

function SQLRepo:save_binding_event(event)
    self.db:eval("INSERT INTO binding_events (mode, lhs, rhs, timestamp) VALUES (?, ?, ?, ?)", 
        { event.mode, event.lhs, event.rhs, event.timestamp })
    return self.db:last_insert_rowid()
end

function SQLRepo:save_key_mapping(mapping)
    self.db:eval("INSERT INTO key_mappings (mode, lhs, rhs, desc, timestamp) VALUES (?, ?, ?, ?, ?)", 
        { mapping.mode, mapping.lhs, mapping.rhs, mapping.desc or "", mapping.timestamp })
    return self.db:last_insert_rowid()
end

-- Методы статистики становятся намного проще:
function SQLRepo:get_mode_statistics()
    -- eval возвращает список таблиц (массив объектов)
    return self.db:eval([[
        SELECT mode, COUNT(*) as count
        FROM key_events
        GROUP BY mode
        ORDER BY count DESC
    ]])
end

function SQLRepo:get_command_statistics()
    return self.db:eval([[
        SELECT command, COUNT(*) as count
        FROM command_events
        GROUP BY command
        ORDER BY count DESC
        LIMIT 50
    ]])
end

-- Агрегатные функции (COUNT)
function SQLRepo:get_total_key_events()
    local res = self.db:eval("SELECT COUNT(*) as total FROM key_events")
    return res[1] and res[1].total or 0
end

function SQLRepo:close()
    if self.db and not self.db:is_closed() then
        self.db:close()
    end
end

return SQLRepo
