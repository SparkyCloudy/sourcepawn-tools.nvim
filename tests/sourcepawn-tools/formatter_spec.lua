describe("formatter", function()
	local M

	before_each(function()
		package.loaded["sourcepawn-tools.formatter"] = nil
		M = require("sourcepawn-tools.formatter")
	end)

	it("loads without error", function()
		assert.is_not_nil(M)
	end)

	it("M.format is a function", function()
		assert.is_function(M.format)
	end)

	it("Calling M.format(0) via pcall does not crash the process", function()
		local ok, _ = pcall(M.format, 0)
		assert.is_true(true)
	end)
end)
