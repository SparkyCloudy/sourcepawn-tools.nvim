local lazy = require("sourcepawn-tools.lazy")
local path = lazy.require("sourcepawn-tools.utils.path")
local ui = lazy.require("sourcepawn-tools.ui")

local M = {}

---Get the local plugin binary directory
---@return string
function M.get_bin_dir()
	local base = vim.fs.normalize(vim.fn.stdpath("data") .. "/sourcepawn-tools/bin")
	if not path.exists(base) then
		vim.fn.mkdir(base, "p")
	end
	return base
end

---Determine platform identifier
---@return { os: string, arch: string, vsix_target: string, format_asset: string, format_bin: string, lsp_bin: string }
local function get_platform_info()
	local is_win = vim.fn.has("win32") == 1
	local is_mac = vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1
	local is_arm = (vim.uv.os_uname().machine or ""):match("arm") or (vim.uv.os_uname().machine or ""):match("aarch64")

	if is_win then
		return {
			os = "windows",
			arch = is_arm and "arm64" or "x64",
			vsix_target = is_arm and "win32-arm64" or "win32-x64",
			format_asset = "sp_format-windows.zip",
			format_bin = "sp_format.exe",
			lsp_bin = "sourcepawn-studio.exe",
		}
	elseif is_mac then
		return {
			os = "macos",
			arch = is_arm and "arm64" or "x64",
			vsix_target = is_arm and "darwin-arm64" or "darwin-x64",
			format_asset = "sp_format-macos.zip",
			format_bin = "sp_format",
			lsp_bin = "sourcepawn-studio",
		}
	else
		return {
			os = "linux",
			arch = is_arm and "arm64" or "x64",
			vsix_target = is_arm and "linux-arm64" or "linux-x64",
			format_asset = "sp_format-linux.tar.gz",
			format_bin = "sp_format",
			lsp_bin = "sourcepawn-studio",
		}
	end
end

-- =========================================================================
-- [SPFormat Installer - Commented out for experimentation]
-- =========================================================================
-- ---Download and extract SPFormat official binary
-- ---@param callback fun(success: boolean, err: string?)?
-- function M.install_sp_format(callback)
-- 	local info = get_platform_info()
-- 	local bin_dir = M.get_bin_dir()
-- 	local download_url = "https://github.com/Sarrus1/SPFormat/releases/latest/download/" .. info.format_asset
-- 	local temp_archive = vim.fs.normalize(vim.fn.tempname() .. "_" .. info.format_asset)
-- 	ui.notify("Downloading SPFormat binary (" .. info.format_asset .. ") ...", ui.INFO)
-- 	...
-- end

---Download and extract sourcepawn-studio LSP binary from Open-VSX
---@param callback fun(success: boolean, err: string?)?
function M.install_lsp(callback)
	local info = get_platform_info()
	local bin_dir = M.get_bin_dir()
	local vsix_url = ("https://open-vsx.org/api/Sarrus/sourcepawn-vscode/%s/8.1.8/file/Sarrus.sourcepawn-vscode-8.1.8@%s.vsix"):format(
		info.vsix_target,
		info.vsix_target
	)
	local temp_vsix = vim.fs.normalize(vim.fn.tempname() .. "_sourcepawn-vscode.zip")
	local extract_temp = vim.fs.normalize(vim.fn.tempname() .. "_vsix_ext")
	vim.fn.mkdir(extract_temp, "p")

	ui.notify("Downloading sourcepawn-studio LSP (" .. info.vsix_target .. ") ...", ui.INFO)

	-- 1. Download VSIX archive
	local dl_cmd = { "curl", "-sSL", vsix_url, "-o", temp_vsix }
	vim.system(dl_cmd, { text = true }, function(dl_res)
		if dl_res.code ~= 0 or not path.exists(temp_vsix) then
			pcall(vim.uv.fs_unlink, temp_vsix)
			vim.schedule(function()
				local err = "Failed to download LSP package from " .. vsix_url
				ui.notify(err, ui.ERROR)
				if callback then
					callback(false, err)
				end
			end)
			return
		end

		-- 2. Extract archive
		local extract_cmd
		if path.is_windows then
			extract_cmd = {
				"powershell",
				"-NoProfile",
				"-Command",
				("Expand-Archive -Path '%s' -DestinationPath '%s' -Force"):format(
					temp_vsix:gsub("/", "\\"),
					extract_temp:gsub("/", "\\")
				),
			}
		else
			extract_cmd = { "unzip", "-o", temp_vsix, "-d", extract_temp }
		end

		vim.system(extract_cmd, { text = true }, function(ex_res)
			pcall(vim.uv.fs_unlink, temp_vsix)
			vim.schedule(function()
				local lsp_extracted = path.normalize(extract_temp .. "/extension/languageServer/" .. info.lsp_bin)
				local target_bin = path.normalize(bin_dir .. "/" .. info.lsp_bin)

				if path.exists(lsp_extracted) then
					-- Copy binary using libuv fs_copyfile
					local ok, _ = pcall(vim.uv.fs_copyfile, lsp_extracted, target_bin)
					if not ok or not path.exists(target_bin) then
						-- Fallback system copy
						if path.is_windows then
							vim.fn.system({
								"cmd",
								"/c",
								"copy",
								"/y",
								lsp_extracted:gsub("/", "\\"),
								target_bin:gsub("/", "\\"),
							})
						else
							vim.fn.system({ "cp", "-f", lsp_extracted, target_bin })
						end
					end

					if not path.is_windows and path.exists(target_bin) then
						vim.fn.setfperm(target_bin, "rwxr-xr-x")
					end
				end

				-- Clean up temp folder
				if path.is_windows then
					pcall(vim.fn.system, { "cmd", "/c", "rmdir", "/s", "/q", extract_temp:gsub("/", "\\") })
				else
					pcall(vim.fn.system, { "rm", "-rf", extract_temp })
				end

				if path.exists(target_bin) then
					ui.notify("✓ sourcepawn-studio LSP installed successfully at " .. target_bin, ui.INFO)
					if callback then
						callback(true)
					end
				else
					local err = "Failed to extract sourcepawn-studio LSP binary: " .. (ex_res.stderr or "")
					ui.notify(err, ui.ERROR)
					if callback then
						callback(false, err)
					end
				end
			end)
		end)
	end)
