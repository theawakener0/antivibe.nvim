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

--- @class _99.ExplainLevel
--- @field name string
--- @field description string

local EXPLAIN_LEVELS = {
    simple = {
        name = "simple",
        description = "Provide a high-level overview without technical details",
    },
    detailed = {
        name = "detailed",
        description = "Provide thorough explanation with technical details and implementation notes",
    },
}

--- @param context _99.RequestContext
--- @param range _99.Range
--- @param level _99.ExplainLevel
--- @return string[] explanation_lines
local function build_explain_prompt(context, range, level)
    local lines = {}

    table.insert(lines, string.format([[
Explain the following %s code selection in detail.

Language: %s
Explanation Level: %s
%s

]], context.file_type, context.file_type, level.name,
    level.description))

    local lsp_info = lsp_context.get_symbol_info(context, range.start)
    if lsp_info then
        table.insert(lines, "Symbol Information:")
        table.insert(lines, string.format("  Name: %s", lsp_info.name))
        table.insert(lines, string.format("  Kind: %s", lsp_info.kind))
        if lsp_info.detail then
            table.insert(lines, string.format("  Detail: %s", lsp_info.detail))
        end
        table.insert(lines, "")
    end

    local types = lsp_context.get_variable_types_in_range(context, range)
    if next(types) then
        table.insert(lines, "Type Information:")
        for var, var_type in pairs(types) do
            table.insert(lines, string.format("  %s: %s", var, var_type))
        end
        table.insert(lines, "")
    end

    local diagnostics = lsp_util.get_diagnostics(context.buffer)
    local relevant_diags = {}
    for _, diag in ipairs(diagnostics) do
        if diag.range then
            local start = range.start:to_lsp()
            local end_pos = range.end_:to_lsp()

            local within_range = diag.range.start.line >= start.line and
                diag.range["end"].line <= end_pos.line

            if within_range then
                table.insert(relevant_diags, diag)
            end
        end
    end

    if #relevant_diags > 0 then
        table.insert(lines, "Diagnostics (Potential Issues):")
        for _, diag in ipairs(relevant_diags) do
            table.insert(lines, string.format(
                "  - %s: %s",
                diag.severity or "warning",
                diag.message
            ))
        end
        table.insert(lines, "")
    end

    local surrounding = lsp_context.get_surrounding_context(context, range)
    if #surrounding > 0 then
        table.insert(lines, "Surrounding Context:")
        for i, symbol in ipairs(surrounding) do
            if i <= 5 then
                table.insert(lines, string.format("  - %s (%s)", symbol.name, symbol.kind))
            end
        end
        if #surrounding > 5 then
            table.insert(lines, string.format("  ... and %d more", #surrounding - 5))
        end
        table.insert(lines, "")
    end

    table.insert(lines, "Code to Explain:")
    table.insert(lines, "<CODE>")
    table.insert(lines, range:to_text())
    table.insert(lines, "</CODE>")
    table.insert(lines, "")

    table.insert(lines, [[
Provide a comprehensive explanation that includes:
1. What the code does (high-level purpose)
2. How it works (step-by-step explanation)
3. Key concepts or patterns used
4. Why it was written this way (rationale)
5. Potential issues or edge cases
6. Suggestions for improvement (if any)

Format your response in Markdown with:
- Clear section headers
- Code examples where helpful
- Bullet points for lists
- Code blocks for code snippets
]])

    return lines
end

--- @param context _99.RequestContext
--- @param prompt string?
local function explain_code(context, prompt)
    local logger = context.logger:set_area("explain_code")
    local buffer = context.buffer
    local cursor = Point:from_cursor()

    local range = Range.from_visual_selection()

    if not range.start or not range.end_ then
        logger:fatal("explain_code: no visual selection")
        Window.display_error("Please select code to explain in visual mode first.")
        return
    end

    local request = Request.new(context)
    context.range = range

    local marks = {}
    marks.explanation_mark = Mark.mark_above_range(range)
    context.marks = marks

    local level = EXPLAIN_LEVELS.simple

    local full_prompt_lines = build_explain_prompt(context, range, level)
    local full_prompt = table.concat(full_prompt_lines, "\n")

    if prompt then
        full_prompt = full_prompt .. "\n\nAdditional Context:\n" .. prompt
    end

    request:add_prompt_content(full_prompt)

    local status_display = RequestStatus.new(
        250,
        context._99.ai_stdout_rows,
        "Analyzing Code",
        marks.explanation_mark
    )
    status_display:start()

    local clean_up = make_clean_up(context, function()
        context:clear_marks()
        request:cancel()
        status_display:stop()
    end, "explain_code")

    request:start({
        on_stdout = function(line)
            status_display:push(line)
        end,
        on_complete = function(status, response)
            vim.schedule(clean_up)

            if status == "cancelled" then
                logger:debug("explain_code was cancelled")
                return
            end

            if status == "failed" then
                if context._99.display_errors then
                    Window.display_error(
                        "Error analyzing code\n" ..
                        (response or "No Error text provided")
                    )
                end
                logger:error("unable to explain code")
                return
            end

            if status == "success" then
                logger:info("Code explanation generated")

                Window.display_full_screen_message(vim.split(response, "\n"))
            end
        end,
        on_stderr = function(line)
            logger:debug("explain_code#on_stderr", "line", line)
        end,
    })
end

return explain_code
