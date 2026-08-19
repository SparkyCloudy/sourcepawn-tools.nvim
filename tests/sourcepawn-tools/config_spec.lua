describe("config", function()
	local M

	before_each(function()
		package.loaded["sourcepawn-tools.config"] = nil
		M = require("sourcepawn-tools.config")
	end)

	it("loads without error", function()
		assert.is_not_nil(M)
	end)

	it("default config has correct structure", function()
		local cfg = M.get()
		assert.is_true(cfg.lsp.enabled)
		assert.are.same(150, cfg.lsp.debounce_text_changes)
		assert.are.same("auto", cfg.compiler.default_output)
		assert.are.same("<leader>cc", cfg.keymaps.compile)
	end)

	it("M.set({}) merges and returns config table", function()
		local cfg = M.set({})
		assert.is_true(cfg.lsp.enabled)
		assert.are.same("auto", cfg.compiler.default_output)
	end)

	it("M.set({lsp={enabled=false}}) overrides just lsp.enabled, keeps compiler intact", function()
		local cfg = M.set({ lsp = { enabled = false } })
		assert.is_false(cfg.lsp.enabled)
		assert.are.same("auto", cfg.compiler.default_output)
	end)

	it("M.set(nil) resets to defaults without crash", function()
		M.set({ lsp = { enabled = false } })
		local cfg = M.set(nil)
		assert.is_true(cfg.lsp.enabled)
	end)

	it("M.get() returns a table", function()
		assert.is_table(M.get())
	end)

	it("M.get_for_buffer(0) returns a table", function()
		assert.is_table(M.get_for_buffer(0))
	end)

	it("M.clear_local_cache() runs without error", function()
		local ok = pcall(M.clear_local_cache)
		assert.is_true(ok)
	end)

	it("After M.set({lsp={enabled=false}}), M.get().lsp.enabled is false", function()
		M.set({ lsp = { enabled = false } })
		assert.is_false(M.get().lsp.enabled)
	end)

	it("After M.set(nil), M.get().lsp.enabled is true", function()
		M.set({ lsp = { enabled = false } })
		M.set(nil)
		assert.is_true(M.get().lsp.enabled)
	end)
end)
