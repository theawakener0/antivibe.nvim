local Request = require("99.request")
local RequestStatus = require("99.ops.request_status")
local Mark = require("99.ops.marks")
local geo = require("99.geo")
local Range = geo.Range
local Point = geo.Point
local editor = require("99.editor")
local lsp_util = require("99.lsp")
local lsp_context = require("99.lsp.context")
local make_clean_up = require("99.ops.clean-up")
local Window = require("99.window")
local Logger = require("99.logger.logger")

local M = {}

--- @class _99.DocFormat
--- @field name string
--- @field pattern string
--- @field template string

local DOC_FORMATS = {
    lua = {
        name = "LuaDoc",
        pattern = "^%s*%-%-%-",
        template = [[
Generate LuaDoc documentation for this function.

Requirements:
- Use LuaDoc format (http://lua-users.org/wiki/LuaDoc)
- Document all parameters with @param
- Document return type with @return
- Add @usage example if helpful
- Add @see for related functions
- Keep descriptions concise but clear

Format:
--- Brief description
-- @param param1 type Description of param1
-- @param param2 type Description of param2
-- @return type Description of return value
-- @see related_function
]],
    },
    typescript = {
        name = "JSDoc",
        pattern = "^%s*%/%*%*",
        template = [[
Generate JSDoc documentation for this function.

Requirements:
- Use JSDoc format (https://jsdoc.app/)
- Document all parameters with @param
- Document return type with @returns or @type
- Add @example for usage examples
- Add @throws for exceptions
- Add @see for related items

Format:
/**
 * Brief description
 * @param param1 Description of param1
 * @param param2 Description of param2
 * @returns Description of return value
 * @throws Description of possible exceptions
 * @example
 * // Example code
 * @see RelatedItem
 */
]],
    },
    javascript = {
        name = "JSDoc",
        pattern = "^%s*%/%*%*",
        template = [[
Generate JSDoc documentation for this function.

Requirements:
- Use JSDoc format (https://jsdoc.app/)
- Document all parameters with @param
- Document return type with @returns
- Add @example for usage
- Add @throws for exceptions
- Add @see for related items

Format:
/**
 * Brief description
 * @param param1 Description of param1
 * @param param2 Description of param2
 * @returns Description of return value
 * @throws Description of possible exceptions
 * @example
 * // Example code
 * @see RelatedItem
 */
]],
    },
    go = {
        name = "Go Doc",
        pattern = "^%s*%/%/",
        template = [[
Generate Go documentation for this function.

Requirements:
- Use Go documentation comments
- Document all parameters
- Document return values
- Add examples for complex functions
- Keep descriptions clear and concise

Format:
// Brief description.
// Longer description if needed.
// Parameters:
//   - param1: Description
//   - param2: Description
// Returns:
//   Description of return value
// Example:
//   // Example code
]],
    },
    rust = {
        name = "Rustdoc",
        pattern = "^%s*%/%/%/",
        template = [[
Generate Rustdoc documentation for this function.

Requirements:
- Use Rustdoc format (https://doc.rust-lang.org/rustdoc/)
- Document all parameters
- Document return type with # Returns
- Add # Examples with code blocks
- Add # Panics for unsafe code
- Add # Safety notes for unsafe functions

Format:
/// Brief description.
///
/// Longer description if needed.
///
/// # Arguments
///
/// * `param1` - Description
/// * `param2` - Description
///
/// # Returns
///
/// Description of return value
///
/// # Example
///
/// ```
/// let result = function_name(arg1, arg2);
/// ```
]],
    },
    python = {
        name = "Docstring",
        pattern = '^(["\']){3}',
        template = [[
Generate Python docstring for this function.

Requirements:
- Use Google Style or NumPy Style docstrings
- Document all parameters with Args:
- Document return value with Returns:
- Add Raises: for exceptions
- Add Examples: for usage
- Keep descriptions concise and clear

Format:
"""Brief description.

Longer description if needed.

Args:
    param1 (type): Description of param1
    param2 (type): Description of param2

Returns:
    Description of return value

Raises:
    ExceptionType: When it occurs

Examples:
    >>> result = function_name(arg1, arg2)
    >>> print(result)
    expected_output
"""
]],
    },
    cpp = {
        name = "Doxygen",
        pattern = "^%s*%/%/%/",
        template = [[
Generate Doxygen documentation for this C++ function.

Requirements:
- Use Doxygen format
- Document all parameters with @param
- Document return type with @return
- Add @brief for short description
- Add @details for longer description
- Add @sa for related functions
- Add @note for important notes

Format:
/// @brief Brief description
/// @details Longer description
/// @param param1 Description of param1
/// @param param2 Description of param2
/// @return Description of return value
/// @note Important note
/// @sa related_function
]],
    },
    c = {
        name = "Doxygen",
        pattern = "^%s*%/%/%/",
        template = [[
Generate Doxygen documentation for this C function.

Requirements:
- Use Doxygen format
- Document all parameters with @param
- Document return type with @return
- Add @brief for short description
- Add @pre for preconditions
- Add @post for postconditions

Format:
/// @brief Brief description
/// @param param1 Description of param1
/// @param param2 Description of param2
/// @return Description of return value
/// @pre Preconditions
/// @post Postconditions
]],
    },
}

--- Get doc format for filetype
--- @param file_type string
--- @return _99.DocFormat?
local function get_doc_format(file_type)
    return DOC_FORMATS[file_type]
end

--- Check if code has existing documentation
--- @param range _99.Range
--- @return boolean has_doc
--- @return string? doc_pattern
local function has_existing_doc(range)
    local first_line = range.start:get_text_line(range.buffer)
    local format = get_doc_format(range.buffer)

    if not format then
        return false, nil
    end

    local has_match = first_line:match(format.pattern)
    return has_match ~= nil, format.pattern
end

--- @param context _99.RequestContext
--- @param prompt string?
local function inline_doc(context, prompt)
    local logger = context.logger:set_area("inline_doc")
    local buffer = context.buffer
    local cursor = Point:from_cursor()

    local ts = editor.treesitter
    local func = ts.containing_function(context, cursor)

    if not func then
        logger:fatal("inline_doc: cursor not on a function")
        Window.display_error("Please place cursor on a function to generate documentation.")
        return
    end

    local request = Request.new(context)
    context.range = func.function_range

    local marks = {}
    marks.function_location = Mark.mark_above_func(buffer, func)
    context.marks = marks

    local lsp_sig = lsp_context.get_function_signature(context, func.function_range)

    local format = get_doc_format(context.file_type)
    if not format then
        logger:warn("inline_doc: unsupported file type")
        Window.display_error(string.format(
            "Documentation generation not supported for file type: %s",
            context.file_type
        ))
        return
    end

    local has_doc, doc_pattern = has_existing_doc(func.function_range)

    local full_prompt = format.template .. "\n\n"

    if lsp_sig then
        full_prompt = full_prompt .. string.format([[
Function Signature:
- Name: %s
- Parameters:
]], lsp_sig.name)
        for _, param in ipairs(lsp_sig.parameters) do
            full_prompt = full_prompt .. string.format("  - %s\n", param.label)
        end
    end

    full_prompt = full_prompt .. string.format([[
Language: %s
%s

<FUNCTION_CODE>
%s
</FUNCTION_CODE>
]], context.file_type, has_doc and "Existing documentation detected. Generate improved version." or "Generate new documentation.",
        func.function_range:to_text())

    if prompt then
        full_prompt = full_prompt .. "\n\nAdditional Context:\n" .. prompt
    end

    request:add_prompt_content(full_prompt)

    local status_display = RequestStatus.new(
        250,
        context._99.ai_stdout_rows,
        "Generating Documentation",
        marks.function_location
    )
    status_display:start()

    local clean_up = make_clean_up(context, function()
        context:clear_marks()
        request:cancel()
        status_display:stop()
    end)

    request:start({
        on_stdout = function(line)
            status_display:push(line)
        end,
        on_complete = function(status, response)
            vim.schedule(clean_up)

            if status == "cancelled" then
                logger:debug("inline_doc was cancelled")
                return
            end

            if status == "failed" then
                if context._99.display_errors then
                    Window.display_error(
                        "Error generating documentation\n" ..
                        (response or "No Error text provided")
                    )
                end
                logger:error("unable to generate documentation")
                return
            end

            if status == "success" then
                local lines = vim.split(response, "\n")

                if has_doc and doc_pattern then
                    local first_line = func.function_range.start:get_text_line(buffer)
                    if first_line:match(doc_pattern) then
                        local func_start = func.function_range.start
                        local r, c = func_start:to_vim()
                        vim.api.nvim_buf_set_lines(buffer, r, r + 1, false, { lines[1] })
                        if #lines > 1 then
                            local rest = vim.list_slice(lines, 2)
                            local insert_r, insert_c = func_start:add(Point:new(0, 0)):to_vim()
                            vim.api.nvim_buf_set_lines(buffer, insert_r, insert_r, false, rest)
                        end
                    else
                        func.function_range:replace_text(lines)
                    end
                else
                    func.function_range:replace_text(lines)
                end

                logger:info("Documentation generated successfully")
                Window.display_cancellation_message("Documentation generated successfully")
            end
        end,
        on_stderr = function(line)
            logger:debug("inline_doc#on_stderr", "line", line)
        end,
    })
end

return inline_doc
