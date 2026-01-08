(
    (function_definition
        declarator: (function_declarator
            declarator: (identifier) @context.function
            parameters: (parameter_list) @context.parameters
        )
        body: (compound_statement) @context.body
    )

    (declaration
        declarator: (function_declarator
            declarator: (identifier) @context.function
            parameters: (parameter_list) @context.parameters
        )
        body: (compound_statement) @context.body
    )
)
