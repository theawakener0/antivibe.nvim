local Logger = require("99.logger.logger")
local OpenCodeProvider = require("99.request.opencode")

local M = {}

--- @class _99.TestOpenCodeProvider
--- @field version string
--- @field responses table<string, string>
--- @field should_use_real_opencode boolean

local TestOpenCodeProvider = {}
TestOpenCodeProvider.__index = TestOpenCodeProvider

--- @return _99.TestOpenCodeProvider
function TestOpenCodeProvider.new()
    local should_use_real = vim.env.USE_REAL_OPENCODE == "1"

    return setmetatable({
        version = should_use_real and OpenCodeProvider.new():get_version() or "test",
        responses = {},
        should_use_real_opencode = should_use_real,
    }, TestOpenCodeProvider)
end

--- Mock a response for a query
--- @param query string
--- @param response string
function TestOpenCodeProvider:mock_response(query, response)
    local query_hash = vim.fn.sha256(query)
    self.responses[query_hash] = response
end

--- Clear all mocked responses
function TestOpenCodeProvider:clear_mocks()
    self.responses = {}
end

--- @param query string
--- @param request _99.Request
--- @param observer _99.ProviderObserver
function TestOpenCodeProvider:make_request(query, request, observer)
    local logger = request.logger:set_area("TestOpenCodeProvider")

    if self.should_use_real_opencode then
        logger:info("Using real OpenCode provider")
        OpenCodeProvider.make_request(self, query, request, observer)
        return
    end

    logger:debug("make_request (mocked)", "query", query)

    local query_hash = vim.fn.sha256(query)
    local mock_response = self.responses[query_hash]

    if mock_response then
        logger:debug("Using mocked response", "hash", query_hash:sub(1, 8))

        vim.schedule(function()
            observer.on_stdout("Processing request...")
            vim.schedule(function()
                observer.on_stdout("Generating response...")
                vim.schedule(function()
                    local tmp = request.context.tmp_file
                    local ok, err = pcall(function()
                        vim.fn.writefile(vim.split(mock_response, "\n"), tmp)
                        return nil
                    end)

                    if ok then
                        vim.schedule(function()
                            local ok_read, res = OpenCodeProvider.retrieve_response(tmp, logger)
                            if ok_read then
                                observer.on_complete("success", res)
                            else
                                observer.on_complete("failed", res)
                            end
                        end)
                    else
                        logger:error("Failed to write mock response", "error", err)
                        observer.on_complete("failed", "Failed to write mock response")
                    end
                end)
            end)
        end)
    else
        logger:warn("No mock response found", "hash", query_hash:sub(1, 8))
        logger:info("Use set_mock_response() to mock the answer")

        vim.schedule(function()
            observer.on_complete(
                "success",
                "-- MOCK MODE: No response provided.\n" ..
                "-- Use TestOpenCodeProvider:mock_response(query, answer)\n" ..
                "-- to mock the response for this query."
            )
        end)
    end
end

--- Check if this provider is using real OpenCode
--- @return boolean
function TestOpenCodeProvider:using_real_opencode()
    return self.should_use_real_opencode
end

M.TestOpenCodeProvider = TestOpenCodeProvider

return M
