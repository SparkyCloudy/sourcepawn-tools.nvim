describe("compiler", function()
	local M

	before_each(function()
		package.loaded["sourcepawn-tools.compiler.init"] = nil
		M = require("sourcepawn-tools.compiler.init")
	end)

	it("loads without error", function()
		assert.is_not_nil(M)
	end)

	it("M.compile is a function", function()
		assert.is_function(M.compile)
	end)

	it("M.build_all is a function", function()
		assert.is_function(M.build_all)
	end)

	-- Note: M.compile() triggers vim.fn.jobstart() for spcomp.
	-- We only verify the API surface here; end-to-end compilation is tested manually.
end)
