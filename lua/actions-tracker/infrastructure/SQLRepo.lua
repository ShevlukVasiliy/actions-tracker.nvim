local SQLRepo = {}
SQLRepo.__index = SQLRepo

function SQLRepo:new(conn)
	local instance = setmetatable({}, self)
	instance.db = conn
	instance:_create_tables()
	return instance
end

function SQLRepo:_create_tables()
	self.db:eval [[
        CREATE TABLE IF NOT EXISTS key_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            key TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        )
    ]]

	self.db:eval [[
        CREATE TABLE IF NOT EXISTS command_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            command TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        )
    ]]

	self.db:eval [[
        CREATE TABLE IF NOT EXISTS binding_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            lhs TEXT NOT NULL,
            rhs TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        )
    ]]

	self.db:eval [[
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

local function last_rowid(db)
	local res = db:eval("SELECT last_insert_rowid() as id")
	return res and res[1] and res[1].id or nil
end

function SQLRepo:save_key_event(event)
	self.db:eval(
		"INSERT INTO key_events (mode, key, timestamp) VALUES (:mode, :key, :timestamp)",
		{ mode = event.mode, key = event.key, timestamp = event.timestamp }
	)
	return last_rowid(self.db)
end

function SQLRepo:save_command_event(event)
	self.db:eval(
		"INSERT INTO command_events (command, timestamp) VALUES (:command, :timestamp)",
		{ command = event.command, timestamp = event.timestamp }
	)
	return last_rowid(self.db)
end

function SQLRepo:save_binding_event(event)
	self.db:eval(
		"INSERT INTO binding_events (mode, lhs, rhs, timestamp) VALUES (:mode, :lhs, :rhs, :timestamp)",
		{
			mode = tostring(event.mode or "unknown"),
			lhs = tostring(event.lhs or " "),
			rhs = tostring(event.rhs or " "),
			timestamp = event.timestamp
		}
	)
	return last_rowid(self.db)
end

function SQLRepo:save_key_mapping(mapping)
	self.db:eval(
		"INSERT INTO key_mappings (mode, lhs, rhs, desc, timestamp) VALUES (:mode, :lhs, :rhs, :desc, :timestamp)",
		{
			mode = tostring(event.mode or "unknown"),
			lhs = tostring(event.lhs or " "),
			rhs = tostring(event.rhs or " "),
			desc = tostring(mapping.desc or ""),
			timestamp = mapping.timestamp
		}
	)
	return last_rowid(self.db)
end

function SQLRepo:collect_and_save_all_mappings()
	local modes = { "n", "v", "x", "s", "o", "i", "c", "t" }
	local timestamp = os.time()

	for _, mode in ipairs(modes) do
		local mappings = vim.api.nvim_get_keymap(mode)
		for _, mapping in ipairs(mappings) do
			self:save_key_mapping({
				mode = mode,
				lhs = mapping.lhs or " ",
				rhs = mapping.rhs or " ",
				desc = mapping.desc or " ",
				timestamp = timestamp,
			})
		end
	end
end

function SQLRepo:get_mode_statistics()
	return self.db:eval([[
        SELECT mode, COUNT(*) as count
        FROM key_events
        GROUP BY mode
        ORDER BY count DESC
    ]]) or {}
end

function SQLRepo:get_command_statistics()
	return self.db:eval([[
        SELECT command, COUNT(*) as count
        FROM command_events
        GROUP BY command
        ORDER BY count DESC
        LIMIT 50
    ]]) or {}
end

function SQLRepo:get_binding_statistics()
	return self.db:eval([[
        SELECT lhs, rhs, COUNT(*) as count
        FROM binding_events
        GROUP BY lhs, rhs
        ORDER BY count DESC
        LIMIT 50
    ]]) or {}
end

function SQLRepo:get_total_key_events()
	local res = self.db:eval("SELECT COUNT(*) as total FROM key_events")
	return res and res[1] and res[1].total or 0
end

function SQLRepo:get_total_command_events()
	local res = self.db:eval("SELECT COUNT(*) as total FROM command_events")
	return res and res[1] and res[1].total or 0
end

function SQLRepo:get_total_binding_events()
	local res = self.db:eval("SELECT COUNT(*) as total FROM binding_events")
	return res and res[1] and res[1].total or 0
end

function SQLRepo:close()
	if self.db and not self.db:isclose() then
		self.db:close()
		self.db = nil
	end
end

return SQLRepo
