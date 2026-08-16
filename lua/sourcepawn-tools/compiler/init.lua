local lazy = require("sourcepawn-tools.lazy")
local path = lazy.require("sourcepawn-tools.utils.path")
local config = lazy.require("sourcepawn-tools.config")
local executable = lazy.require("sourcepawn-tools.executable")
local root = lazy.require("sourcepawn-tools.lsp.root")
local ui = lazy.require("sourcepawn-tools.ui")

local M = {
	linter = lazy.require("sourcepawn-tools.compiler.linter"),
}

---Determine output .smx path for a compiled plugin
---@param compile_file string
---@param cfg sourcepawn.Config?
---@return string
local function resolve_output_path(compile_file, cfg)
	local stem = path.stem(compile_file)
	local file_dir = path.dirname(compile_file) or vim.uv.cwd() or "."
	local cwd = vim.uv.cwd() or file_dir
	local default_opt = (cfg and cfg.compiler and cfg.compiler.default_output) or "auto"

	if default_opt ~= "auto" then
		if default_opt == "plugins" then
			return path.normalize(cwd .. "/plugins/" .. stem .. ".smx")
		elseif default_opt == "compiled" then
			return path.normalize(cwd .. "/compiled/" .. stem .. ".smx")
		else
			local out_dir = default_opt
			if not path.is_absolute(out_dir) then
				local local_cfg_path = config.find_local_config(compile_file)
				local base_dir = local_cfg_path and path.dirname(local_cfg_path) or cwd
				out_dir = base_dir .. "/" .. out_dir
			end
			return path.normalize(out_dir .. "/" .. stem .. ".smx")
		end
	end

	if path.exists(cwd .. "/plugins") then
		return path.normalize(cwd .. "/plugins/" .. stem .. ".smx")
	elseif path.exists(file_dir .. "/../plugins") then
		return path.normalize(file_dir .. "/../plugins/" .. stem .. ".smx")
	elseif path.exists(cwd .. "/compiled") then
		return path.normalize(cwd .. "/compiled/" .. stem .. ".smx")
	else
		return path.normalize(file_dir .. "/" .. stem .. ".smx")
	end
end

