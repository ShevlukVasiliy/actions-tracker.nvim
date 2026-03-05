-- Event tracker service
local M = {}

-- Track a key press event
function M.track_key_press(mode, key, timestamp)
	return {
		mode = mode,
		key = key,
		timestamp = timestamp or os.time()
	}
end

-- Track command mode input
function M.track_command_input(command, timestamp)
	return {
		command = command,
		timestamp = timestamp or os.time()
	}
end

-- Track a triggered binding
function M.track_binding_trigger(mode, lhs, rhs, timestamp)
	return {
		mode = mode,
		lhs = lhs,
		rhs = rhs,
		timestamp = timestamp or os.time()
	}
end

-- Track a sequence of actions
function M.track_sequence(actions)
	return {
		type = "sequence",
		actions = actions,
		timestamp = os.time()
	}
end

-- Track a set of related events
function M.track_set(events)
	return {
		type = "set",
		events = events,
		timestamp = os.time()
	}
end

return M
