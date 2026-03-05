local SQLRepo = {}
SQLRepo.__index = SQLRepo

function SQLRepo:new(conn)
	local instance = setmetatable({}, self)
	instance.db = conn
	instance:_create_tables()
	return instance
end

function SQLRepo:_create_tables()
	self.db:exec [[
        CREATE TABLE IF NOT EXISTS key_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            key TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        )
    ]]

	self.db:exec [[
        CREATE TABLE IF NOT EXISTS command_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            command TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        )
    ]]

	self.db:exec [[
        CREATE TABLE IF NOT EXISTS binding_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            lhs TEXT NOT NULL,
            rhs TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        )
    ]]

	self.db:exec [[
        CREATE TABLE IF NOT EXISTS key_mappings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            lhs TEXT NOT NULL,
            rhs TEXT NOT NULL,
            desc TEXT,
            timestamp INTEGER NOT NULL
        )
    ]]
end

function SQLRepo:save_key_event(event)
	local stmt = self.db:prepare("INSERT INTO key_events (mode, key, timestamp) VALUES (?, ?, ?)")
	stmt:bind_values(event.mode, event.key, event.timestamp)
	stmt:step()
	stmt:reset()
	return self.db:last_insert_rowid()
end

function SQLRepo:save_command_event(event)
	local stmt = self.db:prepare("INSERT INTO command_events (command, timestamp) VALUES (?, ?)")
	stmt:bind_values(event.command, event.timestamp)
	stmt:step()
	stmt:reset()
	return self.db:last_insert_rowid()
end

function SQLRepo:save_binding_event(event)
	local stmt = self.db:prepare("INSERT INTO binding_events (mode, lhs, rhs, timestamp) VALUES (?, ?, ?, ?)")
	stmt:bind_values(event.mode, event.lhs, event.rhs, event.timestamp)
	stmt:step()
	stmt:reset()
	return self.db:last_insert_rowid()
end

function SQLRepo:save_key_mapping(mapping)
	local stmt = self.db:prepare("INSERT INTO key_mappings (mode, lhs, rhs, desc, timestamp) VALUES (?, ?, ?, ?, ?)")
	stmt:bind_values(mapping.mode, mapping.lhs, mapping.rhs, mapping.desc or "", mapping.timestamp)
	stmt:step()
	stmt:reset()
	return self.db:last_insert_rowid()
end

function SQLRepo:collect_and_save_all_mappings()
	local modes = { "n", "v", "x", "s", "o", "i", "c", "t" }
	local timestamp = os.time()

	for _, mode in ipairs(modes) do
		local mappings = vim.api.nvim_get_keymap(mode)
		for _, mapping in ipairs(mappings) do
			self:save_key_mapping({
				mode = mode,
				lhs = mapping.lhs,
				rhs = mapping.rhs,
				desc = mapping.desc or "",
				timestamp = timestamp
			})
		end
	end
end

function SQLRepo:get_mode_statistics()
	local stmt = self.db:prepare([[
        SELECT mode, COUNT(*) as count
        FROM key_events
        GROUP BY mode
        ORDER BY count DESC
    ]])
	local result = {}
	while stmt:step() == 100 do   -- sqlite3.ROW is usually 100
		table.insert(result, {
			mode = stmt:get_value(0),
			count = stmt:get_value(1)
		})
	end
	stmt:reset()
	return result
end

function SQLRepo:get_command_statistics()
	local stmt = self.db:prepare([[
        SELECT command, COUNT(*) as count
        FROM command_events
        GROUP BY command
        ORDER BY count DESC
        LIMIT 50
    ]])
	local result = {}
	while stmt:step() == 100 do
		table.insert(result, {
			command = stmt:get_value(0),
			count = stmt:get_value(1)
		})
	end
	stmt:reset()
	return result
end

function SQLRepo:get_binding_statistics()
	local stmt = self.db:prepare([[
        SELECT lhs, rhs, COUNT(*) as count
        FROM binding_events
        GROUP BY lhs, rhs
        ORDER BY count DESC
        LIMIT 50
    ]])
	local result = {}
	while stmt:step() == 100 do
		table.insert(result, {
			lhs = stmt:get_value(0),
			rhs = stmt:get_value(1),
			count = stmt:get_value(2)
		})
	end
	stmt:reset()
	return result
end

function SQLRepo:get_total_key_events()
	local stmt = self.db:prepare("SELECT COUNT(*) FROM key_events")
	stmt:step()
	local count = stmt:get_value(0)
	stmt:reset()
	return count
end

function SQLRepo:get_total_command_events()
	local stmt = self.db:prepare("SELECT COUNT(*) FROM command_events")
	stmt:step()
	local count = stmt:get_value(0)
	stmt:reset()
	return count
end

function SQLRepo:get_total_binding_events()
	local stmt = self.db:prepare("SELECT COUNT(*) FROM binding_events")
	stmt:step()
	local count = stmt:get_value(0)
	stmt:reset()
	return count
end

function SQLRepo:close()
	if self.db then
		self.db:close()
		self.db = nil
	end
end

return SQLRepo
