describe("codegen", function()
  local M
  
  before_each(function()
    package.loaded['sourcepawn-tools.codegen'] = nil
    M = require("sourcepawn-tools.codegen")
  end)

  it("loads without error", function()
    assert.is_not_nil(M)
  end)

  it("M.generate_doc is a function", function()
    assert.is_function(M.generate_doc)
  end)

  it("M.new_plugin is a function", function()
    assert.is_function(M.new_plugin)
  end)

  it("M.new_module is a function", function()
    assert.is_function(M.new_module)
  end)
end)
