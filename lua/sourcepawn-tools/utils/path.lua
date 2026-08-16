local M = {}

M.is_windows = vim.fn.has("win32") == 1

---Normalize path with forward slashes
---@param p string?
---@return string
function M.normalize(p)
	if not p or p == "" then
		return ""
	end
	local norm = vim.fs.normalize(p)
	if M.is_windows then
		norm = norm:gsub("^([a-zA-Z]):", function(d)
			return d:upper() .. ":"
		end)
	end
	return norm
end

---Check if path is absolute
---@param p string?
---@return boolean
function M.is_absolute(p)
	if not p or p == "" then
		return false
	end
	local norm = p:gsub("\\", "/")
	if M.is_windows then
		return norm:match("^[a-zA-Z]:/") ~= nil or norm:match("^//") ~= nil
	else
		return norm:match("^/") ~= nil
	end
end

---Check if path exists
---@param p string
---@return boolean
function M.exists(p)
	if not p or p == "" then
		return false
	end
	return vim.uv.fs_stat(p) ~= nil
end

---Check if file is readable
---@param p string
---@return boolean
function M.is_readable(p)
	if not p or p == "" then
		return false
	end
	return vim.fn.filereadable(p) == 1
end

---Get dirname of path
---@param p string
---@return string?
function M.dirname(p)
	if not p or p == "" then
		return nil
	end
	local norm = p:gsub("\\", "/")
	return norm:match("^(.*)/[^/]+$") or vim.fs.dirname(p)
end

---Get basename of path (filename with extension)
---@param p string
---@return string
function M.basename(p)
	if not p or p == "" then
		return ""
	end
	local norm = p:gsub("\\", "/")
	return norm:match("([^/]+)$") or vim.fn.fnamemodify(p, ":t")
end

---Get file stem (name without extension)
---@param p string
---@return string
function M.stem(p)
	if not p or p == "" then
		return ""
	end
	local base = M.basename(p)
	return base:match("^(.*)%.[^.]+$") or base
end

---Get file extension in lowercase
---@param p string
---@return string
function M.ext(p)
	if not p or p == "" then
		return ""
	end
	local base = M.basename(p)
	local ext = base:match("%.([^.]+)$")
	return ext and ext:lower() or ""
end

---Get canonical realpath
---@param p string
---@return string?
function M.realpath(p)
	if not p or p == "" then
		return nil
	end
	local real = vim.uv.fs_realpath(p)
	return real and M.normalize(real) or nil
end

---Collect and deduplicate canonical include directories with 3-tier priority
---@param bufnr integer?
---@param custom_dirs string[]?
---@return string[]
function M.get_include_dirs(bufnr, custom_dirs)
	local dirs = {}
	local seen = {}

	local function add_dir(dir_path)
		if not dir_path or dir_path == "" then
			return
		end
		local norm = M.normalize(dir_path)
		local real = M.realpath(norm) or (M.exists(norm) and norm or nil)
		if real and not seen[real] and M.exists(real) then
			seen[real] = true
			table.insert(dirs, real)
		end
	end

	local cwd = vim.uv.cwd() or ""
	local bufpath = (bufnr and bufnr ~= 0) and vim.api.nvim_buf_get_name(bufnr) or ""
	local bufdir = (bufpath ~= "") and M.dirname(bufpath) or cwd

	-- Determine Project Root
	local root_module = require("sourcepawn-tools.lsp.root")
	local root_dir = root_module.resolve_root_dir(bufnr) or bufdir or cwd

	-- =========================================================================
	-- TIER 1: Build Tools & Project-Local Includes (Highest Priority)
	-- Dynamically discovers include/includes/custom_inc directories in project root
	-- (Excludes intermediate cache directories like .sourceknight/cache)
	-- =========================================================================
	if root_dir and M.exists(root_dir) then
		local found_includes = vim.fs.find(function(name, dir_path)
			local l = name:lower()
			local norm_dir = (dir_path .. "/" .. name):lower():gsub("\\", "/")
			-- Ignore intermediate cache folders (e.g. .sourceknight/cache/, .cache/)
			if norm_dir:find("/%.?cache/") or norm_dir:find("/%.?cache$") then
				return false
			end

			return l == "include" or l == "includes" or l == "custom_inc" or l == "custom_includes"
		end, {
			path = root_dir,
			type = "directory",
			limit = 30,
		})

		for _, inc_path in ipairs(found_includes) do
			add_dir(inc_path)
		end
	end

	if bufdir and bufdir ~= root_dir then
		add_dir(bufdir .. "/include")
		add_dir(bufdir .. "/../include")
	end

	-- =========================================================================
	-- TIER 2: Workspace Override Config (.sourcepawn-tools.lua, etc.)
	-- =========================================================================
	local config_module = require("sourcepawn-tools.config")
	local local_cfg_path = config_module.find_local_config(bufnr)
	if local_cfg_path then
		local local_cfg = config_module.get_for_buffer(bufnr)
		if local_cfg and local_cfg.compiler and local_cfg.compiler.include_dirs then
			for _, cdir in ipairs(local_cfg.compiler.include_dirs) do
				local d = cdir
				if not M.is_absolute(d) then
					local base_dir = M.dirname(local_cfg_path) or root_dir
					d = base_dir .. "/" .. d
				end
				add_dir(d)
			end
		end
	end

	-- =========================================================================
	-- TIER 3: Plugin Config & Global Fallbacks (Lowest Priority)
	-- =========================================================================
	if custom_dirs and type(custom_dirs) == "table" then
		for _, cdir in ipairs(custom_dirs) do
			add_dir(cdir)
		end
	end

	-- Global extension fallbacks
	local vs_matches =
		vim.fn.glob(vim.fn.expand("~/.vscode/extensions/sarrus.sourcepawn-vscode-*/sourcemod/include"), false, true)
	if #vs_matches > 0 then
		add_dir(vs_matches[#vs_matches])
	end

	return dirs
end

return M
