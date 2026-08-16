local lazy = require("sourcepawn-tools.lazy")
local path = lazy.require("sourcepawn-tools.utils.path")
local root = lazy.require("sourcepawn-tools.lsp.root")

local M = {}

---Get active SourcePawn main file name for the current buffer
---@param bufnr integer?
---@return string
function M.main_file(bufnr)
	bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return ""
	end

	local file = vim.api.nvim_buf_get_name(bufnr)
	if not file or file == "" then
		return ""
	end

	local ext = path.ext(file)
	if ext ~= "sp" and ext ~= "inc" then
		return ""
	end

	local main = root.find_main_file(file)
	if not main or main == "" then
		return path.basename(file)
	end

	local is_sub = (main ~= path.normalize(file))
	local main_name = path.basename(main)

	if is_sub then
		return "SP: " .. main_name .. " (" .. path.basename(file) .. ")"
	else
		return "SP: " .. main_name
	end
end

---Lualine component function: returns formatted status with nerd font icon
---@return string
function M.lualine()
	local bufnr = vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(bufnr)
	if not file or file == "" then
		return ""
	end

	local ext = path.ext(file)
	if ext ~= "sp" and ext ~= "inc" then
		return ""
	end

	local main = root.find_main_file(file)
	if not main or main == "" then
		return " " .. path.basename(file)
	end

	local is_sub = (main ~= path.normalize(file))
	local main_name = path.basename(main)

	if is_sub then
		return " " .. main_name .. " ↳ " .. path.basename(file)
	else
		return " " .. main_name
	end
end

return M
