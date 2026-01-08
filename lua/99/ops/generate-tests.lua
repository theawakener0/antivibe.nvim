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

--- @class _99.TestFramework
--- @field name string
--- @field file_pattern string
--- @field template string

--- Detect test framework from project
--- @param context _99.RequestContext
--- @return _99.TestFramework?
local function detect_test_framework(context)
    local buffer = context.buffer
    local ft = context.file_type

    local patterns = {
        lua = {
            { name = "busted", pattern = ".*_spec%.lua$", template = "busted" },
            { name = "plenary", pattern = ".*_spec%.lua$", template = "plenary" },
        },
        typescript = {
            { name = "jest", pattern = ".*%.test%.ts$", template = "jest" },
            { name = "vitest", pattern = ".*%.test%.ts$", template = "vitest" },
        },
        javascript = {
            { name = "jest", pattern = ".*%.test%.js$", template = "jest" },
            { name = "mocha", pattern = ".*%.test%.js$", template = "mocha" },
        },
        go = {
            { name = "go test", pattern = ".*_test%.go$", template = "gotest" },
        },
        rust = {
            { name = "cargo test", pattern = ".*_test%.rs$", template = "cargo" },
        },
        python = {
            { name = "pytest", pattern = "test_.*%.py$", template = "pytest" },
            { name = "unittest", pattern = "test_.*%.py$", template = "unittest" },
        },
    }

    local ft_patterns = patterns[ft]
    if not ft_patterns then
        return nil
    end

    for _, fw in ipairs(ft_patterns) do
        if vim.fn.glob(fw.pattern) ~= "" then
            return {
                name = fw.name,
                file_pattern = fw.pattern,
                template = fw.template,
            }
        end
    end

    return ft_patterns[1]
end

--- Get test file path based on source file
--- @param context _99.RequestContext
--- @param framework _99.TestFramework
--- @return string test_file_path
local function get_test_file_path(context, framework)
    local source_path = context.full_path
    local dir = vim.fn.fnamemodify(source_path, ":h")
    local filename = vim.fn.fnamemodify(source_path, ":t")
    local base_name = filename:gsub("%.%w+$", "")

    local test_patterns = {
        lua = string.format("%s_spec.lua", base_name),
        typescript = string.format("%s.test.ts", base_name),
        javascript = string.format("%s.test.js", base_name),
        go = string.format("%s_test.go", base_name),
        rust = string.format("%s_test.rs", base_name),
        python = string.format("test_%s.py", base_name),
    }

    local ft = context.file_type
    local pattern = test_patterns[ft] or string.format("%s.test", base_name)

    return dir .. "/" .. pattern
end

--- @param context _99.RequestContext
--- @param prompt string?
local function generate_tests(context, prompt)
    local logger = context.logger:set_area("generate_tests")
    local buffer = context.buffer
    local cursor = Point:from_cursor()

    local framework = detect_test_framework(context)
    if not framework then
        logger:warn("Could not detect test framework")
        Window.display_error(
            "Could not detect test framework for this file type.\n" ..
            "Supported: Lua, TypeScript, JavaScript, Go, Rust, Python"
        )
        return
    end

    local ts = editor.treesitter
    local func = ts.containing_function(context, cursor)

    if not func then
        logger:fatal("generate_tests: cursor not on a function")
        Window.display_error("Please place cursor on a function to generate tests for it.")
        return
    end

    local request = Request.new(context)
    context.range = func.function_range

    local marks = {}
    marks.function_location = Mark.mark_func_body(buffer, func)
    context.marks = marks

    logger:info("Using framework", "framework", framework.name)

    local lsp_sig = lsp_context.get_function_signature(context, func.function_range)

    local full_prompt = string.format([[
Generate comprehensive tests for the following %s function.

Test Framework: %s (%s)
Language: %s

%s

%s

Generate tests that cover:
1. Normal/typical use cases
2. Edge cases and boundary conditions
3. Error cases and invalid inputs
4. Performance considerations if applicable

Requirements:
- Use proper assertions for the framework
- Include descriptive test names
- Add comments explaining test cases
- Mock external dependencies as needed
- Ensure tests are independent and can run in any order
]], context.file_type, framework.name, framework.template, context.file_type,
    lsp_sig and string.format("Function Signature:\n%s", lsp_sig.name) or "",
    func.function_range:to_text())

    if prompt then
        full_prompt = full_prompt .. "\n\nAdditional Context:\n" .. prompt
    end

    request:add_prompt_content(full_prompt)

    local test_file_path = get_test_file_path(context, framework)
    logger:debug("Test file path", "path", test_file_path)

    local status_display = RequestStatus.new(
        250,
        context._99.ai_stdout_rows,
        "Generating Tests",
        marks.function_location
    )
    status_display:start()

    local clean_up = make_clean_up(context, function()
        context:clear_marks()
        request:cancel()
        status_display:stop()
    end, "generate_tests")

    request:start({
        on_stdout = function(line)
            status_display:push(line)
        end,
        on_complete = function(status, response)
            vim.schedule(clean_up)

            if status == "cancelled" then
                logger:debug("generate_tests was cancelled")
                return
            end

            if status == "failed" then
                if context._99.display_errors then
                    Window.display_error(
                        "Error generating tests\n" ..
                        (response or "No Error text provided")
                    )
                end
                logger:error("unable to generate tests")
                return
            end

            if status == "success" then
                local lines = vim.split(response, "\n")

                if vim.fn.filereadable(test_file_path) == 1 then
                    local existing = vim.fn.readfile(test_file_path)
                    vim.api.nvim_list_bufs()
                end

                vim.fn.writefile(lines, test_file_path)

                logger:info("Tests written", "file", test_file_path)
                Window.display_cancellation_message(
                    string.format("Tests generated for %s\nWritten to: %s",
                        framework.name,
                        vim.fn.fnamemodify(test_file_path, ":t")
                    )
                )
            end
        end,
        on_stderr = function(line)
            logger:debug("generate_tests#on_stderr", "line", line)
        end,
    })
end

return generate_tests
