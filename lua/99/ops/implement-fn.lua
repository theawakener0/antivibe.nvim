local Request = require("99.request")
local editor = require("99.editor")
local geo = require("99.geo")
local Range = geo.Range
local Point = geo.Point
local Mark = require("99.ops.marks")
local RequestStatus = require("99.ops.request_status")
local make_clean_up = require("99.ops.clean-up")
local Window = require("99.window")

--- @param context _99.RequestContext
--- @param response string
local function update_code(context, response)
    local code_mark = context.marks.code_placement
    local logger = context.logger:set_area("implement_fn#update_code")
    local point = Point.from_mark(code_mark)

    logger:debug("setting text at mark", "Point", point)
    code_mark:set_text_at_mark("\n" .. response)
end

--- @param context _99.RequestContext
local function implement_fn(context)
    local ts = editor.treesitter
    local cursor = Point:from_cursor()
    local buffer = vim.api.nvim_get_current_buf()
    local fn_call = ts.fn_call(context, cursor)
    local logger = context.logger:set_area("implement_fn")

    if not fn_call then
        logger:fatal(
            "cannot implement function, cursor was not on an identifier that is a function call"
        )
        return
    end

    local range = Range:from_ts_node(fn_call, buffer)
    local request = Request.new(context)

    context.marks.end_of_fn_call = Mark.mark_end_of_range(buffer, range)
    local func = ts.containing_function(context, cursor)
    if func then
        context.marks.code_placement = Mark.mark_above_func(buffer, func)
    else
        context.marks.code_placement = Mark.mark_above_range(range)
    end

    local code_placement = RequestStatus.new(
        250,
        context._99.ai_stdout_rows,
        "Loading",
        context.marks.code_placement
    )
    local at_call_site = RequestStatus.new(
        250,
        1,
        "Implementing Function",
        context.marks.end_of_fn_call
    )

    code_placement:start()
    at_call_site:start()

    local clean_up = make_clean_up(context, function()
        context:clear_marks()
        request:cancel()
        code_placement:stop()
        at_call_site:stop()
    end, "implement_fn")

    request:add_prompt_content(context._99.prompts.prompts.implement_function)
    request:start({
        on_stdout = function(line)
            code_placement:push(line)
        end,
        on_complete = function(status, response)
            vim.schedule(clean_up)
            if status ~= "success" then
                local err_msg = response or "No error text provided"
                logger:fatal(
                    "unable to implement function",
                    "status",
                    status,
                    "error",
                    err_msg
                )

                if context._99.display_errors then
                    Window.display_error(
                        string.format("Error implementing function\n%s", err_msg)
                    )
                end
                return
            end

            local success, err = pcall(update_code, context, response)
            if not success then
                logger:error(
                    "failed to update code after implementation",
                    "error",
                    err
                )
                if context._99.display_errors then
                    Window.display_error(
                        string.format("Failed to insert implementation\n%s", tostring(err))
                    )
                end
            end
        end,
        on_stderr = function(line)
            logger:error("stderr", "line", line)
        end,
    })

    return request
end

return implement_fn
