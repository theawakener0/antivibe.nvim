(call_expression
    function: (identifier) @call_name
    arguments: (argument_list) @call_arguments
)

(call_expression
    function: (field_expression
        field: (field_identifier) @call_name
    )
    arguments: (argument_list) @call_arguments
)

(call_expression
    function: (template_function
        name: (identifier) @call_name
    )
    arguments: (argument_list) @call_arguments
)
