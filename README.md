# antivibe.nvim

> A fork of [ThePrimeagen/99](https://github.com/ThePrimeagen/99) — The AI agent that Neovim deserves

This is a modern Neovim fork of the original 99 plugin, bringing you an optimized AI workflow for developers who don't have "skill issues." It streamlines AI requests to restricted areas of your code, making pair programming more focused and productive.

For general requests, please use [opencode](https://opencode.ai). For focused, context-aware code assistance, use antivibe.nvim.

## Installation

### Lazy.nvim

```lua
{
  "theawakener0/antivibe.nvim",
  config = function()
    local antivibe = require("99")

    -- Optional: Configure logging for debugging
    local cwd = vim.uv.cwd()
    local basename = vim.fs.basename(cwd)

    antivibe.setup({
      -- Logging configuration
      logger = {
        level = "DEBUG",  -- or "INFO", "WARN", "ERROR", "FATAL"
        path = "/tmp/" .. basename .. ".99.debug",
        print_on_error = true,
        max_requests_cached = 5,
      },

      -- Model to use
      model = "opencode/claude-opus-4-5",

      -- Files to automatically include in context
      md_files = {
        "AGENT.md",
      },

      -- Supported languages
      languages = {
        "lua",
        "typescript",
        "javascript",
        "c",
        "cpp",
        "go",
        "rust",
        "python",
      },

      -- Virtual text options
      virtual_text = {
        enabled = true,
        max_lines = 3,
        show_ai_stdout = true,
      },

      -- AI stdout preview rows
      ai_stdout_rows = 3,

      -- Timeout settings (in milliseconds)
      timeout = {
        fill_in_function = 30000,
        visual = 45000,
        implement_fn = 30000,
        generate_tests = 60000,
        explain_code = 30000,
        refactor = 45000,
        inline_doc = 30000,
      },
    })

    -- Keymaps
    vim.keymap.set("n", "<leader>9f", function()
      antivibe.fill_in_function()
    end, { desc = "AI: Fill in function" })

    vim.keymap.set("v", "<leader>9v", function()
      antivibe.visual()
    end, { desc = "AI: Visual selection" })

    vim.keymap.set("v", "<leader>9s", function()
      antivibe.stop_all_requests()
    end, { desc = "AI: Stop all requests" })
  end,
}
```

## Features

- **Fill in function**: Automatically complete function bodies
- **Visual selection**: Refactor and improve selected code
- **Generate tests**: Create unit tests for your code
- **Explain code**: Get detailed explanations of code blocks
- **Refactor**: Intelligent code refactoring
- **Inline documentation**: Generate inline documentation
- **Multi-language support**: Lua, TypeScript, JavaScript, C, C++, Go, Rust, Python

## API

See the full API documentation at [lua/99/init.lua](./lua/99/init.lua)

## Requirements

- [opencode](https://opencode.ai) CLI installed and configured
- Neovim 0.9+
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

## Status

This project is under active development. While based on the original 99 plugin, this fork includes improvements and optimizations for a better developer experience.

### Known Issues

- Long function definitions may display virtual text one line below "function"
- Lua and JSDoc replacements may duplicate comment definitions
- Visual selection currently sends the entire file
- Context gathering could be improved with better tree-sitter and LSP integration

## Credits

Original work by [ThePrimeagen](https://github.com/ThePrimeagen/99)

## License

Same as the original [ThePrimeagen/99](https://github.com/ThePrimeagen/99)
