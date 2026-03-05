---@class KeyMapping
---@field mapping string Клавиша (напр. "<leader>ff")
---@field action string Команда или функция
local M = {}
M.__index = M

---@param mapping string
---@param action string
---@return KeyMapping
function M:new(mapping, action)
	return setmetatable({
		mapping = mapping,
		action = action
	}, self)
end

return M
