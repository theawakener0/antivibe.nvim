local LanguageBase = require("99.language.base")

local M = LanguageBase.new({
    filetypes = { "cpp" },

    log_item = function(item_name)
        return string.format("C++: %s", item_name)
    end,

    get_prompt_template = function(operation_type)
        local templates = {
            fill_in_function = [[
Fill in the C++ function body.
- Do not change the function signature
- Follow C++ best practices and RAII principles
- Use const correctness
- Consider move semantics for large objects
- Handle exceptions appropriately
- Use smart pointers for memory management
- Follow the style of existing code
]],

            constructor = [[
Generate a C++ constructor.
- Use initialization lists
- Follow the rule of five where applicable
- Use const references for large objects
- Handle member initialization order
- Use nullptr instead of NULL
]],

            destructor = [[
Generate a C++ destructor.
- Follow RAII principles
- Release all owned resources
- Handle smart pointers appropriately
- Use noexcept where appropriate
]],

            operator_overload = [[
Implement this C++ operator overload.
- Follow the canonical forms
- Consider self-assignment
- Return appropriate reference types
- Maintain exception safety guarantees
- Follow common semantics (e.g., == should be symmetric)
]],

            implement_function = [[
Implement this C++ function based on its signature and usage context.
- Consider template parameters
- Use const and constexpr where appropriate
- Handle potential exceptions
- Follow C++ STL conventions
- Consider iterator invalidation
]],

            method_impl = [[
Implement this C++ class method.
- Respect const-correctness
- Use appropriate access specifiers
- Consider virtual and override keywords
- Follow class invariants
]],
        }

        return templates[operation_type]
    end,

    supports_lsp = function()
        return true
    end,
})

return M
