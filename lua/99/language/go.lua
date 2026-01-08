local LanguageBase = require("99.language.base")

local M = LanguageBase.new({
    filetypes = { "go" },

    log_item = function(item_name)
        return string.format("Go: %s", item_name)
    end,

    get_prompt_template = function(operation_type)
        local templates = {
            fill_in_function = [[
Fill in the Go function body.
- Do not change the function signature
- Follow Go conventions and idioms
- Use short, descriptive variable names
- Handle errors properly with explicit error returns
- Use defer for cleanup
- Avoid global variables
- Use appropriate built-in functions
- Respect interface implementations
]],

            constructor = [[
Generate a Go constructor function (NewX pattern).
- Return a pointer to the struct
- Initialize all fields
- Accept necessary parameters
- Use clear naming convention (e.g., NewMyStruct)
]],

            implement_interface = [[
Implement this Go interface method.
- Match the interface signature exactly
- Follow Go conventions
- Handle errors appropriately
- Use receiver appropriately (pointer or value)
]],

            implement_function = [[
Implement this Go function based on its signature and usage context.
- Consider concurrency implications
- Use channels or mutexes if needed
- Handle errors gracefully
- Follow Go's error handling patterns
- Use appropriate data structures
]],

            method = [[
Implement this Go struct method.
- Use appropriate receiver type (pointer vs value)
- Follow Go method naming conventions
- Handle errors properly
- Consider method mutability
]],
        }

        return templates[operation_type]
    end,

    supports_lsp = function()
        return true
    end,
})

return M
