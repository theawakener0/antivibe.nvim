--- @alias _99.Request.State "ready" | "calling-model" | "parsing-result" | "updating-file" | "cancelled"
--- @alias _99.Request.ResponseState "failed" | "success" | "cancelled"

--- @class _99.ProviderObserver
--- @field on_stdout fun(line: string): nil
--- @field on_stderr fun(line: string): nil
--- @field on_complete fun(status: _99.Request.ResponseState, res: string): nil

--- @class _99.Provider
--- @field make_request fun(self: _99.Provider, query: string, request: _99.Request, observer: _99.ProviderObserver): nil

local OpenCodeProvider = require("99.request.opencode")

local DevNullObserver = {
    name = "DevNullObserver",
    on_stdout = function() end,
    on_stderr = function() end,
    on_complete = function() end,
}

--- @param fn fun(...: any): nil
--- @return fun(...: any): nil
local function once(fn)
    local called = false
    return function(...)
        if called then
            return
        end
        called = true
        fn(...)
    end
end

--- @class _99.Request.Opts
--- @field model string
--- @field tmp_file string
--- @field provider _99.Provider?
--- @field xid number

--- @class _99.Request.Config
--- @field model string
--- @field tmp_file string
--- @field provider _99.Provider
--- @field xid number

--- @class _99.Request
--- @field context _99.RequestContext
--- @field state _99.Request.State
--- @field provider _99.Provider
--- @field logger _99.Logger
--- @field _content string[]
local Request = {}
Request.__index = Request

--- @param context _99.RequestContext
--- @return _99.Request
function Request.new(context)
    local provider = context._99.provider_override or OpenCodeProvider.new()
    return setmetatable({
        context = context,
        provider = provider,
        state = "ready",
        logger = context.logger:set_area("Request"),
        _content = {},
    }, Request)
end

function Request:cancel()
    self.logger:debug("cancel")
    self.state = "cancelled"
end

function Request:is_cancelled()
    return self.state == "cancelled"
end

--- @param content string
--- @return self
function Request:add_prompt_content(content)
    table.insert(self._content, content)
    return self
end

--- @param observer _99.ProviderObserver?
--- @param timeout_ms number?
function Request:start(observer, timeout_ms)
    self.context:finalize()
    for _, content in ipairs(self.context.ai_context) do
        self:add_prompt_content(content)
    end

    local query = table.concat(self._content, "\n")
    observer = observer or DevNullObserver

    local timeout = timeout_ms or self:default_timeout()

    self.logger:debug("start", "query", query, "timeout_ms", timeout)

    local timeout_timer = vim.loop.new_timer()
    local timed_out = false

    timeout_timer:start(timeout, 0, vim.schedule_wrap(function()
        if not self:is_cancelled() then
            timed_out = true
            self:cancel()
            self.logger:warn("request timed out", "timeout_ms", timeout)

            if observer.on_complete then
                observer.on_complete("failed", "Request timed out after " .. timeout .. "ms")
            end
        end
    end))

    local wrapped_observer = {
        on_stdout = function(line)
            if not timed_out and observer.on_stdout then
                observer.on_stdout(line)
            end
        end,
        on_stderr = function(line)
            if not timed_out and observer.on_stderr then
                observer.on_stderr(line)
            end
        end,
        on_complete = function(status, res)
            timeout_timer:stop()
            if observer.on_complete then
                observer.on_complete(status, res)
            end
        end,
    }

    self.provider:make_request(query, self, wrapped_observer)
end

--- @return number
function Request:default_timeout()
    local operation_type = self.context and self.context.operation_type or "default"

    if self.context._99 and self.context._99.timeout then
        return self.context._99.timeout[operation_type] or self.context._99.timeout.default or 30000
    end

    return 30000
end

return Request
