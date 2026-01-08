(
    (function_definition
        declarator: (function_declarator
            declarator: (identifier) @context.function
            parameters: (parameter_list) @context.parameters
        )
        body: (compound_statement) @context.body
    )

    (function_definition
        declarator: (function_declarator
            declarator: (field_identifier) @context.function
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

    (constructor_definition
        name: (identifier) @context.function
        body: (compound_statement) @context.body
    )

    (destructor_definition
        name: (destructor_name) @context.function
        body: (compound_statement) @context.body
    )
)
