# sourcepawn-tools.nvim 🚀

A comprehensive Neovim companion plugin for **SourcePawn** and **SourceMod** development.

Orchestrates **Language Server (`sourcepawn-studio`)**, **Treesitter syntax highlighting**, **`spcomp` asynchronous compilation**, **real-time on-typing compiler diagnostics**, and **smart main entry point resolution** in a clean, modular architecture inspired by [`flutter-tools.nvim`](https://github.com/akinsho/flutter-tools.nvim).

---

## ✨ Features

- 📥 **Official Binary Auto-Installer**: Run `:SourcepawnInstall` to automatically download the official `sourcepawn-studio` LSP binary to your local Neovim data folder (`nvim-data/sourcepawn-tools/bin/`) with zero manual setup.
- 💅 **SourcePawn Code Formatter**: Format code seamlessly via `:SourcepawnFormat` (`<leader>cf` / `<leader>spf`) or `conform.nvim` using `clang-format` (with native `SPFormat` support planned).
- ⚡ **Zero-Config Auto-Discovery**: Automatically locates `sourcepawn-studio.exe` LSP, `spcomp.exe` compiler, and Mason/system `clang-format` from local plugin data, system `PATH`, VS Code extensions (`sarrus.sourcepawn-vscode`), or workspace directories.
- 🎯 **Smart Main Entry Point (MainPath)**: Automatically discovers project roots and parent main scripts (e.g. `plugin.sp` with `myinfo`) when editing modular subfiles (`modules/*.sp`), eliminating missing include errors.
- 🔄 **Real-Time Live Diagnostics**: Asynchronous compilation of temporary shadow buffers while typing (`TextChanged`, `TextChangedI`), displaying compiler errors inline via `vim.diagnostic`.
- 🛠️ **Single & Batch Compilation**:
  - `:SourcepawnCompile` (`<leader>cc`): Asynchronously compiles active plugin and auto-routes `.smx` to `plugins/` or `compiled/` directory.
  - `:SourcepawnBuild` (`<leader>cb`): Compiles all main plugins in workspace concurrently.
- 🩺 **Doctor Health Check**: `:SourcepawnDoctor` (`<leader>spd`) inspects LSP, compiler, formatter, active main scripts, and canonical include paths.

---

## 📋 Requirements & Dependencies

- **Neovim `>= 0.11.0`**
- **[`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter)** (for SourcePawn syntax highlighting).
- **`clang-format`** (or **[`williamboman/mason.nvim`](https://github.com/williamboman/mason.nvim)** for automated installation).
- **SourceMod Compiler (`spcomp` / `spcomp64`)** (from local SourceMod installation or [SourceKnight](https://github.com/tmick0/sourceknight)).
- **`curl` & `tar` / `unzip`** (for binary auto-installation via `:SourcepawnInstall`).

### Integrations (Optional)

- **[`stevearc/conform.nvim`](https://github.com/stevearc/conform.nvim)**: For unified formatting and format-on-save workflows.
- **[`nvim-lualine/lualine.nvim`](https://github.com/nvim-lualine/lualine.nvim)**: For displaying the active main script status in your statusline.

---

## 📦 Installation & Setup

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  {
    "SparkyCloudy/sourcepawn-tools.nvim",
    ft = "sourcepawn",
    opts = {},
  },
}
```

### 📥 Post-Installation (First-Time Setup)

After installing the plugin, run **`:SourcepawnInstall`** (or `:SPInstall`) once inside Neovim to download the official `sourcepawn-studio` LSP server binary and set up the `clang-format` formatter:

```vim
:SourcepawnInstall
```

> **Tip:** You can verify your environment and toolchain health at any time by running **`:SourcepawnDoctor`** (`:SPDoctor`).

---

## ⚙️ Full Configuration Reference

All options are optional and come with sensible defaults:

```lua
require("sourcepawn-tools").setup({
  lsp = {
    enabled = true,                     -- Enable / disable sourcepawn-studio LSP
    cmd = nil,                          -- Custom LSP command line (auto-detected if nil)
    disable_telemetry = true,           -- Pass --disable-telemetry to LSP
    debounce_text_changes = 150,        -- Delay in ms before sending changes to LSP
    auto_save = true,                   -- Auto-save buffer quietly on edit to continuously trigger LSP diagnostics
    settings = {},                      -- Custom LSP settings (e.g. SourcePawnLanguageServer)
  },
  compiler = {
    path = nil,                         -- Path to spcomp / spcomp64 (auto-detected if nil)
    include_dirs = {},                  -- Custom include directories
    options = {},                       -- Extra compiler CLI flags (e.g. {"-O2", "-v2"})
    main_file = nil,                    -- Explicit main plugin entry file (e.g. "my_plugin.sp")
    default_output = "auto",            -- Output directory: "auto", "plugins", "compiled", or custom path
  },
  formatter = {
    options = {},                       -- Custom CLI flags passed to formatter
  },
  keymaps = {
    compile = "<leader>cc",             -- Compile active / main plugin
    build_all = "<leader>cb",           -- Compile all plugins in workspace
    doctor = "<leader>spd",             -- Open environment diagnostics
    format = "<leader>cf",              -- Format active buffer
  },
  hooks = {
    on_compile_success = function(file, output_smx) end,  -- Success callback
    on_compile_error = function(file, errors) end,         -- Failure callback
  },
})
```

### 📋 Configuration Options Breakdown

| Section           | Option                  | Type              | Default         | Description                                                   |
| ----------------- | ----------------------- | ----------------- | --------------- | ------------------------------------------------------------- |
| **`lsp`**         | `enabled`               | `boolean`         | `true`          | Enable or disable automatic LSP attachment.                   |
|                   | `cmd`                   | `string[] \| nil` | `nil`           | Custom command to run `sourcepawn-studio` binary.             |
|                   | `disable_telemetry`     | `boolean`         | `true`          | Pass `--disable-telemetry` flag to LSP server.                |
|                   | `debounce_text_changes` | `integer`         | `150`           | Milliseconds to debounce text sync to LSP.                    |
|                   | `auto_save`             | `boolean`         | `true`          | Auto-saves quietly on edit to continuously trigger LSP diagnostics. |
|                   | `settings`              | `table`           | `{}`            | Custom table passed to `SourcePawnLanguageServer`.            |
| **`compiler`**    | `path`                  | `string \| nil`   | `nil`           | Path to `spcomp.exe` / `spcomp64.exe` (auto-detected).        |
|                   | `include_dirs`          | `string[]`        | `{}`            | List of include directories passed with `-i`.                 |
|                   | `options`               | `string[]`        | `{}`            | Additional CLI flags passed to `spcomp` (e.g. `{"-O2"}`).     |
|                   | `main_file`             | `string \| nil`   | `nil`           | Explicit main entry file for modular projects.                |
|                   | `default_output`        | `string`          | `"auto"`        | Output folder: `"auto"`, `"plugins"`, `"compiled"`, or path.  |
| **`formatter`**   | `options`               | `string[]`        | `{}`            | Additional CLI flags passed to `clang-format`.                |
| **`keymaps`**     | `compile`               | `string \| false` | `"<leader>cc"`  | Keymap to compile current/main plugin (`false` to disable).   |
|                   | `build_all`             | `string \| false` | `"<leader>cb"`  | Keymap to batch compile all plugins (`false` to disable).     |
|                   | `doctor`                | `string \| false` | `"<leader>spd"` | Keymap to run `:SourcepawnDoctor` (`false` to disable).       |
|                   | `format`                | `string \| false` | `"<leader>cf"`  | Keymap to format buffer with `clang-format` (`false` to disable). |
| **`hooks`**       | `on_compile_success`    | `function \| nil` | `nil`           | Callback with `(file, output_smx)` on compile success.        |
|                   | `on_compile_error`      | `function \| nil` | `nil`           | Callback with `(file, errors)` on compile error.              |

---

## 📁 Project Workspace Configuration Override

You can override any configuration on a per-project basis by placing a **`.sourcepawn-tools.lua`** (or `.sourcepawn.lua` / `.spconfig.lua`) file at the root of your project:

```lua
-- File: .sourcepawn-tools.lua (in your project root)
return {
  compiler = {
    -- Explicit compiler path (Linux / Windows example, or nil for auto-detect):
    -- Linux:   path = "/path/to/sourcemod/addons/sourcemod/scripting/spcomp",
    -- Windows: path = "C:/sourcemod/addons/sourcemod/scripting/spcomp.exe",
    path = nil,

    -- Custom include directories for this project
    include_dirs = {
      "./include",
      "./custom_includes",
    },

    -- Output directory for compiled .smx files
    default_output = "./plugins",

    -- Explicit main entry point when editing submodules inside modules/
    main_file = "scripting/my_plugin.sp",

    -- Custom compiler CLI options
    options = { "-O2" },
  },
}
```

When you open any SourcePawn file in that workspace, `sourcepawn-tools.nvim` will automatically discover the configuration, deep-merge it with your global defaults, and configure both the compiler and LSP server accordingly. Check active configuration anytime with `:SourcepawnDoctor`.

---

## 💅 Code Formatting

`sourcepawn-tools.nvim` provides seamless buffer formatting via `:SourcepawnFormat` (`<leader>cf` / `<leader>spf`) or via integration with [`conform.nvim`](https://github.com/stevearc/conform.nvim).

### ⚙️ Formatter Engines:

- **`clang-format` (Current Default)**:
  `clang-format` is the active formatting engine due to its mature support for Allman braces, function-comment spacing preservation, and flexible macro attribute handling. It can be easily installed via Mason (`:MasonInstall clang-format`) or your system package manager.
- **`SPFormat` (Planned / Roadmap)**:
  Native integration with [SPFormat](https://github.com/Sarrus1/SPFormat) by Sarrus1 is currently in experimentation and will be made available as a selectable backend in future releases as upstream formatting options evolve.

### 📐 Zero-Config Built-in Style & Custom `.clang-format`

`sourcepawn-tools.nvim` comes with **built-in SourcePawn formatting rules** applied automatically out of the box (Allman braces, 4-space indentation, inline modifier keywords, and preserved function documentation spacing).

Creating a `.clang-format` file in your project root is **completely optional** and only needed if you wish to customize or override the default style:

```yaml
# .clang-format for SourcePawn
Language: Cpp
BasedOnStyle: LLVM
IndentWidth: 4
TabWidth: 4
UseTab: Never

# Allman braces (SourceMod standard)
BreakBeforeBraces: Allman

# Keep modifiers & return types on the same line (no unexpected newlines)
AlwaysBreakAfterReturnType: None
AlwaysBreakAfterDefinitionReturnType: None
BreakAfterAttributes: Never

# Register SourcePawn keywords as Attribute Macros
AttributeMacros:
  - public
  - stock
  - forward
  - native
  - normal
  - static

# Common SourcePawn return types & classes
TypenameMacros:
  - Action
  - Plugin
  - Handle
  - Cookie
  - ConVar

# Maintain single empty line between functions & doc comments
KeepEmptyLinesAtTheStartOfBlocks: false
MaxEmptyLinesToKeep: 1
ColumnLimit: 120
```

### 🔌 Integration with `conform.nvim`

```lua
local sp_formatter = require("sourcepawn-tools.formatter").conform_formatter

require("conform").setup({
  formatters = {
    sourcepawn_fmt = sp_formatter,
  },
  formatters_by_ft = {
    sourcepawn = { "sourcepawn_fmt" },
  },
})
```

---

## 🛡️ 3-Tier Toolchain & Include Resolution Hierarchy

`sourcepawn-tools.nvim` resolves compiler executables (`spcomp` / `spcomp64` / `compile`) and include directories using a strict **3-Tier Priority System**:

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. BUILD TOOLS (Highest Priority)                           │
│    • SourceKnight (.sourceknight/build/**/include/)         │
│    • Project-local build outputs (build/bin/, build/inc/)   │
│    • Project root toolchain (spcomp.exe, include/)          │
├─────────────────────────────────────────────────────────────┤
│ 2. OVERRIDE CONFIG (Workspace Local)                        │
│    • .sourcepawn-tools.lua/.sourcepawn.lua/.spconfig.lua    │
├─────────────────────────────────────────────────────────────┤
│ 3. PLUGIN CONFIG & FALLBACKS (Lowest Priority)              │
│    • Global Neovim user options passed to setup()           │
│    • System PATH & VS Code extension fallbacks              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Statusline Integration (`lualine.nvim`)

Show the active SourcePawn main entry point and submodule relationship dynamically in your statusline:

```lua
-- Example for lualine.nvim
require("lualine").setup({
  sections = {
    lualine_x = {
      {
        require("sourcepawn-tools.statusline").lualine,
        cond = function()
          return vim.bo.filetype == "sourcepawn"
        end,
      },
    },
  },
})
```

Outputs:

- Single Plugin: ` my_plugin.sp`
- Submodule file in `modules/helper.sp`: ` my_plugin.sp ↳ helper.sp`

---

## 📝 Code Generation & Documentation

- **Doc Comment Generator (`:SourcepawnDocGen` / `:SPDocGen`)**:
  Place your cursor on any function declaration and run `:SPDocGen` to generate Doxygen/SourceMod docstrings:

  ```sourcepawn
  /**
   * Command_Kick description.
   *
   * @param client       The client index.
   * @param args         Number of arguments.
   * @return             Plugin_Handled or Plugin_Continue.
   */
  public Action Command_Kick(int client, int args)
  ```

- **Plugin Scaffold (`:SourcepawnNewPlugin [name]` / `:SPNewPlugin`)**:
  Creates a new SourcePawn plugin with `#pragma newdecls required`, `#include <sourcemod>`, `Plugin myinfo`, and `OnPluginStart()`.

- **Module Scaffold (`:SourcepawnNewModule [name]` / `:SPNewModule`)**:
  Creates a new submodule script with `#if defined _module_included` guards.

---

## ⌨️ Commands & Aliases

| Command                                    | Alias          | Description                                                                         |
| ------------------------------------------ | -------------- | ----------------------------------------------------------------------------------- |
| `:SourcepawnInstall [lsp\|formatter\|all]` | `:SPInstall`   | Download LSP (`sourcepawn-studio`) and install Formatter (`clang-format` via Mason) |
| `:SourcepawnFormat`                        | `:SPFormat`    | Format active SourcePawn buffer using built-in rules or `.clang-format`             |
| `:SourcepawnCompile [file]`                | `:SPCompile`   | Asynchronously compile current/main plugin                                          |
| `:SourcepawnBuild`                         | `:SPBuild`     | Batch compile all main plugins in workspace                                         |
| `:SourcepawnDoctor`                        | `:SPDoctor`    | Environment & toolchain diagnostics health check                                    |
| `:SourcepawnSetMain [file]`                | `:SPSetMain`   | Manually set the main entry file                                                    |
| `:SourcepawnUnsetMain`                     | `:SPUnsetMain` | Reset main entry point back to auto-detect                                          |
| `:SourcepawnDocGen`                        | `:SPDocGen`    | Generate Doxygen docstring for function under cursor                                |
| `:SourcepawnNewPlugin [name]`              | `:SPNewPlugin` | Scaffold a new SourcePawn plugin `.sp`                                              |
| `:SourcepawnNewModule [name]`              | `:SPNewModule` | Scaffold a new SourcePawn submodule `.sp`                                           |

---

## 🙏 Acknowledgements & Credits

This plugin serves as a Neovim companion bridge and relies fundamentally on the incredible work of the SourcePawn & SourceMod community:

- **[Sarrus1](https://github.com/Sarrus1)**: For creating **[`sourcepawn-studio`](https://github.com/Sarrus1/sourcepawn-studio)** (the Rust-based Language Server Protocol implementation) and **[`SPFormat`](https://github.com/Sarrus1/SPFormat)** (the dedicated SourcePawn code formatter).
- **[Nils Helmig](https://github.com/nilshelmig)**: For creating and maintaining the upstream **[`tree-sitter-sourcepawn`](https://github.com/nilshelmig/tree-sitter-sourcepawn)** grammar used for syntax highlighting.
- **[AlliedModders LLC](https://alliedmods.net/)**: For the SourceMod platform, `spcomp` compiler, and the foundational SourcePawn language ecosystem.
- **[`flutter-tools.nvim`](https://github.com/akinsho/flutter-tools.nvim)**: For the architectural inspiration behind the clean and modular structure of this plugin.

---

## 📜 License

MIT
