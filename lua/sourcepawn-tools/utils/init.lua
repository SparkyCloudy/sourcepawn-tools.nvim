local M = {}

M.path = require("sourcepawn-tools.utils.path")

---Check if value is a list / array table
---@param val any
---@return boolean
function M.is_list(val)
	if type(val) ~= "table" then
		return false
	end
	if vim.islist then
		return vim.islist(val)
	end
	local i = 1
	for _ in pairs(val) do
		if val[i] == nil then
			return false
		end
		i = i + 1
	end
	return true
end

---Safely merge tables
---@param ... table
---@return table
function M.merge(...)
	return vim.tbl_deep_extend("force", ...)
end

return M
