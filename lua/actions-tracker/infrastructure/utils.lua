local M = {}

local random = math.random

function M.uuid()
	local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
	return string.gsub(template, '[xy]', function(c)
		local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
		return string.format('%x', v)
	end)
end

-- Get current timestamp in seconds
function M.get_timestamp()
	return os.time()
end

-- Safely require a module
function M.safe_require(module_name)
	local ok, module = pcall(require, module_name)
	if ok then
		return module
	else
		return nil
	end
end

-- Table helper: check if table is empty
function M.is_table_empty(t)
	return next(t) == nil
end

-- Debug print (only in development)
function M.debug_print(...)
	if os.getenv("ACTIONS_TRACKER_DEBUG") then
		print(...)
	end
end

return M
