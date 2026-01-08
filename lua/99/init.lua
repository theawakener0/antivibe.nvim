local Logger = require("99.logger.logger")
local Level = require("99.logger.level")
local Error = require("99.error")
local ops = require("99.ops")
local Languages = require("99.language")
local Window = require("99.window")
local UI = require("99.ui")
local get_id = require("99.id")
local RequestContext = require("99.request-context")
local Range = require("99.geo").Range
local Config = require("99.config")
local Config = require("99.config")

--- @alias _99.Cleanup fun(): nil

--- @class _99.RequestMetadata
--- @field id number
--- @field operation_type string
--- @field start_time number
--- @field cleanup _99.Cleanup

--- @class _99.StateProps
--- @field model string
--- @field md_files string[]
--- @field prompts _99.Prompts
--- @field ai_stdout_rows number
--- @field languages string[]
--- @field display_errors boolean
--- @field provider_override _99.Provider?
--- @field __requests table<number, _99.RequestMetadata>
--- @field __request_queue _99.RequestMetadata[]
--- @field __is_processing_queue boolean
--- @field __view_log_idx number
--- @field __initialized boolean
--- @field timeout table<string, number>?
--- @field virtual_text table<string, any>?

--- @return _99.StateProps
local function create_99_state()
    return {
        model = "opencode/claude-opus-4-5",
        md_files = {},
        prompts = require("99.prompt-settings"),
        ai_stdout_rows = 3,
        languages = { "lua" },
        display_errors = false,
        provider_override = nil,
        __requests = {},
        __request_queue = {},
        __is_processing_queue = false,
        __view_log_idx = 1,
        __initialized = false,
        timeout = nil,
        virtual_text = nil,
    }
end

--- @class _99.Options
--- @field logger _99.Logger.Options?
--- @field model string?
--- @field md_files string[]?
--- @field provider _99.Provider?
--- @field debug_log_prefix string?
--- @field display_errors? boolean

--- Request queue manager for sequential execution to prevent mark namespace conflicts
--- @class _99.State
--- @field model string
--- @field md_files string[]
--- @field prompts _99.Prompts
--- @field ai_stdout_rows number
--- @field languages string[]
--- @field display_errors boolean
--- @field provider_override _99.Provider?
--- @field __requests table<number, _99.RequestMetadata>
--- @field __request_queue _99.RequestMetadata[]
--- @field __is_processing_queue boolean
--- @field __view_log_idx number
--- @field __initialized boolean
local _99_State = {}
_99_State.__index = _99_State

--- @return _99.State
function _99_State.new()
    local props = create_99_state()
    ---@diagnostic disable-next-line: return-type-mismatch
    return setmetatable(props, _99_State)
end

local _active_request_id = 0
---@param cleanup _99.Cleanup
---@param operation_type string
---@return number
function _99_State:add_request(cleanup, operation_type)
    _active_request_id = _active_request_id + 1
    local metadata = {
        id = _active_request_id,
        operation_type = operation_type,
        start_time = vim.loop.hrtime(),
        cleanup = cleanup,
    }
    self.__requests[_active_request_id] = metadata
    Logger:debug("adding request", "id", _active_request_id, "type", operation_type)
    return _active_request_id
end

--- Queue a request for sequential processing
---@param cleanup _99.Cleanup
---@param operation_type string
---@return number
function _99_State:queue_request(cleanup, operation_type)
    local metadata = {
        id = _active_request_id + 1,
        operation_type = operation_type,
        start_time = 0,
        cleanup = cleanup,
    }
    table.insert(self.__request_queue, metadata)
    Logger:debug("queueing request", "id", metadata.id, "type", operation_type, "queue_size", #self.__request_queue)

    if not self.__is_processing_queue then
        self:process_queue()
    end

    return metadata.id
end

--- Process the request queue sequentially
function _99_State:process_queue()
    if #self.__request_queue == 0 then
        self.__is_processing_queue = false
        return
    end

    self.__is_processing_queue = true
    local metadata = table.remove(self.__request_queue, 1)
    _active_request_id = metadata.id
    self.__requests[metadata.id] = metadata
    metadata.start_time = vim.loop.hrtime()

    Logger:debug("processing queued request", "id", metadata.id, "type", metadata.operation_type)
end

function _99_State:active_request_count()
    local count = 0
    for _ in pairs(self.__requests) do
        count = count + 1
    end
    return count
end

function _99_State:queued_request_count()
    return #self.__request_queue
end

---@param id number
function _99_State:remove_request(id)
    local logger = Logger:set_id(id)
    local r = self.__requests[id]
    logger:assert(
        r,
        "there is no active request for id.  implementation broken"
    )
    logger:debug("removing request")
    self.__requests[id] = nil

    if #self.__request_queue > 0 then
        self:process_queue()
    end
end

--- Teardown all active requests, marks, and windows
--- Use this before re-setup or plugin unload
function _99_State:teardown()
    for id, metadata in pairs(self.__requests) do
        Logger:debug("teardown: stopping request", "id", id)
        pcall(metadata.cleanup)
        self.__requests[id] = nil
    end

    for _, metadata in ipairs(self.__request_queue) do
        Logger:debug("teardown: cancelling queued request", "id", metadata.id)
        pcall(metadata.cleanup)
    end

    self.__request_queue = {}
    self.__is_processing_queue = false
    Window.clear_active_popups()
end

--- Check if state is initialized
---@return boolean
function _99_State:is_initialized()
    return self.__initialized
end

local _99_state = _99_State.new()

--- @class _99
local _99 = {
    DEBUG = Level.DEBUG,
    INFO = Level.INFO,
    WARN = Level.WARN,
    ERROR = Level.ERROR,
    FATAL = Level.FATAL,
}

--- you can only set those marks after the visual selection is removed
local function set_selection_marks()
    vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
        "x",
        false
    )
