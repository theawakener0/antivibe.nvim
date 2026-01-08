local M = {}

function M.next_frame()
    local next = false
    vim.schedule(function()
        next = true
    end)

    vim.wait(1000, function()
        return next
    end)
end

M.created_files = {}

--- @class _99.test.ProviderRequest
--- @field query string
--- @field request _99.Request
--- @field observer _99.ProviderObserver?
--- @field logger _99.Logger

--- @class _99.test.Provider : _99.Provider
--- @field request _99.test.ProviderRequest?
local TestProvider = {}
TestProvider.__index = TestProvider

function TestProvider.new()
    return setmetatable({}, TestProvider)
end

--- @param query string
---@param request _99.Request
---@param observer _99.ProviderObserver?
function TestProvider:make_request(query, request, observer)
    local logger = request.context.logger:set_area("TestProvider")
    logger:debug("make_request", "tmp_file", request.context.tmp_file)
    self.request = {
        query = query,
        request = request,
        observer = observer,
        logger = logger,
    }
end

--- @param status _99.Request.ResponseState
--- @param result string
function TestProvider:resolve(status, result)
    assert(self.request, "you cannot call resolve until make_request is called")
    local obs = self.request.observer
    if obs then
        --- to match the behavior expected from the OpenCodeProvider
        if self.request.request:is_cancelled() then
            obs.on_complete("cancelled", result)
        else
            obs.on_complete(status, result)
        end
    end
    self.request = nil
end

--- @param line string
function TestProvider:stdout(line)
    assert(self.request, "you cannot call stdout until make_request is called")
    local obs = self.request.observer
    if obs then
        obs.on_stdout(line)
    end
end

--- @param line string
function TestProvider:stderr(line)
    assert(self.request, "you cannot call stderr until make_request is called")
    local obs = self.request.observer
    if obs then
        obs.on_stderr(line)
    end
end

M.TestProvider = TestProvider

function M.clean_files()
    for _, bufnr in ipairs(M.created_files) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end
    M.created_files = {}
end

--- Wait for condition with timeout
--- @param predicate fun(): boolean
--- @param timeout_ms number?
--- @return boolean success
function M.wait_for(predicate, timeout_ms)
    timeout_ms = timeout_ms or 5000
    local start = vim.loop.hrtime()
    local elapsed = 0

    while not predicate() and elapsed < timeout_ms do
        vim.wait(10, function() return false end)
        elapsed = (vim.loop.hrtime() - start) / 1000000
    end

    return predicate()
end

--- Assert condition with timeout
--- @param predicate fun(): boolean
--- @param timeout_ms number?
--- @param message string?
function M.assert_wait(predicate, timeout_ms, message)
    local success = M.wait_for(predicate, timeout_ms)
    if not success then
        error(message or "Condition not met within timeout")
    end
end

--- Check if buffer exists and is valid
--- @param bufnr number
--- @return boolean
function M.is_buffer_valid(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr)
end

--- Ensure buffer is cleaned up after test
--- @param bufnr number
function M.ensure_buffer_cleanup(bufnr)
    vim.api.nvim_create_autocmd(
        "BufWipeout",
        {
            callback = function()
                if M.is_buffer_valid(bufnr) then
                    vim.api.nvim_buf_delete(bufnr, { force = true })
                end
            end,
            once = true,
            pattern = string.format("<buffer=%d>", bufnr),
        }
    )
end

---@param contents string[]
---@param file_type string?
---@param row number?
---@param col number?
function M.create_file(contents, file_type, row, col)
    assert(type(contents) == "table", "contents must be a table of strings")
    file_type = file_type or "lua"
    local bufnr = vim.api.nvim_create_buf(false, false)

    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_set_option_value("filetype", file_type, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    vim.api.nvim_win_set_cursor(0, { row or 1, col or 0 })

    table.insert(M.created_files, bufnr)
    return bufnr
end

return M
