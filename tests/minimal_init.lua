-- Resolve plugin root relative to this file (tests/minimal_init.lua -> root)
local script_path = debug.getinfo(1, "S").source:sub(2) -- strip '@'
local plugin_root = script_path:match("^(.*[/\\])tests[/\\]") or "./"
plugin_root = plugin_root:gsub("[/\\]$", "") -- strip trailing slash

vim.opt.rtp:prepend(plugin_root)

-- Discover plenary.nvim from common installation locations
local plenary_paths = {
  vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
  vim.fn.stdpath("data") .. "/site/pack/test/start/plenary.nvim",
  vim.fn.stdpath("data") .. "/site/pack/packer/start/plenary.nvim",
  -- Windows nvim-data (used by CI runner)
  (os.getenv("LOCALAPPDATA") or "") .. "/nvim-data/site/pack/test/start/plenary.nvim",
}

for _, p in ipairs(plenary_paths) do
  if vim.fn.isdirectory(p) == 1 then
    vim.opt.rtp:prepend(p)
    vim.cmd("runtime! plugin/plenary.vim")
    break
  end
end

vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
_G.test_env = true
vim.notify = function() end

