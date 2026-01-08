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

    -- Keymaps: Fill in function
    vim.keymap.set("n", "<leader>9f", antivibe.fill_in_function, { desc = "AI: Fill in function" })
    vim.keymap.set("n", "<leader>9F", antivibe.fill_in_function_prompt, { desc = "AI: Fill in function (with prompt)" })

    -- Keymaps: Visual selection
    vim.keymap.set("v", "<leader>9v", antivibe.visual, { desc = "AI: Visual selection" })
    vim.keymap.set("v", "<leader>9V", antivibe.visual_prompt, { desc = "AI: Visual selection (with prompt)" })

    -- Keymaps: Generate tests
    vim.keymap.set("n", "<leader>9t", antivibe.generate_tests, { desc = "AI: Generate tests" })
    vim.keymap.set("n", "<leader>9T", antivibe.generate_tests_prompt, { desc = "AI: Generate tests (with prompt)" })

    -- Keymaps: Explain code
    vim.keymap.set("n", "<leader>9e", antivibe.explain_code, { desc = "AI: Explain code" })
    vim.keymap.set("n", "<leader>9E", antivibe.explain_code_prompt, { desc = "AI: Explain code (with prompt)" })

    -- Keymaps: Refactor
    vim.keymap.set("n", "<leader>9r", antivibe.refactor, { desc = "AI: Refactor" })
    vim.keymap.set("n", "<leader>9R", antivibe.refactor_prompt, { desc = "AI: Refactor (with prompt)" })

    -- Keymaps: Documentation
    vim.keymap.set("n", "<leader>9d", antivibe.inline_doc, { desc = "AI: Inline documentation" })

    -- Keymaps: Menu and utilities
    vim.keymap.set("n", "<leader>9m", antivibe.show_operation_menu, { desc = "AI: Show operation menu" })
    vim.keymap.set("n", "<leader>9i", antivibe.info, { desc = "AI: Show info" })
    vim.keymap.set("n", "<leader>9s", antivibe.stop_all_requests, { desc = "AI: Stop all requests" })

    -- Keymaps: Log viewing
    vim.keymap.set("n", "<leader>9l", antivibe.view_logs, { desc = "AI: View logs" })
    vim.keymap.set("n", "<leader>9[", antivibe.prev_request_logs, { desc = "AI: Previous request logs" })
    vim.keymap.set("n", "<leader>9]", antivibe.next_request_logs, { desc = "AI: Next request logs" })
  end,
}
```

## Features

- **Fill in function** (`<leader>9f` / `<leader>9F`): Automatically complete function bodies
- **Visual selection** (`<leader>9v` / `<leader>9V`): Refactor and improve selected code
- **Generate tests** (`<leader>9t` / `<leader>9T`): Create unit tests for your code
- **Explain code** (`<leader>9e` / `<leader>9E`): Get detailed explanations of code blocks
- **Refactor** (`<leader>9r` / `<leader>9R`): Intelligent code refactoring
- **Inline documentation** (`<leader>9d`): Generate inline documentation
- **Operation menu** (`<leader>9m`): Quick pick menu for all operations
- **Info** (`<leader>9i`): Show current configuration and status
- **Stop requests** (`<leader>9s`): Cancel all active AI requests
- **View logs** (`<leader>9l` / `<leader>9[` / `<leader>9]`): View and navigate request logs
- **Multi-language support**: Lua, TypeScript, JavaScript, C, C++, Go, Rust, Python

## Keymaps Reference

| Keymap | Mode | Description |
|--------|------|-------------|
| `<leader>9f` | n | Fill in function |
| `<leader>9F` | n | Fill in function (with prompt) |
| `<leader>9v` | v | Visual selection |
| `<leader>9V` | v | Visual selection (with prompt) |
| `<leader>9t` | n | Generate tests |
| `<leader>9T` | n | Generate tests (with prompt) |
| `<leader>9e` | n | Explain code |
| `<leader>9E` | n | Explain code (with prompt) |
| `<leader>9r` | n | Refactor |
| `<leader>9R` | n | Refactor (with prompt) |
| `<leader>9d` | n | Inline documentation |
| `<leader>9m` | n | Show operation menu |
| `<leader>9i` | n | Show info |
| `<leader>9s` | n | Stop all requests |
| `<leader>9l` | n | View logs |
| `<leader>9[` | n | Previous request logs |
| `<leader>9]` | n | Next request logs |

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
