local lazy = require("sourcepawn-tools.lazy")
local config = lazy.require("sourcepawn-tools.config")

local M = {}

local save_timers = {}

---Trigger debounced silent auto-save for buffer to trigger LSP didSave diagnostics
---@param bufnr integer?
---@param delay_ms integer?
function M.debounce_save(bufnr, delay_ms)
	bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local cfg = config.get_for_buffer(bufnr)
	local auto_save_cfg = cfg.lsp and cfg.lsp.auto_save
	if not auto_save_cfg then
		return
	end

	local debounce_time = delay_ms or (type(auto_save_cfg) == "table" and auto_save_cfg.debounce_ms) or 500

	if save_timers[bufnr] then
		save_timers[bufnr]:stop()
		if not save_timers[bufnr]:is_closing() then
			save_timers[bufnr]:close()
		end
		save_timers[bufnr] = nil
	end

	local timer = vim.uv.new_timer()
	if not timer then
		return
	end

	save_timers[bufnr] = timer
	timer:start(
		debounce_time,
		0,
		vim.schedule_wrap(function()
			if save_timers[bufnr] then
				save_timers[bufnr]:stop()
				if not save_timers[bufnr]:is_closing() then
					save_timers[bufnr]:close()
				end
				save_timers[bufnr] = nil
			end

			if not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end

			local buftype = vim.bo[bufnr].buftype
			local modified = vim.bo[bufnr].modified
			local readonly = vim.bo[bufnr].readonly
			local name = vim.api.nvim_buf_get_name(bufnr)

			if modified and not readonly and buftype == "" and name ~= "" then
				-- Save silently to trigger textDocument/didSave for LSP
				vim.api.nvim_buf_call(bufnr, function()
					vim.cmd("silent! write")
				end)
			end
		end)
	)
end

return M
