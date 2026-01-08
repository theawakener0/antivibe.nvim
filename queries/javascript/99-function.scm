; JavaScript uses the same grammar as TypeScript for functions
(function_declaration) @context.function
(arrow_function) @context.function
(method_definition) @context.function
(function_expression) @context.function

(function_declaration
  body: (statement_block) @context.body)

(arrow_function
  body: (statement_block) @context.body)

(method_definition
  body: (statement_block) @context.body)

(function_expression
  body: (statement_block) @context.body)
