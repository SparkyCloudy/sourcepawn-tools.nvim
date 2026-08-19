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

	-- Note: M.format() triggers an async vim.fn.jobstart() call (clang-format).
	-- We only verify the API surface here; end-to-end formatting is tested manually.
end)
