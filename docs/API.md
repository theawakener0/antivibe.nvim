# 99 (antivibe.nvim) API Documentation

Complete API reference for the 99 AI coding agent plugin.

## Table of Contents

- [Configuration](#configuration)
- [State Management](#state-management)
- [Operations](#operations)
- [Operations](#ui-module)
- [Language Support](#language-support)
- [LSP Integration](#lsp-integration)
- [Configuration](#configuration-1)

---

## Configuration

### `setup(opts)`

Initialize the 99 plugin with custom configuration.

**Parameters:**
- `opts` (table?): Configuration options

**Options:**

#### Logger Options

```lua
{
    logger = {
        level = "DEBUG",        -- "DEBUG" | "INFO" | "WARN" | "ERROR" | "FATAL"
        path = "/tmp/debug.log",  -- string | nil (no file)
        print_on_error = true,  -- boolean
        max_requests_cached = 5,  -- number (1-20)
    }
}
```

#### Main Options

```lua
{
    model = "opencode/claude-opus-4-5",  -- string
    md_files = { "AGENT.md" },  -- string[]
    provider = custom_provider,  -- function | nil
    display_errors = false,  -- boolean
}
```

#### New Options

```lua
{
    languages = { "lua", "typescript", "c", "cpp", "go" },  -- string[]
    timeout = {
        fill_in_function = 30000,     -- number (ms)
        visual = 45000,                  -- number (ms)
        implement_fn = 30000,           -- number (ms)
        generate_tests = 60000,         -- number (ms)
        explain_code = 30000,           -- number (ms)
        refactor = 45000,               -- number (ms)
        inline_doc = 30000,            -- number (ms)
    },
    virtual_text = {
        enabled = true,            -- boolean
        max_lines = 3,              -- number (0-10)
        show_ai_stdout = true,      -- boolean
    },
}
```

**Example:**

```lua
local _99 = require("99")

_99.setup({
    model = "opencode/claude-opus-4-5",
    md_files = { "AGENT.md" },
    logger = {
        level = _99.DEBUG,
        path = "/tmp/99-debug.log",
    },
    languages = { "lua", "typescript", "cpp", "go" },
    timeout = {
        fill_in_function = 30000,
        visual = 45000,
    },
    virtual_text = {
        enabled = true,
        max_lines = 3,
    },
    display_errors = true,
})
```

**Returns:** nil

---

## State Management

### `get_config()`

Get the current plugin configuration.

**Returns:** Table with current configuration settings.

**Example:**

```lua
local config = _99.get_config()
print(config.model)
```

### `reset_config()`

Reset all configuration to defaults.

**Returns:** Table with default configuration.

**Example:**

```lua
local defaults = _99.reset_config()
```

---

## Operations

### Core Operations

#### `fill_in_function()`

Fill in the function body at the current cursor position.

**Usage:**

```lua
_99.fill_in_function()
```

**Behavior:**
- Detects containing function using treesitter
- Sends function signature and context to AI
- Replaces function body with AI-generated implementation
- Shows loading spinner during request

#### `fill_in_function_prompt()`

Fill in function with additional user prompt.

**Usage:**

```lua
_99.fill_in_function_prompt()
-- User is prompted for additional context
```

#### `visual()`

Replace visual selection with AI-generated code.

**Usage:**

```lua
_99.visual()
```

**Parameters:**
- `prompt` (string?): Additional prompt context

**Example:**

```lua
_99.visual("Make this more efficient")
```

#### `visual_prompt()`

Replace visual selection with additional user prompt.

**Usage:**

```lua
_99.visual_prompt()
```

#### `implement_fn()`

Implement a function call at the current cursor position.

**Usage:**

```lua
_99.implement_fn()
```

**Behavior:**
- Detects function call using treesitter
- Generates implementation based on type information
- Places implementation at appropriate location

### New Operations

#### `generate_tests()`

Generate unit tests for the function at cursor or selected code.

**Features:**
- Auto-detects test framework (busted, jest, pytest, go test, cargo test, etc.)
- Generates comprehensive tests (normal, edge, error cases)
- Creates test file in appropriate location

**Usage:**

```lua
_99.generate_tests()
```

#### `generate_tests_prompt()`

Generate tests with additional user prompt.

**Usage:**

```lua
_99.generate_tests_prompt()
```

#### `explain_code(prompt?)`

Explain selected code with detailed analysis.

**Features:**
- Extracts type information via LSP
- Analyzes code structure and relationships
- Shows diagnostics and warnings
- Provides surrounding context
- Markdown-formatted explanations

**Levels:**
- Simple: High-level overview
- Detailed: Technical details with implementation notes

**Usage:**

```lua
-- Basic explanation
_99.explain_code()

-- With custom prompt
_99.explain_code("Explain this in more detail")
```

#### `refactor(prompt?)`

Refactor selected code with safety measures.

**Refactor Types:**
1. Extract function - Extract selection into new named function
2. Inline variable - Replace with its value
3. Rename symbol - Rename to more descriptive name
4. Simplify condition - Simplify complex conditional

**Safety Features:**
- Preview mode before applying changes
- Confirmation for destructive operations
- LSP-based references detection
- Undo support

**Usage:**

```lua
_99.refactor()

-- With custom prompt
_99.refactor("Extract this into a reusable function")
```

#### `inline_doc()`

Generate or update inline documentation for function at cursor.

**Supported Formats:**
- Lua: LuaDoc (`@param`, `@return`, `@see`)
- TypeScript/JavaScript: JSDoc (`/** */`)
- Go: Go Doc (`//`)
- Rust: Rustdoc (`///`)
- C/C++: Doxygen (`///`)
- Python: Docstring (Google/NumPy style)

**Features:**
- Detects existing documentation
- Generates based on LSP signature
- Improved version generation
- Language-specific formatting

**Usage:**

```lua
_99.inline_doc()
```

### Log Management

#### `view_logs()`

View the most recent cached request logs.

**Usage:**

```lua
_99.view_logs()
```

#### `prev_request_logs()`

Navigate to previous request logs.

**Usage:**

```lua
_99.prev_request_logs()
```

#### `next_request_logs()`

Navigate to next request logs.

**Usage:**

```lua
_99.next_request_logs()
```

### Request Management

#### `stop_all_requests()`

Cancel all active and queued requests.

**Usage:**

```lua
_99.stop_all_requests()
```

#### `info()`

Display plugin information and status.

**Shows:**
- Active requests count
- Queued requests count
- Model being used
- Configuration options
- Timeout settings
- Virtual text settings

**Usage:**

```lua
_99.info()
```

---

## UI Module

### Notification Functions

#### `notify(message, type?)`

Display a notification to the user.

**Parameters:**
- `message` (string): Notification message
- `type` (string?): "info" | "warn" | "error"

**Usage:**

```lua
local UI = require("99.ui")

UI.notify("Operation completed")
UI.warn("Configuration invalid")
UI.error("Request failed")
```

#### `success(message)`

Display a success notification.

**Parameters:**
- `message` (string): Success message

**Usage:**

```lua
UI.success("Tests generated successfully")
```

#### `warn(message)`

Display a warning notification.

**Parameters:**
- `message` (string): Warning message

**Usage:**

```lua
UI.warn("Timeout reached")
```

#### `error(message)`

Display an error notification.

**Parameters:**
- `message` (string): Error message

**Usage:**

```lua
UI.error("Failed to connect to LSP")
```

#### `show_operation_progress(operation, details?)`

Show operation progress notification.

**Parameters:**
- `operation` (string): Operation name
- `details` (string?): Additional details

**Usage:**

```lua
UI.show_operation_progress("Generating tests", "Processing file...")
```

### Status Line

#### `update_statusline()`

Manually trigger status line update.

**Usage:**

```lua
UI.update_statusline()
```

### Quick Pick Menu

#### `show_operation_menu()`

Display operation selection menu.

**Available Options:**
- Fill in Function (`<leader>9f`)
- Generate Tests (`<leader>9g`)
- Explain Code (`<leader>9e`)
- Refactor Selection (`<leader>9r`)
- Generate Documentation (`<leader>9d`)
- View Info (`<leader>9i`)
- Cancel All Requests (`<leader>9c`)

**Usage:**

```lua
local UI = require("99.ui")

UI.show_operation_menu()
```

---

## Language Support

### Supported Languages

| Language | File Types | LSP | Treesitter | Documentation |
|---------|------------|-----|-----------|-------------|
| Lua | `lua`, `luau` | ✓ | ✓ | LuaDoc |
| TypeScript | `ts`, `tsx` | ✓ | ✓ | JSDoc |
| JavaScript | `js`, `jsx` | ✓ | ✓ | JSDoc |
| C | `c`, `h` | ✓ | ✓ | Doxygen |
| C++ | `cpp`, `hpp`, `cc`, `cxx` | ✓ | ✓ | Doxygen |
| Go | `go` | ✓ | ✓ | Go Doc |

### Language Modules

#### Lua

```lua
local lua_module = require("99.language.lua")

lua_module.log_item("function_name")
```

#### TypeScript

```lua
local ts_module = require("99.language.typescript")

ts_module.log_item("function_name")
```

#### C

```lua
local c_module = require("99.language.c")

c_module.log_item("function_name")
```

#### C++

```lua
local cpp_module = require("99.language.cpp")

cpp_module.log_item("function_name")
```

#### Go

```lua
local go_module = require("99.language.go")

go_module.log_item("function_name")
```

### Language Configuration

#### `get_language_config(config, language)`

Get language-specific configuration.

**Parameters:**
- `config` (table): Plugin configuration
- `language` (string): Language name

**Returns:** Language-specific config or nil

**Example:**

```lua
local config = _99.get_config()
local go_config = _99.get_language_config(config, "go")
```

#### `set_language_config(config, language, lang_config)`

Set language-specific configuration.

**Parameters:**
- `config` (table): Plugin configuration
- `language` (string): Language name
- `lang_config` (table): Language-specific settings

**Example:**

```lua
_99.setup()
local config = _99.get_config()
config = _99.set_language_config(config, "go", {
    custom_setting = "value",
})
```

---

## LSP Integration

### Utilities

#### `lsp.get_type_at_cursor(buf, row, col, timeout_ms)`

Get type information at cursor position.

**Parameters:**
- `buf` (number?): Buffer number (default: current buffer)
- `row` (number?): Row number (0-based)
- `col` (number?): Column number (0-based)
- `timeout_ms` (number?): Timeout in ms (default: 5000)

**Returns:** (success, type_info, error_msg)

**Example:**

```lua
local lsp = require("99.lsp")

local ok, type_info, err = lsp.get_type_at_cursor()
if ok then
    print("Type:", type_info)
end
```

#### `lsp.get_references(buf, row, col, timeout_ms)`

Find all references to symbol at cursor.

**Parameters:**
- `buf` (number?): Buffer number (default: current buffer)
- `row` (number?): Row number (0-based)
- `col` (number?): Column number (0-based)
- `timeout_ms` (number?): Timeout in ms (default: 5000)

**Returns:** (success, references, error_msg)

**Example:**

```lua
local ok, refs, err = lsp.get_references()
if ok then
    for _, ref in ipairs(refs) do
        print(ref.uri)
    end
end
```

#### `lsp.get_definition(buf, row, col, timeout_ms)`

Jump to definition of symbol at cursor.

**Parameters:**
- `buf` (number?): Buffer number (default: current buffer)
- `row` (number?): Row number (0-based)
- `col` (number?): Column number (0-based)
- `timeout_ms` (number?): Timeout in ms (default: 5000)

**Returns:** (success, definitions, error_msg)

**Example:**

```lua
local ok, defs, err = lsp.get_definition()
```

#### `lsp.get_document_symbols(buf, timeout_ms)`

Get all symbols in current buffer.

**Parameters:**
- `buf` (number?): Buffer number (default: current buffer)
- `timeout_ms` (number?): Timeout in ms (default: 5000)

**Returns:** (success, symbols, error_msg)

**Example:**

```lua
local ok, symbols, err = lsp.get_document_symbols()
if ok then
    for _, sym in ipairs(symbols) do
        print(sym.name, sym.kind)
    end
end
```

#### `lsp.get_diagnostics(buf)`

Get diagnostics for buffer.

**Parameters:**
- `buf` (number?): Buffer number (default: current buffer)

**Returns:** Array of diagnostic objects

**Example:**

```lua
local diags = lsp.get_diagnostics()
for _, diag in ipairs(diags) do
    print(diag.message, diag.severity)
end
```

#### `lsp.get_signature_help(buf, row, col, timeout_ms)`

Get function signature at cursor.

**Parameters:**
- `buf` (number?): Buffer number (default: current buffer)
- `row` (number?): Row number (0-based)
- `col` (number?): Column number (0-based)
- `timeout_ms` (number?): Timeout in ms (default: 5000)

**Returns:** (success, signature_help, error_msg)

**Example:**

```lua
local ok, sig = lsp.get_signature_help()
if ok and #sig > 0 then
    print(sig[1].label)
end
```

#### `lsp.is_lsp_available(buf?)`

Check if LSP is available for buffer.

**Parameters:**
- `buf` (number?): Buffer number (default: current buffer)

**Returns:** boolean

**Example:**

```lua
local available = lsp.is_lsp_available()
print("LSP available:", available)
```

#### `lsp.get_lsp_clients(buf?)`

Get all LSP clients for buffer.

**Parameters:**
- `buf` (number?): Buffer number (default: current buffer)

**Returns:** Array of LSP client objects

**Example:**

```lua
local clients = lsp.get_lsp_clients()
for _, client in ipairs(clients) do
    print(client.name)
end
```

### Context Builder

#### `lsp_context.get_function_signature(context, range)`

Extract function signature with parameter types.

**Parameters:**
- `context` (_99.RequestContext): Request context
- `range` (_99.Range): Function range

**Returns:** Signature object or nil

**Example:**

```lua
local lsp_context = require("99.lsp.context")

local sig = lsp_context.get_function_signature(context, range)
if sig then
    print(sig.name)
    for _, param in ipairs(sig.parameters) do
        print("-", param.label)
    end
end
```

#### `lsp_context.get_type_at_position(context, point)`

Get type information at specific position.

**Parameters:**
- `context` (_99.RequestContext): Request context
- `point` (_99.Point): Point position

**Returns:** Type information or nil

**Example:**

```lua
local type_info = lsp_context.get_type_at_position(context, point)
print(type_info)
```

#### `lsp_context.get_symbol_info(context, point)`

Get symbol information (name, kind, detail).

**Parameters:**
- `context` (_99.RequestContext): Request context
- `point` (_99.Point): Point position

**Returns:** Symbol info or nil

**Example:**

```lua
local sym_info = lsp_context.get_symbol_info(context, point)
print(sym_info.name, sym_info.kind)
```

#### `lsp_context.get_surrounding_context(context, range)`

Get surrounding functions, classes, and their relationships.

**Parameters:**
- `context` (_99.RequestContext): Request context
- `range` (_99.Range): Range to analyze

**Returns:** Array of surrounding symbols

**Example:**

```lua
local surrounding = lsp_context.get_surrounding_context(context, range)
for _, sym in ipairs(surrounding) do
    print(sym.name, sym.kind)
end
```

#### `lsp_context.get_variable_types_in_range(context, range)`

Extract variable types from diagnostics.

**Parameters:**
- `context` (_99.RequestContext): Request context
- `range` (_99.Range): Range to analyze

**Returns:** Table of variable -> type mappings

**Example:**

```lua
local var_types = lsp_context.get_variable_types_in_range(context, range)
for var, var_type in pairs(var_types) do
    print(var, var_type)
end
```

#### `lsp_context.build_lsp_context(context, range, include_diagnostics)`

Build comprehensive LSP context string.

**Parameters:**
- `context` (_99.RequestContext): Request context
- `range` (_99.Range): Range to analyze
- `include_diagnostics` (boolean?): Include diagnostics (default: false)

**Returns:** Array of context lines

**Example:**

```lua
local context = get_context("operation")
local range = Range.from_visual_selection()

local lines = lsp_context.build_lsp_context(context, range, true)
```

---

## Configuration (Updated)

### Configuration Schema

#### Complete Schema

```lua
{
    logger = {
        type = "table",
        required = false,
        default = { level = "INFO", path = nil, print_on_error = true, max_requests_cached = 5 },
        validate = function(val) end,
    },
    model = {
        type = "string",
        required = false,
        default = "opencode/claude-opus-4-5",
        validate = function(val) return type(val) == "string" end,
    },
    md_files = {
        type = "table",
        required = false,
        default = { "AGENT.md" },
        validate = function(val) end,
    },
    provider = {
        type = "function",
        required = false,
        default = nil,
    },
    languages = {
        type = "table",
        required = false,
        default = { "lua" },
        validate = function(val) end,
    },
    display_errors = {
        type = "boolean",
        required = false,
        default = false,
    },
    timeout = {
        type = "table",
        required = false,
        default = {
            fill_in_function = 30000,
            visual = 45000,
            implement_fn = 30000,
            generate_tests = 60000,
            explain_code = 30000,
            refactor = 45000,
            inline_doc = 30000,
        },
        validate = function(val) end,
    },
    virtual_text = {
        type = "table",
        required = false,
        default = {
            enabled = true,
            max_lines = 3,
            show_ai_stdout = true,
        },
        validate = function(val) end,
    },
}
```

### Configuration Functions

#### `get_config()`

Get current configuration with all options.

**Returns:** Table

#### `get_value(config, key, default)`

Get nested configuration value with default fallback.

**Parameters:**
- `config` (table): Configuration table
- `key` (string): Dot-separated key path
- `default` (any): Default value if key not found

**Returns:** Configuration value

**Example:**

```lua
local config = _99.get_config()
local timeout = _99.get_value(config, "timeout.fill_in_function", 30000)
```

#### `get_language_config(config, language)`

Get language-specific configuration.

**Parameters:**
- `config` (table): Configuration table
- `language` (string): Language name

**Returns:** Language config or nil

**Example:**

```lua
local config = _99.get_config()
local go_config = _99.get_language_config(config, "go")
```

#### `get_schema()`

Get configuration schema for documentation.

**Returns:** Schema table

**Example:**

```lua
local schema = _99.get_schema()
vim.print(vim.inspect(schema))
```

---

## Internal Functions

These functions are intended for internal use or debugging.

#### `__debug()`

Enable debug logging mode.

**Usage:**

```lua
_99.__debug()
```

#### `__debug_ident()`

Debug language identification.

**Usage:**

```lua
_99.__debug_ident()
```

#### `__get_state()`

Get the internal state object (advanced usage).

**Returns:** Internal state object

**Usage:**

```lua
local state = _99.__get_state()
print(state.model)
```

---

## Examples

### Basic Setup

```lua
local _99 = require("99")

_99.setup({
    model = "opencode/claude-opus-4-5",
    md_files = { "AGENT.md" },
    languages = { "lua", "typescript", "cpp", "go" },
    display_errors = true,
})

-- Keybindings
vim.keymap.set("n", "<leader>9f", _99.fill_in_function)
vim.keymap.set("v", "<leader>9v", _99.visual)
```

### Advanced Configuration

```lua
_99.setup({
    model = "opencode/claude-opus-4-5",
    md_files = { "AGENT.md", "docs/PROJECT.md" },
    languages = { "lua", "typescript", "cpp", "go" },
    timeout = {
        fill_in_function = 30000,
        visual = 45000,
        generate_tests = 60000,
    },
    virtual_text = {
        enabled = true,
        max_lines = 5,
        show_ai_stdout = false,
    },
    display_errors = true,
})

-- Per-language configuration
local config = _99.get_config()
config = _99.set_language_config(config, "go", {
    enable_special_features = true,
})
```

### Using New Operations

```lua
-- Generate tests
vim.keymap.set("n", "<leader>9t", _99.generate_tests)

-- Explain code
vim.keymap.set("v", "<leader>9e", _99.explain_code)

-- Refactor selection
vim.keymap.set("v", "<leader>9r", _99.refactor)

-- Generate documentation
vim.keymap.set("n", "<leader>9d", _99.inline_doc)

-- Show operation menu
vim.keymap.set("n", "<leader>9o", _99.show_operation_menu)

-- View info
vim.keymap.set("n", "<leader>9i", _99.info)
-- Cancel all requests
vim.keymap.set("n", "<leader>9c", _99.stop_all_requests)

-- UI notifications
local UI = require("99.ui")

UI.success("Operation completed")
UI.warn("Configuration warning")
UI.error("Request failed")
```

### LSP Integration

```lua
local lsp = require("99.lsp")
local lsp_context = require("99.lsp.context")

-- Check LSP availability
if lsp.is_lsp_available() then
    local ok, type_info = lsp.get_type_at_cursor()
    if ok then
        print("Type:", type_info)
    end
end

-- Get context
local context = get_context("operation")
local range = Range.from_visual_selection()
local lines = lsp_context.build_lsp_context(context, range, true)
```

### Error Handling

```lua
-- All errors include helpful suggestions
-- Use display_errors to show them to users

_99.setup({
    display_errors = true,
})

-- Notifications
local UI = require("99.ui")

UI.error("Failed to connect to LSP")
UI.warn("Operation timed out")
UI.success("Tests generated successfully")
```

---

## See Also

- [README.md](README.md) - Getting started guide
- [PLAN.md](PLAN.md) - Implementation roadmap
- [PHASES_1-3_SUMMARY.md](PHASES_1-3_SUMMARY.md) - Phases 1-3 details
- [PHASES_4-8_SUMMARY.md](PHASES_4-8_SUMMARY.md) - Phases 4-8 details

---

## License

This plugin follows the same license as Neovim.
