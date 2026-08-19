local M = {}

---Setup Treesitter parser and filetype integration
function M.setup()
	-- Register filetypes
	vim.filetype.add({
		extension = {
			sp = "sourcepawn",
			inc = "sourcepawn",
		},
	})

	-- Treesitter configuration integration if available
	local has_ts_parsers, ts_parsers = pcall(require, "nvim-treesitter.parsers")
	if has_ts_parsers and type(ts_parsers) == "table" then
		---@type table<string, any>?
		local parser_configs = nil
		if type(ts_parsers.get_parser_configs) == "function" then
			parser_configs = ts_parsers.get_parser_configs()
		elseif type(ts_parsers.get_parser_configs) == "table" then
			parser_configs = ts_parsers.get_parser_configs
		elseif type(ts_parsers.parser_configs) == "table" then
			parser_configs = ts_parsers.parser_configs
		end

		if parser_configs then
			---@diagnostic disable-next-line: inject-field
			if not parser_configs.sourcepawn then
				---@diagnostic disable-next-line: inject-field
				parser_configs.sourcepawn = {
					install_info = {
						url = "https://github.com/nilshelmig/tree-sitter-sourcepawn",
						files = { "src/parser.c", "src/scanner.c" },
						branch = "main",
						generate_requires_npm = false,
						requires_generate_from_grammar = false,
					},
					filetype = "sourcepawn",
				}
			end
		end
	end
end

return M
