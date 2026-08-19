describe("lsp.autosave", function()
  local M
  
  before_each(function()
    package.loaded['sourcepawn-tools.lsp.autosave'] = nil
    local ok, res = pcall(require, "sourcepawn-tools.lsp.autosave")
    if ok then M = res end
  end)

  it("loads without error", function()
    assert.is_not_nil(M)
  end)

  it("returns a table with functions", function()
    assert.is_table(M)
  end)

  it("M.attach is a function or nil", function()
    if M.attach ~= nil then
      assert.is_function(M.attach)
      pcall(M.attach)
    end
  end)

  it("M.detach is a function or nil", function()
    if M.detach ~= nil then
      assert.is_function(M.detach)
    end
  end)
end)
