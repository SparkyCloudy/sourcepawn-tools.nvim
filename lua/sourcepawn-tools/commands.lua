local lazy = require("sourcepawn-tools.lazy")
local compiler = lazy.require("sourcepawn-tools.compiler")
local doctor = lazy.require("sourcepawn-tools.doctor")
local root = lazy.require("sourcepawn-tools.lsp.root")
local ui = lazy.require("sourcepawn-tools.ui")
local path = lazy.require("sourcepawn-tools.utils.path")

local M = {}

local function create_cmd(name, callback, opts)
	vim.api.nvim_create_user_command(name, callback, opts or {})
end

---Register all user commands and aliases
function M.setup()
	local commands = {
		{
			names = { "SourcepawnCompile", "SPCompile" },
			callback = function(opts)
				local target = (opts.args and opts.args ~= "") and opts.args or nil
				compiler.compile(target)
			end,
			opts = {
				nargs = "?",
				complete = "file",
				desc = "Compile current plugin / main entry script (Single Compile)",
			},
		},
		{
			names = { "SourcepawnBuild", "SPBuild" },
			callback = function()
				compiler.build_all()
			end,
			opts = {
				desc = "Build all main plugins in workspace (Batch Build)",
			},
		},
		{
			names = { "SourcepawnDoctor", "SPDoctor" },
			callback = function()
				doctor.doctor()
			end,
			opts = {
				desc = "Check SourcePawn LSP, compiler, and environment status",
			},
		},
		{
			names = { "SourcepawnSetMain", "SPSetMain" },
			callback = function(opts)
				local file = (opts.args and opts.args ~= "") and opts.args or nil
				local set_file = root.set_manual_main(file)
				ui.notify("Main Entry Point set to: " .. path.basename(set_file), ui.INFO)
			end,
			opts = {
				nargs = "?",
				complete = "file",
				desc = "Set manual main entry point script for compilation and LSP",
			},
		},
		{
			names = { "SourcepawnUnsetMain", "SPUnsetMain" },
			callback = function()
				root.clear_manual_main()
				ui.notify("Main Entry Point reset to auto-detect", ui.INFO)
			end,
			opts = {
				desc = "Reset main entry point back to auto-detect",
			},
		},
		{
			names = { "SourcepawnFormat", "SPFormat" },
			callback = function()
				local formatter = require("sourcepawn-tools.formatter")
				formatter.format(0)
			end,
			opts = {
				desc = "Format active SourcePawn buffer using clang-format",
			},
		},
		{
			names = { "SourcepawnInstall", "SPInstall" },
			callback = function(opts)
				local installer = require("sourcepawn-tools.installer")
				local target = (opts.args and opts.args ~= "") and opts.args:lower() or "all"
				if target == "lsp" then
					installer.install_lsp()
				elseif target == "formatter" or target == "format" then
					installer.install_formatter()
				elseif target == "treesitter" or target == "ts" then
					installer.install_treesitter()
				else
					installer.install_all()
				end
			end,
			opts = {
				nargs = "?",
				complete = function()
					return { "all", "formatter", "lsp", "treesitter" }
				end,
				desc = "Install official toolchain (sourcepawn-studio LSP, clang-format, and Treesitter parser)",
			},
		},
		{
			names = { "SourcepawnDocGen", "SPDocGen" },
			callback = function()
				local codegen = require("sourcepawn-tools.codegen")
				codegen.generate_doc(0)
			end,
			opts = {
				desc = "Generate Doxygen doc comment for function under cursor",
			},
		},
		{
			names = { "SourcepawnNewPlugin", "SPNewPlugin" },
			callback = function(opts)
				local codegen = require("sourcepawn-tools.codegen")
				codegen.new_plugin(opts.args)
			end,
			opts = {
				nargs = "?",
				desc = "Scaffold a new SourcePawn plugin",
			},
		},
		{
			names = { "SourcepawnNewModule", "SPNewModule" },
			callback = function(opts)
				local codegen = require("sourcepawn-tools.codegen")
				codegen.new_module(opts.args)
			end,
			opts = {
				nargs = "?",
				desc = "Scaffold a new SourcePawn submodule with include guards",
			},
		},
	}

	for _, cmd in ipairs(commands) do
		for _, name in ipairs(cmd.names) do
			create_cmd(name, cmd.callback, cmd.opts)
		end
	end
end

return M
