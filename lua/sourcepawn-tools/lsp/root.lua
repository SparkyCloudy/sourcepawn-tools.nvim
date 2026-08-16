local lazy = require("sourcepawn-tools.lazy")
local path = lazy.require("sourcepawn-tools.utils.path")

local M = {}

---@type string?
local manual_main_file = nil

---Set manual override for main entry file
---@param file string?
function M.set_manual_main(file)
	if file and file ~= "" then
		manual_main_file = path.normalize(vim.fn.fnamemodify(file, ":p"))
	else
		manual_main_file = path.normalize(vim.api.nvim_buf_get_name(0))
	end
	return manual_main_file
end

---Clear manual main file override
function M.clear_manual_main()
	manual_main_file = nil
end

---Get current manual main file override
---@return string?
function M.get_manual_main()
	return manual_main_file
end

local main_cache = {}

---Clear main file cache
function M.clear_cache()
	main_cache = {}
end

---Find the main plugin entry point (e.g. plugin.sp) for a given SourcePawn file
---@param target_file string?
---@return string?
function M.find_main_file(target_file)
	if manual_main_file and path.is_readable(manual_main_file) then
		return manual_main_file
	end

	if not target_file or target_file == "" then
		return nil
	end

	local norm_target = path.normalize(target_file)
	if main_cache[norm_target] and path.exists(main_cache[norm_target]) then
		return main_cache[norm_target]
	end

	-- Check if workspace config specifies an explicit main_file
	local config = lazy.require("sourcepawn-tools.config")
	local cfg = config.get_for_buffer(norm_target)
	if cfg and cfg.compiler and cfg.compiler.main_file and cfg.compiler.main_file ~= "" then
		local mf = cfg.compiler.main_file
		if not path.is_absolute(mf) then
			local local_cfg_path = config.find_local_config(norm_target)
			local base_dir = local_cfg_path and path.dirname(local_cfg_path)
				or path.dirname(norm_target)
				or vim.uv.cwd()
				or "."
			mf = base_dir .. "/" .. mf
		end
		mf = path.normalize(mf)
		if path.is_readable(mf) then
			main_cache[norm_target] = mf
			return mf
		end
	end

	local target_name = path.basename(norm_target)
	local target_dir = path.dirname(norm_target)

	-- 1. Check if the target file itself defines Plugin myinfo
	local f = io.open(norm_target, "r")
	if f then
		local content = f:read("*a") or ""
		f:close()
		if content:find("Plugin%s+myinfo") or content:find("myinfo%s*=") or content:find("Extension%s+myinfo") then
			return norm_target
		end
	end

	-- 2. Search parent directories and workspace root for .sp files that include this file or declare myinfo
	local search_dirs = {
		(target_dir and target_dir ~= "") and (target_dir .. "/..") or nil,
		vim.uv.cwd() or "",
		target_dir,
	}

	for _, sdir in ipairs(search_dirs) do
		if sdir and sdir ~= "" then
			local sp_files = vim.fn.glob(sdir .. "/*.sp", false, true)
			for _, candidate in ipairs(sp_files) do
				local cand_norm = path.normalize(candidate)
				if cand_norm ~= norm_target and path.is_readable(cand_norm) then
					local cf = io.open(cand_norm, "r")
					if cf then
						local ccontent = cf:read("*a") or ""
						cf:close()
						if
							ccontent:find(target_name, 1, true)
							or ccontent:find("Plugin%s+myinfo")
							or ccontent:find("myinfo%s*=")
						then
							main_cache[norm_target] = cand_norm
							return cand_norm
						end
					end
				end
			end
		end
	end

	main_cache[norm_target] = norm_target
	return norm_target
end

---Resolve root directory for LSP and tools
---@param fname_or_buf (string|integer)?
---@return string
function M.resolve_root_dir(fname_or_buf)
	local fname = fname_or_buf
	if type(fname_or_buf) == "number" or not fname_or_buf then
		local bufnr = (fname_or_buf and fname_or_buf ~= 0) and fname_or_buf or vim.api.nvim_get_current_buf()
		fname = vim.api.nvim_buf_get_name(bufnr)
	end

	if type(fname) ~= "string" or fname == "" then
		return vim.uv.cwd() or ""
	end

	fname = path.normalize(fname)

	-- 1. Check for local configs, sourceknight, .git, or project structure markers upward from file
	local root = vim.fs.root(fname, {
		".sourcepawn-tools.lua",
		".sourcepawn.lua",
		".spconfig.lua",
		"sourceknight.yaml",
		".sourceknight",
		".git",
		"scripting",
		"plugins",
		"include",
	})
	if root then
		return path.normalize(root)
	end

	-- 2. Resolve root from detected main entry file directory
	local main_file = M.find_main_file(fname)
	if main_file and main_file ~= "" then
		local dir = path.dirname(main_file)
		if dir and dir ~= "" then
			return path.normalize(dir)
		end
	end

	return path.dirname(fname) or vim.uv.cwd() or ""
end

return M
