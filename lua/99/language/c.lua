local LanguageBase = require("99.language.base")

local M = LanguageBase.new({
    filetypes = { "c" },

    log_item = function(item_name)
        return string.format("C: %s", item_name)
    end,

    get_prompt_template = function(operation_type)
        local templates = {
            fill_in_function = [[
Fill in the C function body.
- Do not change the function signature
- Follow C coding conventions
- Use appropriate C standard library functions
- Handle pointers carefully
- Free allocated memory
- Return appropriate values or error codes
]],

            constructor = [[
Generate a C constructor that initializes all struct members.
- Use consistent naming convention
- Handle null pointers appropriately
- Set default values
]],

            destructor = [[
Generate a C destructor that cleans up all allocated resources.
- Free all allocated memory
- Handle nested pointers
- Set pointers to NULL after freeing
]],

            implement_function = [[
Implement this C function based on its signature and usage context.
- Consider the expected return type
- Handle edge cases and errors
- Use appropriate C idioms
]],
        }

        return templates[operation_type]
    end,

    supports_lsp = function()
        return true
    end,
})

return M
