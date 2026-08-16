local lazy = require("sourcepawn-tools.lazy")
local path = lazy.require("sourcepawn-tools.utils.path")
local config = lazy.require("sourcepawn-tools.config")
local executable = lazy.require("sourcepawn-tools.executable")
local root = lazy.require("sourcepawn-tools.lsp.root")
local lsp = lazy.require("sourcepawn-tools.lsp")
local ui = lazy.require("sourcepawn-tools.ui")

local M = {}

---Run health check and report environment status
function M.doctor()
	local current_file = vim.api.nvim_buf_get_name(0)
	local cfg = config.get_for_buffer(0)
	local local_cfg_path = config.find_local_config(0)
	local main_file = root.find_main_file(current_file)
	local manual_override = root.get_manual_main()
	local lsp_path = executable.get_lsp_path()
	local spcomp_path = executable.get_compiler_path(0)
	local spformat_path = executable.get_formatter_path()
	local inc_dirs = path.get_include_dirs(0, cfg.compiler and cfg.compiler.include_dirs)
	local clients = lsp.get_clients(0)

	local info = {
		"=== SourcePawn Doctor ===",
		"",
		"1. Workspace Configuration:",
		"   Local Config: " .. (local_cfg_path and ("✓ " .. local_cfg_path) or "none (using global defaults)"),
		"",
		"2. Main Entry Point Script:",
		"   Current File: " .. (current_file ~= "" and path.basename(current_file) or "none"),
		"   Detected Main File: " .. (main_file and path.basename(main_file) or "none"),
		"   Configured Main: "
			.. ((cfg.compiler and cfg.compiler.main_file) or manual_override or "none (auto-detect)"),
		"",
		"3. Language Server (sourcepawn-studio):",
		"   Path: " .. (lsp_path or "NOT FOUND"),
		"   Status: " .. (lsp_path and path.exists(lsp_path) and "✓ Detected" or "✗ Not found"),
		"",
		"4. Compiler (spcomp / spcomp64):",
		"   Path: " .. (spcomp_path or "NOT FOUND"),
		"   Status: " .. (spcomp_path and path.exists(spcomp_path) and "✓ Detected" or "✗ Not found"),
		"",
		"5. Formatter (clang-format):",
		"   Path: " .. (spformat_path or "NOT FOUND"),
		"   Status: "
			.. (
				spformat_path
					and (path.exists(spformat_path) or vim.fn.executable(spformat_path) == 1)
					and "✓ Detected"
				or "✗ Not found"
			),
		"",
		"6. Status LSP Attached: "
			.. (#clients > 0 and ("✓ Active (Client ID: " .. clients[1].id .. ")") or "✗ Inactive"),
		"",
		"7. Include Directories (" .. #inc_dirs .. "):",
	}

	for _, dir in ipairs(inc_dirs) do
		table.insert(info, "   - " .. dir)
	end

	ui.notify(info, ui.INFO, { title = "SourcePawn Doctor" })
end

return M
