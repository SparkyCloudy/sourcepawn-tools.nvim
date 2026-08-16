local lazy = require("sourcepawn-tools.lazy")
local path = lazy.require("sourcepawn-tools.utils.path")
local ui = lazy.require("sourcepawn-tools.ui")

local M = {}

---Parse function parameters into list of names
---@param param_str string
---@return string[]
local function parse_params(param_str)
	local params = {}
	if not param_str or param_str:match("^%s*$") or param_str:match("^%s*void%s*$") then
		return params
	end

	for p in param_str:gmatch("[^,]+") do
		p = p:gsub("%s*=[^,]+", "") -- Remove default values (e.g. = 0)
		p = vim.trim(p)
		-- Match type and param name: e.g. "int client", "const char[] name", "any data", "client"
		local name = p:match("[%w_]+%s*([%w_]+)%s*%[%]?$") or p:match("([%w_]+)%s*$")
		if name and name ~= "" and name ~= "void" then
			table.insert(params, name)
		end
	end

	return params
end

---Generate Doxygen-style doc comment for function under cursor
---@param bufnr integer?
function M.generate_doc(bufnr)
	bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] -- 1-indexed line number

	local lines =
		vim.api.nvim_buf_get_lines(bufnr, row - 1, math.min(row + 5, vim.api.nvim_buf_line_count(bufnr)), false)
	local combined = table.concat(lines, " ")

	-- Match SourcePawn function patterns:
	-- [public|stock|native|forward|static]? [ret_type] func_name(params)
	local match_pattern = "([%w_]*%s*[%w_:]+%s+[%w_]+)%s*%((.-)%)"
	local func_head, param_str = combined:match(match_pattern)

	if not func_head then
		-- Try simpler fallback: func_name(params)
		func_head, param_str = combined:match("([%w_]+)%s*%((.-)%)")
	end

	if not func_head then
		ui.notify("Could not detect a function signature under cursor!", ui.WARN)
		return
	end

	local func_name = func_head:match("([%w_]+)%s*$") or func_head
	local ret_type = func_head:match("([%w_:]+)%s+[%w_]+$") or ""
	local has_return = (ret_type ~= "void" and ret_type ~= "")

	local params = parse_params(param_str or "")

	-- Calculate indentation of target line
	local target_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
	local indent = target_line:match("^(%s*)") or ""

	local doc_lines = {
		indent .. "/**",
		indent .. " * " .. func_name .. " description.",
	}

	if #params > 0 then
		table.insert(doc_lines, indent .. " *")
		for _, param in ipairs(params) do
			local desc = "The " .. param .. "."
			if param == "client" then
				desc = "The client index."
			elseif param == "args" then
				desc = "Number of arguments."
			end
			table.insert(doc_lines, string.format("%s * @param %-12s %s", indent, param, desc))
		end
	end

	if has_return then
		if #params == 0 then
			table.insert(doc_lines, indent .. " *")
		end
		table.insert(
			doc_lines,
			indent
				.. " * @return       "
				.. (ret_type == "Action" and "Plugin_Handled or Plugin_Continue." or (ret_type .. " value."))
		)
	end

	table.insert(doc_lines, indent .. " */")

	vim.api.nvim_buf_set_lines(bufnr, row - 1, row - 1, false, doc_lines)
	ui.notify("✓ Doc comment generated for " .. func_name .. "()", ui.INFO)
end

---Generate boilerplate code for a new SourcePawn plugin
---@param name string?
function M.new_plugin(name)
	local plugin_name = name
	if not plugin_name or plugin_name == "" then
		plugin_name = vim.fn.input("Plugin filename / name: ")
	end

	if not plugin_name or plugin_name == "" then
		return
	end

	if not plugin_name:match("%.sp$") then
		plugin_name = plugin_name .. ".sp"
	end

	local title_name = path.stem(plugin_name):gsub("[-_]", " "):gsub("(%a)([%w_']*)", function(first, rest)
		return first:upper() .. rest:lower()
	end)

	local content = {
		"#pragma semicolon 1",
		"#pragma newdecls required",
		"",
		"#include <sourcemod>",
		"#include <sdktools>",
		"",
		"public Plugin myinfo =",
		"{",
		'\tname = "' .. title_name .. '",',
		'\tauthor = "' .. (vim.g.user or vim.uv.os_homedir():match("([^\\/]+)$") or "Author") .. '",',
		'\tdescription = "' .. title_name .. ' plugin",',
		'\tversion = "1.0.0",',
		'\turl = ""',
		"};",
		"",
		"public void OnPluginStart()",
		"{",
		"\t// Initialization code",
		"}",
		"",
	}

	local target_path = (vim.uv.cwd() or ".") .. "/" .. plugin_name
	target_path = path.normalize(target_path)

	if path.exists(target_path) then
		ui.notify("File already exists: " .. target_path, ui.WARN)
		vim.cmd("edit " .. target_path)
		return
	end

	local f = io.open(target_path, "w")
	if f then
		f:write(table.concat(content, "\n"))
		f:close()
		vim.cmd("edit " .. target_path)
		ui.notify("✓ Created new SourcePawn plugin: " .. plugin_name, ui.INFO)
	else
		ui.notify("Failed to create file: " .. target_path, ui.ERROR)
	end
end

---Generate boilerplate for a new submodule
---@param name string?
function M.new_module(name)
	local mod_name = name
	if not mod_name or mod_name == "" then
		mod_name = vim.fn.input("Module filename / name: ")
	end

	if not mod_name or mod_name == "" then
		return
	end

	if not mod_name:match("%.sp$") and not mod_name:match("%.inc$") then
		mod_name = mod_name .. ".sp"
	end

	local stem = path.stem(mod_name)
	local prefix = stem:gsub("[-_]", " ")
		:gsub("(%a)([%w_']*)", function(first, rest)
			return first:upper() .. rest:lower()
		end)
		:gsub("%s+", "")

	local content = {
		"#if defined _" .. stem .. "_included",
		"  #endinput",
		"#endif",
		"#define _" .. stem .. "_included",
		"",
		"void " .. prefix .. "_OnPluginStart()",
		"{",
		"\t// Module startup logic",
		"}",
		"",
	}

	local target_path = (vim.uv.cwd() or ".") .. "/" .. mod_name
	target_path = path.normalize(target_path)

	if path.exists(target_path) then
		ui.notify("File already exists: " .. target_path, ui.WARN)
		vim.cmd("edit " .. target_path)
		return
	end

	local parent_dir = path.dirname(target_path)
	if parent_dir and not path.exists(parent_dir) then
		vim.fn.mkdir(parent_dir, "p")
	end

	local f = io.open(target_path, "w")
	if f then
		f:write(table.concat(content, "\n"))
		f:close()
		vim.cmd("edit " .. target_path)
		ui.notify("✓ Created new SourcePawn module: " .. mod_name, ui.INFO)
	else
		ui.notify("Failed to create file: " .. target_path, ui.ERROR)
	end
end

return M
