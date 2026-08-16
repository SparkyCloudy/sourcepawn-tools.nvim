local M = {}

local lazy = require("sourcepawn-tools.lazy")

local config = lazy.require("sourcepawn-tools.config")
local commands = lazy.require("sourcepawn-tools.commands")
local compiler = lazy.require("sourcepawn-tools.compiler")
local doctor = lazy.require("sourcepawn-tools.doctor")
local lsp = lazy.require("sourcepawn-tools.lsp")
local installer = lazy.require("sourcepawn-tools.installer")
local formatter = lazy.require("sourcepawn-tools.formatter")
local treesitter = lazy.require("sourcepawn-tools.treesitter")
local statusline = lazy.require("sourcepawn-tools.statusline")
local codegen = lazy.require("sourcepawn-tools.codegen")
local utils = lazy.require("sourcepawn-tools.utils")
local ui = lazy.require("sourcepawn-tools.ui")
local log = lazy.require("sourcepawn-tools.log")

M.compiler = compiler
M.doctor = doctor
M.lsp = lsp
M.installer = installer
M.formatter = formatter
M.treesitter = treesitter
M.statusline = statusline
M.codegen = codegen
M.utils = utils
M.ui = ui
M.log = log
M.config = config

local AUGROUP = vim.api.nvim_create_augroup("SourcepawnToolsGroup", { clear = true })
local _started = false

---Setup buffer-local keymaps
---@param bufnr integer
local function setup_buffer_keymaps(bufnr)
	local keymaps = config.keymaps or {}
	local set_key = function(lhs, rhs, desc)
		if lhs and lhs ~= false and lhs ~= "" then
			vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = "SourcePawn: " .. desc })
		end
	end

	set_key(keymaps.compile, "<cmd>SourcepawnCompile<CR>", "Compile Current/Main Plugin")
	set_key(keymaps.build_all, "<cmd>SourcepawnBuild<CR>", "Build All Plugins in Workspace")
	set_key(keymaps.doctor, "<cmd>SourcepawnDoctor<CR>", "Doctor Environment Health")
	set_key(keymaps.format or "<leader>cf", "<cmd>SourcepawnFormat<CR>", "Format Active Buffer")

	-- Legacy convenience mappings
	set_key("<leader>spc", "<cmd>SourcepawnCompile<CR>", "Compile Current/Main Plugin")
	set_key("<leader>spb", "<cmd>SourcepawnBuild<CR>", "Build All Plugins in Workspace")
	set_key("<leader>spd", "<cmd>SourcepawnDoctor<CR>", "Doctor Environment Health")
	set_key("<leader>spf", "<cmd>SourcepawnFormat<CR>", "Format Active Buffer")
end

---Initialize plugin features on filetype entry
local function start()
	if not _started then
		_started = true
		treesitter.setup()
		lsp.setup()
		commands.setup()
	end
end

---Setup plugin autocommands
local function setup_autocommands()
	local autocmd = vim.api.nvim_create_autocmd

	-- 1. Initialize on SourcePawn buffer entry
	autocmd({ "FileType" }, {
		group = AUGROUP,
		pattern = "sourcepawn",
		callback = function(args)
			start()
			lsp.attach(args.buf)
			setup_buffer_keymaps(args.buf)
			if config.diagnostics.realtime then
				compiler.linter.debounce_lint(args.buf, 100)
			end
		end,
	})

	-- 2. Real-time live diagnostics on typing
	autocmd({ "TextChanged", "TextChangedI" }, {
		group = AUGROUP,
		pattern = { "*.sp", "*.inc" },
		callback = function(args)
			if config.diagnostics.realtime then
				compiler.linter.debounce_lint(args.buf, config.diagnostics.debounce_ms)
			end
		end,
	})

	-- 3. On Save: Clear realtime shadow diagnostics so LSP handles the saved state cleanly without duplication
	autocmd({ "BufWritePost" }, {
		group = AUGROUP,
		pattern = { "*.sp", "*.inc" },
		callback = function(args)
			compiler.linter.clear_lint(args.buf)
		end,
	})
end

---Public entrypoint for sourcepawn-tools.nvim
---@param user_config sourcepawn.Config?
function M.setup(user_config)
	config.set(user_config)
	start()
	setup_autocommands()
end

return M
