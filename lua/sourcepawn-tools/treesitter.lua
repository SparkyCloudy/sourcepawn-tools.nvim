local M = {}

---Setup SourcePawn filetypes for Treesitter and Neovim
function M.setup()
	vim.filetype.add({
		extension = {
			sp = "sourcepawn",
			inc = "sourcepawn",
		},
	})
end

return M
