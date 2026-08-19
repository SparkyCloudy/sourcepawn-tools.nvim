describe("lsp.root", function()
	local M

	before_each(function()
		package.loaded["sourcepawn-tools.lsp.root"] = nil
		M = require("sourcepawn-tools.lsp.root")
	end)

	it("loads without error", function()
		assert.is_not_nil(M)
	end)

	it("M.get_manual_main() initially returns nil", function()
		M.clear_manual_main()
		assert.is_nil(M.get_manual_main())
	end)

	it("M.set_manual_main('/tmp/test.sp') sets and M.get_manual_main() returns normalized path", function()
		local path = require("sourcepawn-tools.utils.path")
		local expected = path.normalize(vim.fn.fnamemodify("/tmp/test.sp", ":p"))
		M.set_manual_main("/tmp/test.sp")
		assert.are.same(expected, M.get_manual_main())
	end)

	it("M.clear_manual_main() makes M.get_manual_main() return nil", function()
		M.set_manual_main("/tmp/test.sp")
		M.clear_manual_main()
		assert.is_nil(M.get_manual_main())
	end)

	it("M.find_main_file(nil) returns nil gracefully", function()
		assert.is_nil(M.find_main_file(nil))
	end)

	it("M.find_main_file('') returns nil", function()
		assert.is_nil(M.find_main_file(""))
	end)

	it("M.clear_cache() runs without error", function()
		local ok = pcall(M.clear_cache)
		assert.is_true(ok)
	end)

	it("M.resolve_root_dir(nil) returns a non-empty string", function()
		local res = M.resolve_root_dir(nil)
		assert.is_string(res)
		assert.is_true(#res > 0)
	end)

	it("M.resolve_root_dir('') returns a non-empty string", function()
		local res = M.resolve_root_dir("")
		assert.is_string(res)
		assert.is_true(#res > 0)
	end)
end)
