local M = {}

---@class sourcepawn.AutoSaveOpts
---@field enabled? boolean
---@field debounce_ms? integer

---@class sourcepawn.LspOpts
---@field enabled? boolean
---@field cmd? string[]
---@field disable_telemetry? boolean
---@field debounce_text_changes? integer
---@field auto_save? boolean|sourcepawn.AutoSaveOpts
---@field settings? table

---@class sourcepawn.CompilerOpts
---@field path? string
---@field include_dirs? string[]
---@field options? string[]
---@field main_file? string
---@field default_output? string "auto" | "plugins" | "compiled" | string
---@field output_dir? string

---@class sourcepawn.KeymapsOpts
---@field compile? string|false
---@field build_all? string|false
---@field doctor? string|false
---@field format? string|false

---@class sourcepawn.FormatterOpts
---@field options? string[]

---@class sourcepawn.HooksOpts
---@field on_compile_success? fun(file: string, output_smx: string)
---@field on_compile_error? fun(file: string, errors: table[])

---@class sourcepawn.Config
---@field lsp? sourcepawn.LspOpts
---@field compiler? sourcepawn.CompilerOpts
---@field formatter? sourcepawn.FormatterOpts
---@field keymaps? sourcepawn.KeymapsOpts
---@field hooks? sourcepawn.HooksOpts

local default_config = {
	lsp = {
		enabled = true,
		cmd = nil,
		disable_telemetry = true,
		debounce_text_changes = 150,
		auto_save = true, -- Auto-saves quietly on edit to continuously trigger LSP diagnostics
		settings = {},
	},
	compiler = {
		path = nil,
		include_dirs = {},
		options = {},
		main_file = nil,
		default_output = "auto",
	},
	formatter = {
		options = {},
	},
	keymaps = {
		compile = "<leader>cc",
		build_all = "<leader>cb",
		doctor = "<leader>spd",
		format = "<leader>cf",
	},
	hooks = {
		on_compile_success = nil,
		on_compile_error = nil,
	},
}

---@type sourcepawn.Config
local current_config = vim.deepcopy(default_config)

local local_config_cache = {}

---Find local configuration file for a buffer or path
---@param bufnr_or_path (integer|string)?
---@return string?
function M.find_local_config(bufnr_or_path)
	local target_path = bufnr_or_path
	if type(bufnr_or_path) == "number" or not bufnr_or_path then
		local bufnr = (bufnr_or_path and bufnr_or_path ~= 0) and bufnr_or_path or vim.api.nvim_get_current_buf()
		target_path = vim.api.nvim_buf_get_name(bufnr)
	end

	local search_dir = (target_path and target_path ~= "") and vim.fs.dirname(target_path) or vim.uv.cwd()
	if not search_dir or search_dir == "" then
		search_dir = vim.uv.cwd() or "."
	end

	local candidates = {
		".sourcepawn-tools.lua",
		".sourcepawn.lua",
		".spconfig.lua",
		"sourcepawn.json",
		".sourcepawn.json",
	}

	local found = vim.fs.find(candidates, {
		path = search_dir,
		upward = true,
	})

	return found[1]
end

---Load and parse a local configuration file
---@param filepath string
---@return table?
local function load_local_config_file(filepath)
	if not filepath or filepath == "" or vim.fn.filereadable(filepath) ~= 1 then
		return nil
	end

	if filepath:match("%.lua$") then
		local fn, err = loadfile(filepath)
		if fn then
			local ok, res = pcall(fn)
			if ok and type(res) == "table" then
				return res
			end
		end
	elseif filepath:match("%.json$") then
		local f = io.open(filepath, "r")
		if f then
			local content = f:read("*a") or ""
			f:close()
			local ok, res = pcall(vim.json.decode, content)
			if ok and type(res) == "table" then
				return res
			end
		end
	end

	return nil
end

---Get merged configuration for a buffer or path (Global + Local workspace override)
---@param bufnr_or_path (integer|string)?
---@return sourcepawn.Config
function M.get_for_buffer(bufnr_or_path)
	local local_path = M.find_local_config(bufnr_or_path)
	if not local_path then
		return current_config
	end

	local stat = vim.uv.fs_stat(local_path)
	local mtime = stat and stat.mtime and stat.mtime.sec or 0
	local cached = local_config_cache[local_path]

	if cached and cached.mtime == mtime then
		return cached.config
	end

	local local_cfg = load_local_config_file(local_path) or {}
	local merged = vim.tbl_deep_extend("force", current_config, local_cfg)

	local_config_cache[local_path] = {
		mtime = mtime,
		config = merged,
	}

	return merged
end

---Clear local configuration cache
function M.clear_local_cache()
	local_config_cache = {}
end

---Set and merge user configuration
---@param user_config sourcepawn.Config?
---@return sourcepawn.Config
function M.set(user_config)
	if user_config and type(user_config) == "table" then
		current_config = vim.tbl_deep_extend("force", default_config, user_config)
	else
		current_config = vim.deepcopy(default_config)
	end
	local_config_cache = {}
	return current_config
end

---Get current global configuration
---@return sourcepawn.Config
function M.get()
	return current_config
end

return setmetatable(M, {
	__index = function(_, k)
		return current_config[k]
	end,
})
