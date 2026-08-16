local lazy = require("sourcepawn-tools.lazy")
local path = lazy.require("sourcepawn-tools.utils.path")
local config = lazy.require("sourcepawn-tools.config")

local M = {}

---Find sourcepawn-studio LSP executable path
---@return string?
function M.get_lsp_path()
	local user_cmd = config.lsp and config.lsp.cmd
	if user_cmd and type(user_cmd) == "table" and user_cmd[1] then
		if path.is_readable(user_cmd[1]) or vim.fn.executable(user_cmd[1]) == 1 then
			return path.normalize(user_cmd[1])
		end
	end

	local lsp_binary = path.is_windows and "sourcepawn-studio.exe" or "sourcepawn-studio"

	-- 1. Check local sourcepawn-tools data directory
	local local_data_bin = vim.fs.normalize(vim.fn.stdpath("data") .. "/sourcepawn-tools/bin/" .. lsp_binary)
	if path.exists(local_data_bin) then
		return path.normalize(local_data_bin)
	end

	-- 2. Check system PATH
	if vim.fn.executable(lsp_binary) == 1 then
		return lsp_binary
	end

	-- 3. Check VS Code extension directories
	local pattern = path.is_windows
			and "~/.vscode/extensions/sarrus.sourcepawn-vscode-*/languageServer/sourcepawn-studio.exe"
		or "~/.vscode/extensions/sarrus.sourcepawn-vscode-*/languageServer/sourcepawn-studio"

	local matches = vim.fn.glob(vim.fn.expand(pattern), false, true)
	if #matches > 0 then
		local matched = matches[#matches]
		if path.exists(matched) then
			return path.normalize(matched)
		end
	end

	return nil
end

local compiler_cache = {}
local formatter_cache = {}

---Clear toolchain executable cache
function M.clear_cache()
	compiler_cache = {}
	formatter_cache = {}
end

---Find spcomp compiler executable path (spcomp.exe or spcomp64.exe or compile.exe)
---@param bufnr (integer|string)?
---@return string?
function M.get_compiler_path(bufnr)
	-- Determine project root
	local root_module = lazy.require("sourcepawn-tools.lsp.root")
	local root_dir = root_module.resolve_root_dir(bufnr) or vim.uv.cwd() or "."

	if compiler_cache[root_dir] and path.exists(compiler_cache[root_dir]) then
		return compiler_cache[root_dir]
	end

	local binary_patterns = path.is_windows and { "spcomp64.exe", "spcomp.exe" } or { "spcomp64", "spcomp" }

	-- =========================================================================
	-- TIER 1: Build Tools & Project-Local Binaries (Highest Priority)
	-- Dynamically discovers spcomp/compile binaries inside project root & subfolders (.sourceknight, build, bin, etc.)
	-- =========================================================================
	if root_dir and path.exists(root_dir) then
		local project_bins = vim.fs.find(binary_patterns, {
			path = root_dir,
			type = "file",
			limit = 1,
		})

		if #project_bins > 0 and path.is_readable(project_bins[1]) then
			local found = path.normalize(project_bins[1])
			compiler_cache[root_dir] = found
			return found
		end
	end

	-- =========================================================================
	-- TIER 2: Workspace Override Config (.sourcepawn-tools.lua, etc.)
	-- =========================================================================
	local local_cfg_path = config.find_local_config(bufnr)
	if local_cfg_path then
		local local_cfg = config.get_for_buffer(bufnr)
		local override_path = local_cfg and local_cfg.compiler and local_cfg.compiler.path
		if override_path and override_path ~= "" then
			if not path.is_absolute(override_path) then
				local base_dir = path.dirname(local_cfg_path) or root_dir
				override_path = base_dir .. "/" .. override_path
			end
			override_path = path.normalize(override_path)
			if path.is_readable(override_path) or vim.fn.executable(override_path) == 1 then
				compiler_cache[root_dir] = override_path
				return override_path
			end
		end
	end

	-- =========================================================================
	-- TIER 3: Plugin Config & Global Fallbacks (Lowest Priority)
	-- =========================================================================
	local global_cfg = config.get()
	local global_path = global_cfg and global_cfg.compiler and global_cfg.compiler.path
	if global_path and global_path ~= "" then
		global_path = path.normalize(global_path)
		if path.is_readable(global_path) or vim.fn.executable(global_path) == 1 then
			compiler_cache[root_dir] = global_path
			return global_path
		end
	end

	-- System PATH
	for _, bin in ipairs(binary_patterns) do
		if vim.fn.executable(bin) == 1 then
			compiler_cache[root_dir] = bin
			return bin
		end
	end

	-- Fallback VS Code extension or global directories
	local vs_matches = vim.fs.find(binary_patterns, {
		path = vim.fn.expand("~/.vscode/extensions"),
		type = "file",
		limit = 1,
	})
	if #vs_matches > 0 then
		local found = path.normalize(vs_matches[1])
		compiler_cache[root_dir] = found
		return found
	end

	return nil
end

---Find formatter executable path (clang-format / Mason / system)
---@return string?
function M.get_formatter_path()
	local cwd = vim.uv.cwd() or "."
	if formatter_cache[cwd] and path.exists(formatter_cache[cwd]) then
		return formatter_cache[cwd]
	end

	-- 1. Check Mason installation
	local mason_candidates = path.is_windows
			and {
				vim.fs.normalize(vim.fn.stdpath("data") .. "/mason/bin/clang-format.cmd"),
				vim.fs.normalize(vim.fn.stdpath("data") .. "/mason/bin/clang-format.exe"),
				vim.fs.normalize(
					vim.fn.stdpath("data") .. "/mason/packages/clang-format/venv/Scripts/clang-format.exe"
				),
			}
		or {
			vim.fs.normalize(vim.fn.stdpath("data") .. "/mason/bin/clang-format"),
			vim.fs.normalize(vim.fn.stdpath("data") .. "/mason/packages/clang-format/venv/bin/clang-format"),
		}

	for _, mpath in ipairs(mason_candidates) do
		if path.exists(mpath) then
			formatter_cache[cwd] = mpath
			return mpath
		end
	end

	-- 2. Check system PATH
	local bin_names = path.is_windows and { "clang-format.cmd", "clang-format.exe", "clang-format" }
		or { "clang-format" }
	for _, bname in ipairs(bin_names) do
		if vim.fn.executable(bname) == 1 then
			formatter_cache[cwd] = bname
			return bname
		end
	end

	-- 3. Check Mason packages directory dynamically
	local mason_root = vim.fs.normalize(vim.fn.stdpath("data") .. "/mason")
	if path.exists(mason_root) then
		local matches = vim.fs.find(function(name)
			local l = name:lower()
			return l == "clang-format.exe" or l == "clang-format.cmd" or l == "clang-format"
		end, { path = mason_root, limit = 1 })
		if #matches > 0 then
			local found = path.normalize(matches[1])
			formatter_cache[cwd] = found
			return found
		end
	end

	-- 4. Check LLVM system paths
	local llvm_candidates = {
		"C:/Program Files/LLVM/bin/clang-format.exe",
		"C:/Program Files (x86)/LLVM/bin/clang-format.exe",
	}
	for _, lpath in ipairs(llvm_candidates) do
		if path.exists(lpath) then
			formatter_cache[cwd] = lpath
			return lpath
		end
	end

	-- [SPFormat Legacy Fallback - Commented for experimentation]
	-- local sp_bin_names = path.is_windows and { "sp_format.exe", "spformat.exe" } or { "sp_format", "spformat" }
	-- for _, bname in ipairs(sp_bin_names) do
	--   local local_data_bin = vim.fs.normalize(vim.fn.stdpath("data") .. "/sourcepawn-tools/bin/" .. bname)
	--   if path.exists(local_data_bin) then
	--     formatter_cache[cwd] = local_data_bin
	--     return local_data_bin
	--   end
	-- end

	return nil
end

return M
