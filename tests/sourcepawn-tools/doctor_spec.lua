describe("doctor", function()
	local M

	before_each(function()
		package.loaded["sourcepawn-tools.doctor"] = nil
		M = require("sourcepawn-tools.doctor")
	end)

	it("loads without error", function()
		assert.is_not_nil(M)
	end)

	it("M.doctor is a function", function()
		assert.is_function(M.doctor)
	end)

	it("Calling M.doctor() in pcall does not raise an error", function()
		local ok = pcall(M.doctor)
		assert.is_true(ok)
	end)
end)
