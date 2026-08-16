local lazy = require("sourcepawn-tools.lazy")
local ui = lazy.require("sourcepawn-tools.ui")

local M = {}

---Log a message
---@param msg string
---@param level integer?
function M.log(msg, level)
	ui.notify(msg, level)
end

function M.debug(msg)
	M.log(msg, ui.DEBUG)
end

function M.info(msg)
	M.log(msg, ui.INFO)
end

function M.warn(msg)
	M.log(msg, ui.WARN)
end

function M.error(msg)
	M.log(msg, ui.ERROR)
end

return M