end

-- =========================================================================
-- [SPFormat Installer - Commented for experimentation]
-- =========================================================================
-- ---Download and extract SPFormat official binary
-- ---@param callback fun(success: boolean, err: string?)?
-- function M.install_formatter(callback)
--   local info = get_platform_info()
--   local bin_dir = M.get_bin_dir()
--   local download_url = "https://github.com/Sarrus1/SPFormat/releases/latest/download/" .. info.format_asset
--   ...
-- end

---Install formatter (clang-format via Mason or guidance)
---@param callback fun(success: boolean, err: string?)?
function M.install_formatter(callback)
	local has_mason, registry = pcall(require, "mason-registry")
	if has_mason and registry then
		if registry.is_installed("clang-format") then
			ui.notify("✓ clang-format is already installed via Mason!", ui.INFO)
			if callback then
				callback(true)
			end
			return
		end

		ui.notify("Installing clang-format via Mason ...", ui.INFO)
		local ok, pkg = pcall(registry.get_package, "clang-format")
		if ok and pkg then
			pkg:install():once("closed", function()
				vim.schedule(function()
					if pkg:is_installed() then
						ui.notify("✓ clang-format installed successfully via Mason!", ui.INFO)
						if callback then
							callback(true)
						end
					else
						local err = "Failed to install clang-format via Mason"
						ui.notify(err, ui.ERROR)
						if callback then
							callback(false, err)
						end
					end
				end)
			end)
			return
		end
	end

	-- Fallback if Mason command exists without registry API
	if vim.fn.exists(":MasonInstall") == 2 then
		vim.cmd("MasonInstall clang-format")
		ui.notify("Triggered :MasonInstall clang-format", ui.INFO)
		if callback then
			callback(true)
		end
	else
		ui.notify(
			"clang-format is used for formatting.\nPlease install via Mason (:MasonInstall clang-format) or system package manager (winget/brew/apt).",
			ui.WARN
		)
		if callback then
			callback(false, "Mason not found")
		end
	end
end

---Install or update official Treesitter parser for SourcePawn
---@param callback fun(success: boolean, err: string?)?
function M.install_treesitter(callback)
	if vim.fn.exists(":TSInstall") == 2 or vim.fn.exists(":TSUpdate") == 2 then
		ui.notify("Installing/updating SourcePawn Treesitter parser from official repo ...", ui.INFO)
		vim.cmd("TSInstall sourcepawn")
		if callback then
			callback(true)
		end
	else
		ui.notify(
			"nvim-treesitter command not found. Please install 'nvim-treesitter/nvim-treesitter' to enable syntax highlighting.",
			ui.WARN
		)
		if callback then
			callback(false, "nvim-treesitter not installed")
		end
	end
end

---Install all tools (LSP, Formatter, and Treesitter parser)
---@param callback fun(success: boolean)?
function M.install_all(callback)
	M.install_lsp(function(ok_lsp)
		M.install_formatter(function(ok_fmt)
			M.install_treesitter(function(ok_ts)
				if callback then
					callback(ok_lsp and ok_fmt and ok_ts)
				end
			end)
		end)
	end)
end

return M
