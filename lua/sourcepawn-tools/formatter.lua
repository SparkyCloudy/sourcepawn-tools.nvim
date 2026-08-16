local lazy = require("sourcepawn-tools.lazy")
local path = lazy.require("sourcepawn-tools.utils.path")
local executable = lazy.require("sourcepawn-tools.executable")
local ui = lazy.require("sourcepawn-tools.ui")

local M = {}

---Get the absolute path to the bundled .clang-format file
---@return string
local function get_bundled_clang_format()
	local info = debug.getinfo(1, "S")
	local source = info.source:sub(2) -- remove '@'
	local plugin_root = vim.fn.fnamemodify(source, ":h:h:h")
	return plugin_root .. "/.clang-format"
end

---Check if project has its own clang-format file
---@param startpath string
---@return boolean
local function has_local_clang_format(startpath)
	local found = vim.fs.find({ ".clang-format", "_clang-format" }, {
		path = startpath,
		upward = true,
		type = "file",
	})
	return #found > 0
end

---Pre-process sourcepawn code for clang-format
---@param text string
---@return string
local function pre_format(text)
	text = text:gsub("enum%s+struct%s+", "struct /*__SP_ENUM_STRUCT__*/ ")
	text = text:gsub("methodmap%s+", "class /*__SP_METHODMAP__*/ ")
	return text
end

---Post-process clang-format output for sourcepawn
---@param text string
---@return string
local function post_format(text)
	text = text:gsub("struct%s+/%*__SP_ENUM_STRUCT__%*/%s+", "enum struct ")
	text = text:gsub("class%s+/%*__SP_METHODMAP__%*/%s+", "methodmap ")
	return text
end

---Run clang-format dynamically on text
---@param bufnr integer
---@param text string
---@param cb function(err: string|nil, result: string[]|nil)
local function run_clang_format(bufnr, text, cb)
	local formatter = executable.get_formatter_path()
	if not formatter or (not path.exists(formatter) and vim.fn.executable(formatter) == 0) then
		cb("clang-format executable not found", nil)
		return
	end

	local fname = vim.api.nvim_buf_get_name(bufnr)
	if fname == "" then fname = "plugin.sp" end
	local file_dir = vim.fn.fnamemodify(fname, ":h")

	local config = lazy.require("sourcepawn-tools.config")
	local cfg = config.get_for_buffer(bufnr)

	local cmd = { formatter }
	if cfg.formatter and cfg.formatter.options and type(cfg.formatter.options) == "table" and #cfg.formatter.options > 0 then
		for _, opt in ipairs(cfg.formatter.options) do
			table.insert(cmd, opt)
		end
	else
		if has_local_clang_format(file_dir) then
			table.insert(cmd, "--style=file")
		else
			table.insert(cmd, "--style=file:" .. get_bundled_clang_format())
		end
	end
	table.insert(cmd, "--assume-filename=" .. fname)

	local input = pre_format(text)

	vim.system(cmd, { stdin = input, text = true }, function(obj)
		vim.schedule(function()
			if obj.code == 0 and obj.stdout then
				local formatted_content = post_format(tostring(obj.stdout))
				local new_lines = vim.split(formatted_content, "\n", { plain = true })
				if #new_lines > 0 and new_lines[#new_lines] == "" then
					table.remove(new_lines, #new_lines)
				end
				cb(nil, new_lines)
			else
				cb(obj.stderr or "Unknown clang-format error", nil)
			end
		end)
	end)
end

---Format buffer using clang-format
---@param bufnr integer?
function M.format(bufnr)
	bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then return end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local text = table.concat(lines, "\n")

	run_clang_format(bufnr, text, function(err, new_lines)
		if err then
			ui.notify("clang-format error: " .. err, ui.ERROR)
			return
		end
		if not vim.api.nvim_buf_is_valid(bufnr) then return end
		-- Preserve trailing empty line logic
		if lines[#lines] ~= "" and new_lines[#new_lines] == "" then
			table.remove(new_lines, #new_lines)
		end
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
		ui.notify("✓ Formatted with clang-format", ui.INFO)
	end)
end

---Conform.nvim integration formatter specification
M.conform_formatter = {
	meta = {
		url = "https://clang.llvm.org/docs/ClangFormat.html",
		description = "A tool to format C/C++/SourcePawn code.",
	},
	format = function(self, ctx, lines, callback)
		local text = table.concat(lines, "\n")
		run_clang_format(ctx.buf, text, function(err, new_lines)
			if err then
				ui.notify("clang-format error: " .. err, ui.ERROR)
				callback(true)
			else
				callback(nil, new_lines)
			end
		end)
	end,
}

return M
