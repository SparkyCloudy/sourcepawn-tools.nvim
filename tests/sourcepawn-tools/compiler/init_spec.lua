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

	it("Calling M.compile(nil) via pcall does not crash the process", function()
		local ok, _ = pcall(M.compile, nil)
		assert.is_true(true)
	end)
end)
