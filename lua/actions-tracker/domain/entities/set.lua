---@class Set
---@field timestamp number
---@field during_time number В миллисекундах или секундах
---@field set_type "normal" | "input" | "command" | "autocommand"
---@field sequence Sequence
local M = {}
M.__index = M

---@param set_type "normal" | "input" | "command" | "autocommand"
---@param sequence Sequence
---@param during_time? number
---@return Set
function M:new(set_type, sequence, during_time)
	return setmetatable({
		timestamp = os.time(),     -- или vim.loop.hrtime() для точности
		during_time = during_time or 0,
		action_type = set_type or 'input',
		sequence = sequence
	}, self)
end

return M
