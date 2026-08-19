local M = {}

function M.with_tmpdir(fn)
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local ok, err = pcall(fn, dir)
	vim.fn.delete(dir, "rf")
	if not ok then
		error(err)
	end
end

function M.write_file(filepath, content)
	local dir = vim.fn.fnamemodify(filepath, ":h")
	vim.fn.mkdir(dir, "p")
	local f = io.open(filepath, "w")
	if f then
		f:write(content)
		f:close()
	end
end

function M.read_file(filepath)
	local f = io.open(filepath, "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

function M.is_windows()
	return vim.fn.has("win32") == 1
end

function M.reset_module(mod_name)
	package.loaded[mod_name] = nil
end

function M.assert_contains(str, pattern)
	assert.is_true(str:find(pattern) ~= nil, string.format("Expected '%s' to contain '%s'", str, pattern))
end

return M