end

--- @param operation_name string
--- @return _99.RequestContext
local function get_context(operation_name)
    local trace_id = get_id()
    local context = RequestContext.from_current_buffer(_99_state, trace_id)
    context.logger:debug("99 Request", "method", operation_name)
    return context
end

function _99.info()
    local info = {}
    table.insert(
        info,
        string.format("Agent Files: %s", table.concat(_99_state.md_files, ", "))
    )
    table.insert(info, string.format("Model: %s", _99_state.model))
    table.insert(
        info,
        string.format("AI Stdout Rows: %d", _99_state.ai_stdout_rows)
    )
    table.insert(
        info,
        string.format("Display Errors: %s", tostring(_99_state.display_errors))
    )
    table.insert(
        info,
        string.format("Active Requests: %d", _99_state:active_request_count())
    )
    table.insert(
        info,
        string.format("Queued Requests: %d", _99_state:queued_request_count())
    )

    if _99_state.languages then
        table.insert(
            info,
            string.format("Languages: %s", table.concat(_99_state.languages, ", "))
        )
    end

    if _99_state.timeout then
        table.insert(info, "Timeouts:")
        for op, ms in pairs(_99_state.timeout) do
            table.insert(info, string.format("  %s: %dms", op, ms))
        end
    end

    if _99_state.virtual_text then
        table.insert(info, "Virtual Text:")
        table.insert(info, string.format("  Enabled: %s", tostring(_99_state.virtual_text.enabled)))
        table.insert(info, string.format("  Max Lines: %d", _99_state.virtual_text.max_lines))
    end

    Window.display_centered_message(info)
end

function _99.fill_in_function_prompt()
    local context = get_context("fill-in-function-with-prompt")
    context.logger:debug("start")
    Window.capture_input(function(success, response)
        context.logger:debug(
            "capture_prompt",
            "success",
            success,
            "response",
            response
        )
        if success then
            ops.fill_in_function(context, response)
        end
    end, {})
end

function _99.fill_in_function()
    ops.fill_in_function(get_context("fill_in_function"))
end

function _99.visual_prompt()
    local context = get_context("over-range-with-prompt")
    context.logger:debug("start")
    Window.capture_input(function(success, response)
        context.logger:debug(
            "capture_prompt",
            "success",
            success,
            "response",
            response
        )
        if success then
            _99.visual(response)
        end
    end, {})
end

--- @param prompt string?
--- @param context _99.RequestContext?
function _99.visual(prompt, context)
    set_selection_marks()

    context = context or get_context("over-range")
    local range = Range.from_visual_selection()
    ops.over_range(context, range, prompt)
end

function _99.generate_tests()
    local context = get_context("generate_tests")
    ops.generate_tests(context)
end

function _99.generate_tests_prompt()
    local context = get_context("generate_tests_with_prompt")
    context.logger:debug("start")
    Window.capture_input(function(success, response)
        context.logger:debug(
            "capture_prompt",
            "success",
            success,
            "response",
            response
        )
        if success then
            ops.generate_tests(context, response)
        end
    end, {})
end

function _99.explain_code(prompt)
    ops.explain_code(get_context("explain_code"), prompt)
end

function _99.explain_code_prompt()
    local context = get_context("explain_code_with_prompt")
    context.logger:debug("start")
    Window.capture_input(function(success, response)
        context.logger:debug(
            "capture_prompt",
            "success",
            success,
            "response",
            response
        )
        if success then
            _99.explain_code(response)
        end
    end, {})
end

function _99.refactor(prompt)
    ops.refactor(get_context("refactor"), prompt)
end

function _99.refactor_prompt()
    local context = get_context("refactor_with_prompt")
    context.logger:debug("start")
    Window.capture_input(function(success, response)
        context.logger:debug(
            "capture_prompt",
            "success",
            success,
            "response",
            response
        )
        if success then
            _99.refactor(response)
        end
    end, {})
end

function _99.inline_doc()
    local context = get_context("inline_doc")
    ops.inline_doc(context)
end

--- Quick pick menu for operations
function _99.show_operation_menu()
    require("99.ui.quickpick").show_operation_menu()
end

