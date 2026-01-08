local Logger = require("99.logger.logger")

---@alias _99.Error.Type "recoverable" | "fatal" | "timeout" | "cancelled"

---@class _99.Error
---@field code string
---@field type _99.Error.Type
---@field message string
---@field details string?
---@field recoverable boolean
---@field recovery_suggestion string?
local Error = {}
Error.__index = Error

Error.codes = {
    STATE_CORRUPTED = "STATE_CORRUPTED",
    REQUEST_TIMEOUT = "REQUEST_TIMEOUT",
    LSP_NOT_AVAILABLE = "LSP_NOT_AVAILABLE",
    BUFFER_INVALID = "BUFFER_INVALID",
    MARK_INVALID = "MARK_INVALID",
    PROVIDER_ERROR = "PROVIDER_ERROR",
    PARSE_ERROR = "PARSE_ERROR",
    OPERATION_CANCELLED = "OPERATION_CANCELLED",
    OPERATION_FAILED = "OPERATION_FAILED",
    CONFIG_INVALID = "CONFIG_INVALID",
    LANGUAGE_NOT_SUPPORTED = "LANGUAGE_NOT_SUPPORTED",
    FUNCTION_NOT_FOUND = "FUNCTION_NOT_FOUND",
}

---@param code string
---@param error_type _99.Error.Type
---@param message string
---@param details string?
---@return _99.Error
function Error.new(code, error_type, message, details)
    return setmetatable({
        code = code,
        type = error_type,
        message = message,
        details = details,
        recoverable = error_type ~= "fatal",
    }, Error)
end

function Error:with_recovery(suggestion)
    self.recovery_suggestion = suggestion
    return self
end

---@return string
function Error:to_string()
    local parts = {
        string.format("[99 Error] %s (%s)", self.message, self.code),
    }

    if self.details then
        table.insert(parts, string.format("Details: %s", self.details))
    end

    if self.recovery_suggestion then
        table.insert(parts, string.format("Suggestion: %s", self.recovery_suggestion))
    end

    return table.concat(parts, "\n")
end

---@param code string
---@param message string
---@return _99.Error
function Error.fatal(code, message)
    return Error.new(code, "fatal", message)
end

---@param code string
---@param message string
---@param details string?
---@return _99.Error
function Error.recoverable(code, message, details)
    return Error.new(code, "recoverable", message, details)
end

function Error.timeout(message)
    return Error.new(Error.codes.REQUEST_TIMEOUT, "timeout", message or "Operation timed out")
end

function Error.cancelled()
    return Error.new(Error.codes.OPERATION_CANCELLED, "cancelled", "Operation was cancelled")
end

---@return _99.Error?
function Error.from_pcall(success, result)
    if success then
        return nil
    end

    if type(result) == "table" and getmetatable(result) == Error then
        return result
    end

    return Error.fatal(Error.codes.OPERATION_FAILED, tostring(result))
end

---@param err _99.Error
function Error.log(err)
    if err.type == "fatal" then
        Logger:fatal(err.message, "code", err.code, "details", err.details)
    elseif err.type == "timeout" then
        Logger:warn(err.message, "code", err.code)
    elseif err.type == "cancelled" then
        Logger:debug(err.message, "code", err.code)
    else
        Logger:error(err.message, "code", err.code, "details", err.details)
    end

    if err.recovery_suggestion then
        Logger:info("Recovery suggestion", "suggestion", err.recovery_suggestion)
    end
end

return Error
