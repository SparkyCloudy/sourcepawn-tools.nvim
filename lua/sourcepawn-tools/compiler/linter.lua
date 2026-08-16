local lazy = require("sourcepawn-tools.lazy")
local path = lazy.require("sourcepawn-tools.utils.path")
local config = lazy.require("sourcepawn-tools.config")
local executable = lazy.require("sourcepawn-tools.executable")
local root = lazy.require("sourcepawn-tools.lsp.root")

local M = {}

local sourcepawn_ns = vim.api.nvim_create_namespace("sourcepawn_realtime_lint")
local lint_timer = nil

---Run realtime linting on buffer
---@param bufnr integer?
function M.run_lint(bufnr)
	local cfg = config.get_for_buffer(bufnr)
	if not cfg.diagnostics or not cfg.diagnostics.realtime then
		return
	end

	bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local file = path.normalize(vim.api.nvim_buf_get_name(bufnr))
	if not file or file == "" then
		return
	end

	local ext = path.ext(file)
	if ext ~= "sp" and ext ~= "inc" then
		return
	end

	local spcomp = executable.get_compiler_path(bufnr)
	if not spcomp or not path.exists(spcomp) then
		return
	end

	local main_file = root.find_main_file(file)
	local is_submodule = (main_file and main_file ~= file)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local file_dir = path.dirname(file) or vim.uv.cwd() or ""
	local file_name = path.basename(file)
	local temp_buffer_file = file_dir .. "/.__tmp_lint_" .. file_name
	local temp_main_file = nil

	-- Write current buffer contents to shadow file
	local f = io.open(temp_buffer_file, "w")
	if not f then
		return
	end
	f:write(table.concat(lines, "\n"))
	f:close()

	local compile_target = temp_buffer_file

	-- If editing a submodule, generate a shadow main script pointing to the shadow file
	if is_submodule and main_file and path.is_readable(main_file) then
		local mf = io.open(main_file, "r")
		if mf then
			local main_content = mf:read("*a") or ""
			mf:close()

			local main_dir = path.dirname(main_file) or file_dir
			local main_stem = path.stem(main_file)
			temp_main_file = main_dir .. "/.__tmp_main_" .. main_stem .. ".sp"

			local rel_name = path.basename(file)
			local pattern = '(["<][^"<>]-)' .. vim.pesc(rel_name) .. '([">])'
			local replaced_content = main_content:gsub(pattern, "%1.__tmp_lint_" .. rel_name .. "%2")

			local tmf = io.open(temp_main_file, "w")
			if tmf then
				tmf:write(replaced_content)
				tmf:close()
				compile_target = temp_main_file
			end
		end
	end

	local temp_out = path.normalize(vim.fn.tempname() .. ".smx")
	local cmd = { spcomp, "-v0", "-o" .. temp_out }
	if cfg.compiler and cfg.compiler.options and type(cfg.compiler.options) == "table" then
		for _, opt in ipairs(cfg.compiler.options) do
			table.insert(cmd, opt)
		end
	end

	local inc_dirs = path.get_include_dirs(bufnr, cfg.compiler and cfg.compiler.include_dirs)
	for _, dir in ipairs(inc_dirs) do
		table.insert(cmd, "-i" .. dir)
	end
	table.insert(cmd, "-i" .. file_dir)
	if is_submodule and main_file then
		local mf_dir = path.dirname(main_file)
		if mf_dir then
			table.insert(cmd, "-i" .. mf_dir)
		end
	end
	table.insert(cmd, compile_target)

	vim.system(cmd, { text = true }, function(obj)
		-- Clean up shadow files immediately
		pcall(vim.uv.fs_unlink, temp_buffer_file)
		if temp_main_file then
			pcall(vim.uv.fs_unlink, temp_main_file)
		end
		pcall(vim.uv.fs_unlink, temp_out)
		pcall(vim.uv.fs_unlink, temp_buffer_file:gsub("%.%w+$", ".smx"))

		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end

			local output = (obj.stdout or "") .. "\n" .. (obj.stderr or "")
			local diagnostics = {}
			local target_base = path.basename(file):lower()
			local temp_base = ".__tmp_lint_" .. target_base

			for line in output:gmatch("[^\r\n]+") do
				local err_file, lnum_str, sev_str, code, msg =
					line:match("^(.-)%((%d+)%)%s*:%s*(%a+)%s*(%d+)%s*:%s*(.+)$")
				if err_file and lnum_str and sev_str and msg then
					local err_base = path.basename(err_file):lower()

					-- Filter diagnostics specifically for the current active buffer
					if err_base == target_base or err_base == temp_base then
						local severity = (sev_str:lower() == "error") and vim.diagnostic.severity.ERROR
							or vim.diagnostic.severity.WARN
						local line_idx = math.max(0, (tonumber(lnum_str) or 1) - 1)
						local current_lines = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)
						local line_text = current_lines[1] or ""

						local first_non_ws = line_text:find("%S")
						local col = first_non_ws and (first_non_ws - 1) or 0
						local end_col = math.max(col + 1, #line_text)

						table.insert(diagnostics, {
							source = "spcomp",
							lnum = line_idx,
							end_lnum = line_idx,
							col = col,
							end_col = end_col,
							severity = severity,
							message = msg .. " (error " .. code .. ")",
							code = code,
						})
					end
				end
			end

			-- Clear stale LSP diagnostics while editing so real-time linter is the single source of truth
			local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "sourcepawn" })
			for _, client in ipairs(clients) do
				local lsp_ns = vim.lsp.diagnostic.get_namespace(client.id)
				if lsp_ns then
					vim.diagnostic.reset(lsp_ns, bufnr)
				end
			end

			vim.diagnostic.set(sourcepawn_ns, bufnr, diagnostics)
		end)
	end)
end

---Debounced wrapper for realtime linting
---@param bufnr integer?
---@param delay_ms integer?
function M.debounce_lint(bufnr, delay_ms)
	local cfg = config.get_for_buffer(bufnr)
	delay_ms = delay_ms or (cfg.diagnostics and cfg.diagnostics.debounce_ms) or 350
	if lint_timer then
		lint_timer:stop()
		if not lint_timer:is_closing() then
			lint_timer:close()
		end
		lint_timer = nil
	end

	local timer = vim.uv.new_timer()
	if not timer then
		return
	end

	lint_timer = timer
	lint_timer:start(
		delay_ms,
		0,
		vim.schedule_wrap(function()
			if lint_timer then
				lint_timer:stop()
				if not lint_timer:is_closing() then
					lint_timer:close()
				end
				lint_timer = nil
			end
			M.run_lint(bufnr)
		end)
	)
end

---Clear realtime linter diagnostics for a buffer
---@param bufnr integer?
function M.clear_lint(bufnr)
	bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.diagnostic.reset(sourcepawn_ns, bufnr)
	end
end

return M
