describe("installer", function()
	local M

	before_each(function()
		package.loaded["sourcepawn-tools.installer"] = nil
		M = require("sourcepawn-tools.installer")
	end)

	it("loads without error", function()
		assert.is_not_nil(M)
	end)

	it("M.install_lsp is a function", function()
		assert.is_function(M.install_lsp)
	end)

	it("M.install_formatter is a function", function()
		assert.is_function(M.install_formatter)
	end)

	it("M.install_treesitter is a function", function()
		assert.is_function(M.install_treesitter)
	end)

	it("M.install_all is a function", function()
		assert.is_function(M.install_all)
	end)
end)
