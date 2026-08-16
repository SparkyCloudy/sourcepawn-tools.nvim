local M = {
	ERROR = vim.log.levels.ERROR,
	WARN = vim.log.levels.WARN,
	INFO = vim.log.levels.INFO,
	DEBUG = vim.log.levels.DEBUG,
}

---Post a notification message to the UI
---@param msg string | string[]
---@param level integer?
---@param opts {title?: string, timeout?: number, once?: boolean}?
function M.notify(msg, level, opts)
	opts = opts or {}
	level = level or M.INFO
	if type(msg) == "table" then
		msg = table.concat(msg, "\n")
	end
	if not msg or msg == "" then
		return
	end

	local notify_opts = {
		title = opts.title or "SourcePawn",
		timeout = opts.timeout,
		icon = "",
	}

	if opts.once then
		vim.notify_once(msg, level, notify_opts)
	else
		vim.notify(msg, level, notify_opts)
	end
end

---Set quickfix list with items and optionally open it
---@param items table[]
---@param title string?
---@param open boolean?
function M.set_quickfix(items, title, open)
	title = title or "SourcePawn Compiler Errors"
	if items and #items > 0 then
		vim.fn.setqflist({}, "r", { title = title, items = items })
		if open ~= false then
			vim.cmd("copen")
		end
	else
		vim.fn.setqflist({}, "r")
		vim.cmd("cclose")
	end
end

---Close quickfix list
function M.close_quickfix()
	vim.fn.setqflist({}, "r")
	vim.cmd("cclose")
end

return M
