---@class Sequence
---@field sequence_id string Уникальный ID (например, "save_file")
---@field acts string[] Список нажатых клавиш
local M = {}
M.__index = M

---@param sequence_id string
---@param acts string[]
---@return Sequence
function M:new(sequence_id, acts)
	return setmetatable({
		sequence_id = sequence_id or "unknown",
		acts = acts or {}
	}, self)
end

return M