---Compile a single SourcePawn file or its main entry point
---@param target_file string?
function M.compile(target_file)
	local file = target_file
	if not file or file == "" then
		file = vim.api.nvim_buf_get_name(0)
	end

	if not file or file == "" then
		ui.notify("No active file to compile!", ui.WARN)
		return
	end

	file = path.normalize(file)
	local ext = path.ext(file)
	if ext ~= "sp" and ext ~= "inc" then
		ui.notify("Active buffer is not a .sp or .inc file!", ui.WARN)
		return
	end

	local cfg = config.get_for_buffer(file)

	local spcomp = executable.get_compiler_path(file)
	if not spcomp or not path.exists(spcomp) then
		ui.notify("Compiler spcomp executable not found!", ui.ERROR)
		return
	end

	local compile_file = root.find_main_file(file) or file
	local is_main = (compile_file == file)
	local stem = path.stem(compile_file)
	local file_dir = path.dirname(compile_file) or vim.uv.cwd() or "."
	local out_path = resolve_output_path(compile_file, cfg)

	local cmd = { spcomp, "-o" .. out_path }
	if cfg.compiler and cfg.compiler.options and type(cfg.compiler.options) == "table" then
		for _, opt in ipairs(cfg.compiler.options) do
			table.insert(cmd, opt)
		end
	end

	local inc_dirs = path.get_include_dirs(0, cfg.compiler and cfg.compiler.include_dirs)
	for _, dir in ipairs(inc_dirs) do
		table.insert(cmd, "-i" .. dir)
	end
	table.insert(cmd, "-i" .. file_dir)
	table.insert(cmd, compile_file)

	local msg_compile = is_main and ("Compiling " .. stem .. ".sp ...")
		or (
			"Compiling main script ("
			.. path.basename(compile_file)
			.. ") for submodule "
			.. path.basename(file)
			.. " ..."
		)
	ui.notify(msg_compile, ui.INFO)

	vim.system(cmd, { text = true }, function(obj)
		vim.schedule(function()
			local stdout = obj.stdout or ""
			local stderr = obj.stderr or ""
			local output = stdout .. "\n" .. stderr

			if obj.code == 0 then
				ui.close_quickfix()
				ui.notify(
					"✓ Compiled successfully!\nMain: " .. path.basename(compile_file) .. "\nOutput: " .. out_path,
					ui.INFO
				)
				if config.hooks and config.hooks.on_compile_success then
					pcall(config.hooks.on_compile_success, compile_file, out_path)
				end
			else
				local qf_items = {}
				for line in output:gmatch("[^\r\n]+") do
					local err_file, lnum, sev_str, code, msg =
						line:match("^(.-)%((%d+)%)%s*:%s*(%a+)%s*(%d+)%s*:%s*(.+)$")
					if err_file and lnum and msg then
						local resolved_file = vim.fn.fnamemodify(err_file, ":p")
						table.insert(qf_items, {
							filename = resolved_file,
							lnum = tonumber(lnum),
							col = 1,
							text = ("[%s %s] %s"):format(sev_str, code, msg),
							type = (sev_str:lower() == "error") and "E" or "W",
						})
					end
				end

				ui.set_quickfix(qf_items, "SourcePawn Compiler Errors", true)
				ui.notify("✗ Compilation failed with " .. #qf_items .. " error(s)!\n(See Quickfix list)", ui.ERROR)
				if config.hooks and config.hooks.on_compile_error then
					pcall(config.hooks.on_compile_error, compile_file, qf_items)
				end
			end
		end)
	end)
end

---Build all main plugins in the workspace
function M.build_all()
	local cwd = vim.uv.cwd() or ""
	if cwd == "" then
		ui.notify("Invalid working directory!", ui.ERROR)
		return
	end

	local spcomp = executable.get_compiler_path()
	if not spcomp or not path.exists(spcomp) then
		ui.notify("Compiler spcomp executable not found!", ui.ERROR)
		return
	end

	vim.cmd("silent! wall")

	local all_sp_files = vim.fn.glob(cwd .. "/**/*.sp", false, true)
	local root_sp_files = vim.fn.glob(cwd .. "/*.sp", false, true)
	local main_plugins = {}
	local seen = {}

	local function add_plugin(fpath)
		local norm = path.normalize(fpath)
		if not seen[norm] and path.is_readable(norm) then
			if not norm:find("/__tmp_") and not norm:find("/include/") and not norm:find("/%.") then
				local f = io.open(norm, "r")
				if f then
					local content = f:read("*a") or ""
					f:close()
					if content:find("Plugin%s+myinfo") or content:find("myinfo%s*=") or path.dirname(norm) == cwd then
						seen[norm] = true
						table.insert(main_plugins, norm)
					end
				end
			end
		end
	end

	for _, file in ipairs(root_sp_files) do
		add_plugin(file)
	end
	for _, file in ipairs(all_sp_files) do
		add_plugin(file)
	end

	if #main_plugins == 0 then
		ui.notify("No standalone .sp plugins found to build!", ui.WARN)
		return
	end

	local total = #main_plugins
	ui.notify("Starting Build All (" .. total .. " plugin(s) found) ...", ui.INFO)

	local completed = 0
	local success_list = {}
	local fail_list = {}
	local all_qf_items = {}

	for _, plugin_file in ipairs(main_plugins) do
		local stem = path.stem(plugin_file)
		local file_dir = path.dirname(plugin_file) or cwd
		local cfg = config.get_for_buffer(plugin_file)
		local out_path = resolve_output_path(plugin_file, cfg)

		local cmd = { spcomp, plugin_file, "-o" .. out_path }
		local inc_dirs = path.get_include_dirs(0, cfg.compiler and cfg.compiler.include_dirs)
		for _, dir in ipairs(inc_dirs) do
			table.insert(cmd, "-i" .. dir)
		end
		table.insert(cmd, "-i" .. file_dir)

		vim.system(cmd, { text = true }, function(obj)
			vim.schedule(function()
				completed = completed + 1
				local stdout = obj.stdout or ""
				local stderr = obj.stderr or ""
				local output = stdout .. "\n" .. stderr

				if obj.code == 0 then
					table.insert(success_list, stem .. ".smx")
				else
					table.insert(fail_list, stem .. ".sp")
					for line in output:gmatch("[^\r\n]+") do
						local err_file, lnum, sev_str, code, msg =
							line:match("^(.-)%((%d+)%)%s*:%s*(%a+)%s*(%d+)%s*:%s*(.+)$")
						if err_file and lnum and msg then
							local resolved_file = vim.fn.fnamemodify(err_file, ":p")
							table.insert(all_qf_items, {
								filename = resolved_file,
								lnum = tonumber(lnum),
								col = 1,
								text = ("[%s %s] (%s) %s"):format(sev_str, code, stem, msg),
								type = (sev_str:lower() == "error") and "E" or "W",
							})
						end
					end
				end

				if completed == total then
					if #fail_list == 0 then
						ui.close_quickfix()
						ui.notify(
							"✓ Build All Succeeded: "
								.. #success_list
								.. "/"
								.. total
								.. " plugin(s) compiled!\n"
								.. table.concat(success_list, ", "),
							ui.INFO
						)
					else
						ui.set_quickfix(all_qf_items, "SourcePawn Build All Errors", true)
						ui.notify(
							"✗ Build All Finished: "
								.. #success_list
								.. " succeeded, "
								.. #fail_list
								.. " failed!\n(Failed: "
								.. table.concat(fail_list, ", ")
								.. ")",
							ui.ERROR
						)
					end
				end
			end)
		end)
	end
end

return M
