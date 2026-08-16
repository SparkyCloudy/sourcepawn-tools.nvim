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
	-- 1. Compilation commands
	create_cmd("SourcepawnCompile", function(opts)
		local target = (opts.args and opts.args ~= "") and opts.args or nil
		compiler.compile(target)
	end, {
		nargs = "?",
		complete = "file",
		desc = "Compile current plugin / main entry script (Single Compile)",
	})

	create_cmd("SourcepawnBuild", function()
		compiler.build_all()
	end, {
		desc = "Build all main plugins in workspace (Batch Build)",
	})

	-- 2. Doctor & Diagnostics
	create_cmd("SourcepawnDoctor", function()
		doctor.doctor()
	end, {
		desc = "Check SourcePawn LSP, compiler, and environment status",
	})

	-- 3. Main Entry File overrides
	create_cmd("SourcepawnSetMain", function(opts)
		local file = (opts.args and opts.args ~= "") and opts.args or nil
		local set_file = root.set_manual_main(file)
		ui.notify("Main Entry Point set to: " .. path.basename(set_file), ui.INFO)
		compiler.linter.run_lint(0)
	end, {
		nargs = "?",
		complete = "file",
		desc = "Set manual main entry point script for compilation and linting",
	})

	create_cmd("SourcepawnUnsetMain", function()
		root.clear_manual_main()
		ui.notify("Main Entry Point reset to auto-detect", ui.INFO)
		compiler.linter.run_lint(0)
	end, {
		desc = "Reset main entry point back to auto-detect",
	})

	-- 4. Formatter
	create_cmd("SourcepawnFormat", function()
		local formatter = require("sourcepawn-tools.formatter")
		formatter.format(0)
	end, {
		desc = "Format active SourcePawn buffer using clang-format",
	})

	-- 5. Binary Installer
	create_cmd("SourcepawnInstall", function(opts)
		local installer = require("sourcepawn-tools.installer")
		local target = (opts.args and opts.args ~= "") and opts.args:lower() or "all"
		if target == "lsp" then
			installer.install_lsp()
		elseif target == "formatter" or target == "format" then
			installer.install_formatter()
		else
			installer.install_all()
		end
	end, {
		nargs = "?",
		complete = function()
			return { "all", "formatter", "lsp" }
		end,
		desc = "Install official LSP (sourcepawn-studio) and Formatter (clang-format via Mason)",
	})

	-- 6. Code Generation & Templates
	create_cmd("SourcepawnDocGen", function()
		local codegen = require("sourcepawn-tools.codegen")
		codegen.generate_doc(0)
	end, {
		desc = "Generate Doxygen doc comment for function under cursor",
	})

	create_cmd("SourcepawnNewPlugin", function(opts)
		local codegen = require("sourcepawn-tools.codegen")
		codegen.new_plugin(opts.args)
	end, {
		nargs = "?",
		desc = "Scaffold a new SourcePawn plugin",
	})

	create_cmd("SourcepawnNewModule", function(opts)
		local codegen = require("sourcepawn-tools.codegen")
		codegen.new_module(opts.args)
	end, {
		nargs = "?",
		desc = "Scaffold a new SourcePawn submodule with include guards",
	})

	-- 7. Short Aliases
	create_cmd("SPCompile", function(opts)
		vim.cmd("SourcepawnCompile " .. (opts.args or ""))
	end, { nargs = "?", complete = "file" })

	create_cmd("SPBuild", function()
		vim.cmd("SourcepawnBuild")
	end, {})

	create_cmd("SPDoctor", function()
		vim.cmd("SourcepawnDoctor")
	end, {})

	create_cmd("SPSetMain", function(opts)
		vim.cmd("SourcepawnSetMain " .. (opts.args or ""))
	end, { nargs = "?", complete = "file" })

	create_cmd("SPUnsetMain", function()
		vim.cmd("SourcepawnUnsetMain")
	end, {})

	create_cmd("SPFormat", function()
		vim.cmd("SourcepawnFormat")
	end, {})

	create_cmd("SPInstall", function(opts)
		vim.cmd("SourcepawnInstall " .. (opts.args or ""))
	end, {
		nargs = "?",
		complete = function()
			return { "all", "formatter", "lsp" }
		end,
	})

	create_cmd("SPDocGen", function()
		vim.cmd("SourcepawnDocGen")
	end, {})

	create_cmd("SPNewPlugin", function(opts)
		vim.cmd("SourcepawnNewPlugin " .. (opts.args or ""))
	end, { nargs = "?" })

	create_cmd("SPNewModule", function(opts)
		vim.cmd("SourcepawnNewModule " .. (opts.args or ""))
	end, { nargs = "?" })
end

return M
