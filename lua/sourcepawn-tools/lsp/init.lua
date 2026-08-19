local lazy = require("sourcepawn-tools.lazy")
local path = lazy.require("sourcepawn-tools.utils.path")
local config = lazy.require("sourcepawn-tools.config")
local executable = lazy.require("sourcepawn-tools.executable")
local root = lazy.require("sourcepawn-tools.lsp.root")
local autosave = lazy.require("sourcepawn-tools.lsp.autosave")

local M = {}

M.root = root
M.autosave = autosave

---Get merged LSP server configuration
---@param bufnr integer?
---@return table?
function M.get_server_config(bufnr)
	local lsp_path = executable.get_lsp_path()
	if not lsp_path then
		return nil
	end

	local cfg = config.get_for_buffer(bufnr)
	local spcomp_path = executable.get_compiler_path(bufnr)
	local inc_dirs = path.get_include_dirs(bufnr, cfg.compiler and cfg.compiler.include_dirs)

	local user_cmd = cfg.lsp and cfg.lsp.cmd
	local cmd = user_cmd or { lsp_path }
	if not user_cmd and (cfg.lsp and cfg.lsp.disable_telemetry) then
		table.insert(cmd, "--disable-telemetry")
	end

	local server_config = {
		name = "sourcepawn",
		cmd = cmd,
		filetypes = { "sourcepawn" },
		root_dir = root.resolve_root_dir,
		root_markers = {
			"sourceknight.yaml",
			".sourcepawn-tools.lua",
			".sourcepawn.lua",
			".spconfig.lua",
			".git",
			"addons",
		},
		flags = {
			debounce_text_changes = (cfg.lsp and cfg.lsp.debounce_text_changes) or 150,
		},
		-- Filter out verbose grammar token dumps from sourcepawn-studio's internal parser
		handlers = {
			["textDocument/publishDiagnostics"] = function(err, result, ctx, config_tbl)
				if result and result.diagnostics then
					local filtered = {}
					for _, diag in ipairs(result.diagnostics) do
						local msg = diag.message or ""
						local is_messy_parser = diag.source == "sourcepawn-studio" and msg:match("^expected ")
						if not is_messy_parser then
							table.insert(filtered, diag)
						end
					end
					result.diagnostics = filtered
				end
				vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config_tbl)
			end,
		},
		settings = vim.tbl_deep_extend("force", {
			SourcePawnLanguageServer = {
				compiler = {
					path = spcomp_path,
					onSave = true,
				},
				includeDirectories = inc_dirs,
				linter = {
					disable = true, -- Favor clean spcomp diagnostics over internal AST parser errors
				},
			},
		}, (cfg.lsp and cfg.lsp.settings) or {}),
	}

	return server_config
end

---Register LSP with Neovim 0.11+ native vim.lsp.config and legacy nvim-lspconfig
function M.setup()
	if not config.lsp.enabled then
		return
	end

	local s_config = M.get_server_config()
	if not s_config then
		return
	end

	-- 1. Neovim 0.11+ Native Declarative LSP configuration
	if vim.lsp and vim.lsp.config then
		vim.lsp.config.sourcepawn = s_config
		if vim.lsp.enable then
			vim.lsp.enable("sourcepawn")
		end
	end

	-- 2. Legacy nvim-lspconfig integration for compatibility
	local has_lspconfig, _ = pcall(require, "lspconfig")
	if has_lspconfig then
		local configs = require("lspconfig.configs")
		if not configs.sourcepawn then
			configs.sourcepawn = {
				default_config = s_config,
			}
		end
	end
end

---Attach LSP client to buffer
---@param bufnr integer?
function M.attach(bufnr)
	if not config.lsp.enabled then
		return
	end

	bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	-- Prevent duplicate client attachment to the same buffer
	local active_clients = vim.lsp.get_clients({ bufnr = bufnr, name = "sourcepawn" })
	if #active_clients > 0 then
		return
	end

	local s_config = M.get_server_config(bufnr)
	if not s_config then
		return
	end

	local root_dir = root.resolve_root_dir(bufnr)
	s_config.root_dir = root_dir

	vim.lsp.start(s_config, { bufnr = bufnr })
end

---Get attached SourcePawn clients
---@param bufnr integer?
---@return table[]
function M.get_clients(bufnr)
	local filter = { name = "sourcepawn" }
	if bufnr and bufnr ~= 0 then
		filter.bufnr = bufnr
	end
	return vim.lsp.get_clients(filter)
end

return M
