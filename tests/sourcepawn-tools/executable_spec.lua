describe("executable", function()
	local M

	before_each(function()
		package.loaded["sourcepawn-tools.executable"] = nil
		M = require("sourcepawn-tools.executable")
	end)

	it("loads without error", function()
		assert.is_not_nil(M)
	end)

	it("M.clear_cache() runs without error", function()
		local ok = pcall(M.clear_cache)
		assert.is_true(ok)
	end)

	it("M.get_lsp_path() returns nil or string without crashing", function()
		local ok, res = pcall(M.get_lsp_path)
		assert.is_true(ok)
		if res ~= nil then
			assert.is_string(res)
		end
	end)

	it("M.get_formatter_path() returns nil or string without crashing", function()
		local ok, res = pcall(M.get_formatter_path)
		assert.is_true(ok)
		if res ~= nil then
			assert.is_string(res)
		end
	end)

	it("Result of M.get_lsp_path() is nil or type=='string'", function()
		local res = M.get_lsp_path()
		assert.is_true(res == nil or type(res) == "string")
	end)

	it("Result of M.get_formatter_path() is nil or type=='string'", function()
		local res = M.get_formatter_path()
		assert.is_true(res == nil or type(res) == "string")
	end)
end)