--- Get current configuration
function _99.get_config()
    local config = {
        model = _99_state.model,
        md_files = _99_state.md_files,
        display_errors = _99_state.display_errors,
        ai_stdout_rows = _99_state.ai_stdout_rows,
        languages = _99_state.languages,
        timeout = _99_state.timeout,
        virtual_text = _99_state.virtual_text,
        is_initialized = _99_state:is_initialized(),
    }

    if _99_state.timeout then
        config.timeout = vim.deepcopy(_99_state.timeout)
    end

    if _99_state.virtual_text then
        config.virtual_text = vim.deepcopy(_99_state.virtual_text)
    end

    return config
end

--- Reset configuration to defaults
function _99.reset_config()
    local defaults = Config.reset_to_defaults()
    _99_state.model = defaults.model
    _99_state.md_files = defaults.md_files
    _99_state.display_errors = defaults.display_errors
    _99_state.ai_stdout_rows = defaults.ai_stdout_rows
    _99_state.languages = defaults.languages
    _99_state.timeout = defaults.timeout
    _99_state.virtual_text = defaults.virtual_text

    return _99.get_config()
end

--- View all the logs that are currently cached.  Cached log count is determined
--- by _99.Logger.Options that are passed in.
function _99.view_logs()
    _99_state.__view_log_idx = 1
    local logs = Logger.logs()
    if #logs == 0 then
        print("no logs to display")
        return
    end
    Window.display_full_screen_message(logs[1])
end

function _99.prev_request_logs()
    local logs = Logger.logs()
    if #logs == 0 then
        print("no logs to display")
        return
    end
    _99_state.__view_log_idx = math.min(_99_state.__view_log_idx + 1, #logs)
    Window.display_full_screen_message(logs[_99_state.__view_log_idx])
end

function _99.next_request_logs()
    local logs = Logger.logs()
    if #logs == 0 then
        print("no logs to display")
        return
    end
    _99_state.__view_log_idx = math.max(_99_state.__view_log_idx - 1, 1)
    Window.display_full_screen_message(logs[_99_state.__view_log_idx])
end

function _99.__debug_ident()
    ops.debug_ident(_99_state)
end

function _99.stop_all_requests()
    for id, metadata in pairs(_99_state.__requests) do
        Logger:debug("stop_all_requests: stopping request", "id", id)
        pcall(metadata.cleanup)
        _99_state.__requests[id] = nil
    end

    for _, metadata in ipairs(_99_state.__request_queue) do
        Logger:debug("stop_all_requests: cancelling queued request", "id", metadata.id)
        pcall(metadata.cleanup)
    end

    _99_state.__request_queue = {}
    _99_state.__is_processing_queue = false
end

--- if you touch this function you will be fired
--- @return _99.State
function _99.__get_state()
    return _99_state
end

--- @param opts _99.Options?
function _99.setup(opts)
    local merged_config = Config.merge_with_defaults(opts)

    if _99_state:is_initialized() then
        Logger:info("setup: tearing down existing state before re-setup")
        _99_state:teardown()
    end

    _99_state = _99_State.new()
    _99_state.provider_override = merged_config.provider

    Logger:configure(merged_config.logger)
    _99_state.model = merged_config.model
    _99_state.md_files = merged_config.md_files
    _99_state.display_errors = merged_config.display_errors
    _99_state.ai_stdout_rows = merged_config.ai_stdout_rows
    _99_state.languages = merged_config.languages

    if merged_config.timeout then
        _99_state.timeout = merged_config.timeout
    end

    if merged_config.virtual_text then
        _99_state.virtual_text = merged_config.virtual_text
    end

    Languages.initialize(_99_state)
    UI.init(_99_state)

    _99_state.__initialized = true
end

--- @param md string
--- @return _99
function _99.add_md_file(md)
    table.insert(_99_state.md_files, md)
    return _99
end

--- @param md string
--- @return _99
function _99.rm_md_file(md)
    for i, name in ipairs(_99_state.md_files) do
        if name == md then
            table.remove(_99_state.md_files, i)
            break
        end
    end
    return _99
end

--- @param model string
--- @return _99
function _99.set_model(model)
    _99_state.model = model
    return _99
end

--- Get current configuration
--- @return table
function _99.get_config()
    return {
        model = _99_state.model,
        md_files = _99_state.md_files,
        display_errors = _99_state.display_errors,
        ai_stdout_rows = _99_state.ai_stdout_rows,
        languages = _99_state.languages,
        timeout = _99_state.timeout,
        virtual_text = _99_state.virtual_text,
        is_initialized = _99_state:is_initialized(),
    }
end

--- Reset configuration to defaults
--- @return table
function _99.reset_config()
    local defaults = Config.reset_to_defaults()
    _99_state.model = defaults.model
    _99_state.md_files = defaults.md_files
    _99_state.display_errors = defaults.display_errors
    _99_state.ai_stdout_rows = defaults.ai_stdout_rows
    _99_state.languages = defaults.languages
    _99_state.timeout = defaults.timeout
    _99_state.virtual_text = defaults.virtual_text
    return _99.get_config()
end

function _99.__debug()
    Logger:configure({
        path = nil,
        level = Level.DEBUG,
    })
end

return _99
