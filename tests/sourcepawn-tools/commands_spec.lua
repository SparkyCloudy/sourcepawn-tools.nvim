describe("commands", function()
  local M
  
  before_each(function()
    package.loaded['sourcepawn-tools.commands'] = nil
    M = require("sourcepawn-tools.commands")
  end)

  it("loads without error", function()
    assert.is_not_nil(M)
  end)

  it("setup registers global commands", function()
    local ok = pcall(M.setup)
    assert.is_true(ok)
    local cmds = vim.api.nvim_get_commands({})
    local expected_cmds = {
      'SourcepawnCompile', 'SPCompile',
      'SourcepawnInstall', 'SPInstall',
      'SourcepawnDoctor', 'SPDoctor',
      'SourcepawnFormat', 'SPFormat',
      'SourcepawnBuild', 'SPBuild'
    }
    for _, cmd in ipairs(expected_cmds) do
      assert.is_not_nil(cmds[cmd], "Command " .. cmd .. " should be registered")
    end
  end)
end)
