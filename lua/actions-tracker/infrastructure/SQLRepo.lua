local SQLRepo = {}
SQLRepo.__index = SQLRepo

function SQLRepo:new(conn)
	local instance = setmetatable({}, self)
	instance.db = conn
	instance:_create_tables()
	return instance
end

local function safe_eval(db, query, params)
	local status, res = pcall(function()
		return db:eval(query, params)
	end)
	if not status then
		return nil
	end
	return res
end

function SQLRepo:_create_tables()
	local tables = {
		[[ CREATE TABLE IF NOT EXISTS key_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            key TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        ) ]],
		[[ CREATE TABLE IF NOT EXISTS command_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            command TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        ) ]],
		[[ CREATE TABLE IF NOT EXISTS binding_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            lhs TEXT NOT NULL,
            rhs TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        ) ]],
		[[ CREATE TABLE IF NOT EXISTS key_mappings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            lhs TEXT NOT NULL,
            rhs TEXT NOT NULL,
            desc TEXT,
            timestamp INTEGER NOT NULL
        ) ]]
	}
	for _, table_sql in ipairs(tables) do
		safe_eval(self.db, table_sql)
	end
end

local function last_rowid(db)
	local res = safe_eval(db, "SELECT last_insert_rowid() as id")
	return res and res[1] and res[1].id or nil
end

function SQLRepo:save_key_event(event)
	pcall(function()
		self.db:eval(
			"INSERT INTO key_events (mode, key, timestamp) VALUES (:mode, :key, :timestamp)",
			{
				mode = tostring(event.mode or "n"),
				key = tostring(event.key or "unknown"),
				timestamp = event.timestamp or os.time()
			}
		)
	end)
	return nil
end

function SQLRepo:save_command_event(event)
	pcall(function()
		self.db:eval(
			"INSERT INTO command_events (command, timestamp) VALUES (:command, :timestamp)",
			{
				command = tostring(event.command or "unknown"),
				timestamp = event.timestamp or os.time()
			}
		)
	end)
	return nil
end

function SQLRepo:save_binding_event(event)
	pcall(function()
		local rhs_text = tostring(event.rhs or "")
		if #rhs_text > 100 or rhs_text:match("lua") or rhs_text:match("require") then
			rhs_text = "complex_mapping"
		end

		self.db:eval(
			"INSERT INTO binding_events (mode, lhs, rhs, timestamp) VALUES (:mode, :lhs, :rhs, :timestamp)",
			{
				mode = tostring(event.mode or "n"),
				lhs = tostring(event.lhs or " "),
				rhs = rhs_text,
				timestamp = event.timestamp or os.time()
			}
		)
	end)
	return nil
end

function SQLRepo:save_key_mapping(mapping)
	safe_eval(self.db,
		"INSERT INTO key_mappings (mode, lhs, rhs, desc, timestamp) VALUES (:mode, :lhs, :rhs, :desc, :timestamp)",
		{
			mode = tostring(mapping.mode or "n"),
			lhs = tostring(mapping.lhs or " "),
			rhs = tostring(mapping.rhs or " "),
			desc = tostring(mapping.desc or ""),
			timestamp = mapping.timestamp or os.time()
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
				lhs = mapping.lhs,
				rhs = mapping.rhs or (mapping.callback and "callback") or " ",
				desc = mapping.desc,
				timestamp = timestamp,
			})
		end
	end
end

function SQLRepo:get_mode_statistics()
	return safe_eval(self.db, [[
        SELECT mode, COUNT(*) as count FROM key_events GROUP BY mode ORDER BY count DESC
    ]]) or {}
end

function SQLRepo:get_command_statistics()
	return safe_eval(self.db, [[
        SELECT command, COUNT(*) as count FROM command_events GROUP BY command ORDER BY count DESC LIMIT 50
    ]]) or {}
end

function SQLRepo:get_binding_statistics()
	return safe_eval(self.db, [[
        SELECT lhs, rhs, COUNT(*) as count FROM binding_events GROUP BY lhs, rhs ORDER BY count DESC LIMIT 50
    ]]) or {}
end

function SQLRepo:get_total_key_events()
	local res = safe_eval(self.db, "SELECT COUNT(*) as total FROM key_events")
	return res and res[1] and res[1].total or 0
end

function SQLRepo:get_total_command_events()
	local res = safe_eval(self.db, "SELECT COUNT(*) as total FROM command_events")
	return res and res[1] and res[1].total or 0
end

function SQLRepo:get_total_binding_events()
	local res = safe_eval(self.db, "SELECT COUNT(*) as total FROM binding_events")
	return res and res[1] and res[1].total or 0
end

function SQLRepo:close()
	if self.db and not self.db:isclose() then
		pcall(function() self.db:close() end)
		self.db = nil
	end
end

return SQLRepo
