describe("utils.path", function()
	local M

	before_each(function()
		package.loaded["sourcepawn-tools.utils.path"] = nil
		M = require("sourcepawn-tools.utils.path")
	end)

	it("loads without error", function()
		assert.is_not_nil(M)
	end)

	it("M.is_windows is a boolean", function()
		assert.is_boolean(M.is_windows)
	end)

	it("M.normalize(path) returns a string for various inputs", function()
		assert.is_string(M.normalize("foo/bar"))
		assert.is_string(M.normalize("foo\\bar"))
	end)

	it("M.normalize('') does not crash", function()
		local res = M.normalize("")
		assert.is_string(res)
	end)

	it("M.normalize(nil) does not crash", function()
		local ok, res = pcall(M.normalize, nil)
		assert.is_true(ok)
		assert.is_string(res)
	end)

	it("M.basename('foo/bar/baz.sp') returns 'baz.sp'", function()
		assert.are.same("baz.sp", M.basename("foo/bar/baz.sp"))
	end)

	it("M.dirname('foo/bar/baz.sp') returns something containing 'bar'", function()
		local res = M.dirname("foo/bar/baz.sp")
		assert.is_true(res:find("bar") ~= nil)
	end)

	it("M.exists(vim.fn.stdpath('config')) returns true", function()
		assert.is_true(M.exists(vim.fn.stdpath("config")))
	end)

	it("M.is_absolute function exists", function()
		assert.is_function(M.is_absolute)
	end)
end)
