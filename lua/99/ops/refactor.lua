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

local M = {}

--- @class _99.RefactorType
--- @field name string
--- @field description string
--- @field prompt string

local REFACTOR_TYPES = {
    extract_function = {
        name = "extract_function",
        description = "Extract selected code into a new function",
        prompt = [[
Extract the selected code into a new, well-named function.

Requirements:
- Give the function a descriptive name that explains what it does
- Extract all necessary dependencies as parameters
- Return appropriate values
- Add a brief comment or docstring explaining the function's purpose
- Replace the selected code with a call to the new function
- Follow language best practices and conventions
]],
    },
    inline_variable = {
        name = "inline_variable",
        description = "Inline the selected variable/function call",
        prompt = [[
Inline the selected variable or function call directly into its usage.

Requirements:
- Replace all usages with the inlined value/result
- Be careful with side effects
- Maintain code clarity and readability
- Follow language best practices
]],
    },
    rename_symbol = {
        name = "rename_symbol",
        description = "Rename the selected symbol across the file",
        prompt = [[
Rename the selected symbol to a better, more descriptive name.

Requirements:
- Suggest a better name that clearly describes what the symbol does
- Update all references within this file
- Maintain the symbol's scope and visibility
- Follow language naming conventions (camelCase, snake_case, etc.)
- Keep the name concise but descriptive
]],
    },
    simplify_condition = {
        name = "simplify_condition",
        description = "Simplify the selected conditional expression",
        prompt = [[
Simplify the selected conditional expression to be more readable and maintainable.

Requirements:
- Preserve the original logic and behavior
- Use boolean algebra rules to simplify
- Extract sub-expressions if it improves clarity
- Add comments explaining complex simplifications
- Consider early returns where appropriate
]],
    },
}

--- Show refactor type selection menu
--- @param context _99.RequestContext
--- @return _99.RefactorType?
local function select_refactor_type(context)
    local types = {}
    for _, ref_type in pairs(REFACTOR_TYPES) do
        table.insert(types, ref_type)
    end

    local lines = {
        "Select refactoring type:",
    }
    for i, ref_type in ipairs(types) do
        table.insert(lines, string.format("%d. %s", i, ref_type.description))
    end
    table.insert(lines, "")
    table.insert(lines, "Enter number (1-" .. #types .. "):")

    local result = Window.capture_input_sync(lines)

    local idx = tonumber(result)
    if not idx or idx < 1 or idx > #types then
        return nil
    end

    return types[idx]
end

--- @param context _99.RequestContext
--- @param prompt string?
local function refactor(context, prompt)
    local logger = context.logger:set_area("refactor")
    local buffer = context.buffer
    local cursor = Point:from_cursor()

    local range = Range.from_visual_selection()
    local ref_type

    if not range.start or not range.end_ then
        ref_type = select_refactor_type(context)
        if not ref_type then
            logger:debug("refactor: no type selected")
            return
        end

        local ts = editor.treesitter
        local func = ts.containing_function(context, cursor)

        if not func then
            logger:fatal("refactor: cursor not on a function")
            Window.display_error("Please place cursor on or select code to refactor.")
            return
        end

        range = func.function_range
    else
        ref_type = REFACTOR_TYPES.extract_function
    end

    local request = Request.new(context)
    context.range = range

    local marks = {}
    marks.refactor_mark = Mark.mark_above_range(range)
    context.marks = marks

    local lsp_info = lsp_util.get_references(buffer, range.start.row, range.start.col)
    local symbol_info = lsp_context.get_symbol_info(context, range.start)

    local full_prompt = ref_type.prompt .. "\n\n"

    if symbol_info then
        full_prompt = full_prompt .. string.format([[
Symbol Information:
- Name: %s
- Kind: %s
]], symbol_info.name, symbol_info.kind)
    end

    if lsp_info and #lsp_info > 0 then
        full_prompt = full_prompt .. string.format([[
References Found: %d
]], #lsp_info)
    end

    full_prompt = full_prompt .. string.format([[
Language: %s

<CODE_TO_REFACTOR>
%s
</CODE_TO_REFACTOR>
]], context.file_type, range:to_text())

    if prompt then
        full_prompt = full_prompt .. "\n\nAdditional Context:\n" .. prompt
    end

    request:add_prompt_content(full_prompt)

    local status_display = RequestStatus.new(
        250,
        context._99.ai_stdout_rows,
        "Refactoring",
        marks.refactor_mark
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
                logger:debug("refactor was cancelled")
                return
            end

            if status == "failed" then
                if context._99.display_errors then
                    Window.display_error(
                        "Error during refactoring\n" ..
                        (response or "No Error text provided")
                    )
                end
                logger:error("unable to refactor")
                return
            end

            if status == "success" then
                local lines = vim.split(response, "\n")

                if ref_type.name == "extract_function" then
                    range:replace_text(lines)
                    logger:info("Function extracted successfully")
                    Window.display_cancellation_message("Function extracted successfully")
                elseif ref_type.name == "rename_symbol" then
                    local confirm = vim.fn.confirm(
                        "Apply rename? This will modify multiple locations.\n" ..
                        "1. Apply rename\n" ..
                        "2. Show preview only\n" ..
                        "3. Cancel",
                        "\n", 3
                    )

                    if confirm == 1 then
                        range:replace_text(lines)
                        logger:info("Symbol renamed successfully")
                        Window.display_cancellation_message("Symbol renamed successfully")
                    elseif confirm == 2 then
                        Window.display_full_screen_message(lines)
                    end
                else
                    local confirm = vim.fn.confirm(
                        "Apply refactoring?\n" ..
                        "1. Apply\n" ..
                        "2. Show preview only\n" ..
                        "3. Cancel",
                        "\n", 3
                    )

                    if confirm == 1 then
                        range:replace_text(lines)
                        logger:info(string.format("%s completed successfully", ref_type.name))
                        Window.display_cancellation_message("Refactoring applied successfully")
                    elseif confirm == 2 then
                        Window.display_full_screen_message(lines)
                    end
                end
            end
        end,
        on_stderr = function(line)
            logger:debug("refactor#on_stderr", "line", line)
        end,
    })
end

return refactor
