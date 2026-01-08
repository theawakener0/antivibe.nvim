local Logger = require("99.logger.logger")

--- @class _99.OpenCodeProvider
--- @field version string?
--- @field capabilities table<string, boolean>
local OpenCodeProvider = {}
OpenCodeProvider.__index = OpenCodeProvider

--- Detect OpenCode CLI version
--- @return string?
local function detect_opencode_version()
    local ok, result = pcall(vim.system, { "opencode", "--version" }, { text = true })
    if not ok then
        return nil
    end

    local stdout = result.stdout or ""
    local version_match = stdout:match("opencode ([%d%.]+[%d%.]*[%d]*)")
    return version_match
end

--- Check if OpenCode supports a feature
--- @param version string?
--- @param feature string
--- @return boolean
local function check_capability(version, feature)
    local capability_checks = {
        timeout = function(v)
            return v and (tonumber(v) >= 1.0)
        end,
        streaming = function(v)
            return v and (tonumber(v) >= 1.0)
        end,
    }

    local check_fn = capability_checks[feature]
    if check_fn then
        return check_fn(version)
    end

    return true
end

--- Create new OpenCode provider
--- @return _99.OpenCodeProvider
function OpenCodeProvider.new()
    local version = detect_opencode_version()
    local capabilities = {}

    capabilities.timeout = check_capability(version, "timeout")
    capabilities.streaming = check_capability(version, "streaming")

    Logger:info(
        "OpenCodeProvider initialized",
        "version",
        version or "unknown",
        "capabilities",
        vim.inspect(capabilities)
    )

    return setmetatable({
        version = version,
        capabilities = capabilities,
    }, OpenCodeProvider)
end

--- Retrieve response from temp file
--- @param tmp_file string
--- @param logger _99.Logger
--- @return boolean success
--- @return string response
function OpenCodeProvider.retrieve_response(tmp_file, logger)
    local success, result = pcall(function()
        return vim.fn.readfile(tmp_file)
    end)

    if not success then
        logger:error(
            "retrieve_results: failed to read file",
            "tmp_name",
            tmp_file,
            "error",
            result
        )
        return false, ""
    end

    local str = table.concat(result, "\n")
    logger:debug("retrieve_results", "results", str)

    return true, str
end

--- @param query string
--- @param request _99.Request
--- @param observer _99.ProviderObserver
function OpenCodeProvider:make_request(query, request, observer)
    local logger = request.logger:set_area("OpenCodeProvider")
    logger:debug("make_request", "tmp_file", request.context.tmp_file)

    local command = { "opencode", "run", "-m", request.context.model, query }
    logger:debug("make_request", "command", command)

    vim.system(
        command,
        {
            text = true,
            stdout = vim.schedule_wrap(function(err, data)
                logger:debug("stdout", "data", data)
                if request:is_cancelled() then
                    observer.on_complete("cancelled", "")
                    return
                end
                if err and err ~= "" then
                    logger:debug("stdout#error", "err", err)
                end
                if not err then
                    observer.on_stdout(data)
                end
            end),
            stderr = vim.schedule_wrap(function(err, data)
                logger:debug("stderr", "data", data)
                if request:is_cancelled() then
                    observer.on_complete("cancelled", "")
                    return
                end
                if err and err ~= "" then
                    logger:debug("stderr#error", "err", err)
                end
                if not err then
                    observer.on_stderr(data)
                end
            end),
        },
        vim.schedule_wrap(function(obj)
            if request:is_cancelled() then
                observer.on_complete("cancelled", "")
                logger:debug("on_complete: request has been cancelled")
                return
            end
            if obj.code ~= 0 then
                local str = string.format(
                    "process exit code: %d\n%s",
                    obj.code,
                    vim.inspect(obj)
                )
                observer.on_complete("failed", str)
                logger:fatal(
                    "opencode make_query failed",
                    "obj from results",
                    obj
                )
                return
            end

            local ok, res = self.retrieve_response(request.context.tmp_file, logger)
            if ok then
                observer.on_complete("success", res)
            else
                observer.on_complete(
                    "failed",
                    "unable to retrieve response from llm"
                )
            end
        end)
    )
end

--- @param feature string
--- @return boolean
function OpenCodeProvider:has_capability(feature)
    return self.capabilities[feature] == true
end

--- @return string?
function OpenCodeProvider:get_version()
    return self.version
end

return OpenCodeProvider
