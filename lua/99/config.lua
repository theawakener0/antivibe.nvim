local Logger = require("99.logger.logger")
local Error = require("99.error")

local M = {}

--- @class _99.ConfigSchema
--- @field schema table<string, table>
--- @field defaults table<string, any>

--- @class _99.ValidationResult
--- @field valid boolean
--- @field errors table<string, string>
--- @field warnings table<string, string>

--- Configuration schema with defaults and validation
local CONFIG_SCHEMA = {
    model = {
        type = "string",
        required = false,
        default = "opencode/claude-opus-4-5",
    },
    md_files = {
        type = "table",
        required = false,
        default = { "AGENT.md" },
        validate = function(val)
            if type(val) ~= "table" then return false, "must be a table" end
            for _, v in ipairs(val) do
                if type(v) ~= "string" then
                    return false, "all items must be strings"
                end
            end
            return true
        end,
    },
    provider = {
        type = "function",
        required = false,
        default = nil,
    },
    logger = {
        type = "table",
        required = false,
        default = {
            level = "INFO",
            path = nil,
            print_on_error = true,
            max_requests_cached = 5,
        },
        validate = function(val)
            if type(val) ~= "table" then return false, "must be a table" end
            if val.level ~= nil then
                local level_type = type(val.level)
                if level_type == "string" then
                    local valid_levels = { DEBUG = true, INFO = true, WARN = true, ERROR = true, FATAL = true }
                    if not valid_levels[val.level:upper()] then
                        return false, "level must be one of: DEBUG, INFO, WARN, ERROR, FATAL"
                    end
                elseif level_type ~= "number" then
                    return false, "level must be a string or number"
                end
            end
            if val.path and type(val.path) ~= "string" then
                return false, "path must be a string or nil"
            end
            return true
        end,
    },
    ai_stdout_rows = {
        type = "number",
        required = false,
        default = 3,
        validate = function(val)
            if type(val) ~= "number" then return false, "must be a number" end
            if val < 0 or val > 10 then
                return false, "must be between 0 and 10"
            end
            return true
        end,
    },
    languages = {
        type = "table",
        required = false,
        default = { "lua" },
        validate = function(val)
            if type(val) ~= "table" then return false, "must be a table" end
            local supported = { "lua", "typescript", "javascript", "c", "cpp", "go", "rust", "python" }
            for _, lang in ipairs(val) do
                if not vim.tbl_contains(supported, lang) then
                    return false, string.format("unsupported language: %s", lang)
                end
            end
            return true
        end,
    },
    display_errors = {
        type = "boolean",
        required = false,
        default = false,
    },
    timeout = {
        type = "table",
        required = false,
        default = {
            fill_in_function = 30000,
            visual = 45000,
            implement_fn = 30000,
            generate_tests = 60000,
            explain_code = 30000,
            refactor = 45000,
            inline_doc = 30000,
        },
        validate = function(val)
            if type(val) ~= "table" then return false, "must be a table" end
            for key, ms in pairs(val) do
                if type(ms) ~= "number" or ms < 1000 then
                    return false, string.format("timeout for %s must be at least 1000ms", key)
                end
            end
            return true
        end,
    },
    virtual_text = {
        type = "table",
        required = false,
        default = {
            enabled = true,
            max_lines = 3,
            show_ai_stdout = true,
        },
        validate = function(val)
            if type(val) ~= "table" then return false, "must be a table" end
            if type(val.enabled) ~= "boolean" then return false, "enabled must be boolean" end
            if type(val.max_lines) ~= "number" then return false, "max_lines must be number" end
            if type(val.show_ai_stdout) ~= "boolean" then return false, "show_ai_stdout must be boolean" end
            return true
        end,
    },
}

--- Validate configuration options against schema
--- @param opts table
--- @return _99.ValidationResult
function M.validate(opts)
    local result = {
        valid = true,
        errors = {},
        warnings = {},
    }

    for key, schema in pairs(CONFIG_SCHEMA) do
        if opts[key] == nil then
            if schema.required then
                result.valid = false
                table.insert(result.errors, string.format("Required option '%s' is missing", key))
            end
        elseif type(opts[key]) ~= schema.type and type(opts[key]) ~= "nil" then
            result.valid = false
            table.insert(result.errors, string.format("Option '%s' must be %s", key, schema.type))
        end
    end

    for key, schema in pairs(CONFIG_SCHEMA) do
        if opts[key] ~= nil and schema.validate then
            local ok, msg = schema.validate(opts[key])
            if not ok then
                result.valid = false
                table.insert(result.errors, string.format("Option '%s': %s", key, msg))
            end
        end
    end

    return result
end

--- Get default configuration
--- @return table
function M.get_defaults()
    local defaults = {}

    for key, schema in pairs(CONFIG_SCHEMA) do
        defaults[key] = schema.default
    end

    return defaults
end

--- Merge user options with defaults
--- @param opts table?
--- @return table
function M.merge_with_defaults(opts)
    local defaults = M.get_defaults()
    local merged = vim.tbl_deep_extend("force", defaults, opts or {})

    local validation = M.validate(merged)
    if not validation.valid then
        local error_msg = "Configuration validation failed:\n" ..
            table.concat(validation.errors, "\n")
        Logger:fatal("Config validation failed", "errors", validation.errors)
        error(Error.new(
            Error.codes.CONFIG_INVALID,
            "recoverable",
            error_msg,
            "Fix configuration options or remove invalid ones"
        ))
    end

    if #validation.warnings > 0 then
        Logger:warn("Configuration warnings", "warnings", validation.warnings)
    end

    return merged
end

--- Get configuration value with nested key support
--- @param config table
--- @param key string
--- @param default any?
--- @return any
function M.get_value(config, key, default)
    local keys = vim.split(key, ".")
    local value = config

    for i, k in ipairs(keys) do
        if type(value) ~= "table" then
            return i == #keys and value or default
        end
        value = value[k]
    end

    return value or default
end

--- Get configuration for specific language
--- @param config table
--- @param language string
--- @return table?
function M.get_language_config(config, language)
    return vim.tbl_get(config, { "language_overrides", language })
end

--- Set configuration for specific language
--- @param config table
--- @param language string
--- @param lang_config table
--- @return table
function M.set_language_config(config, language, lang_config)
    if not config.language_overrides then
        config.language_overrides = {}
    end

    config.language_overrides[language] = vim.tbl_deep_extend("force",
        config.language_overrides[language] or {},
        lang_config
    )

    return config
end

--- Reset configuration to defaults
--- @return table
function M.reset_to_defaults()
    return M.get_defaults()
end

--- Export schema for documentation
--- @return table
function M.get_schema()
    local schema = {}

    for key, def in pairs(CONFIG_SCHEMA) do
        schema[key] = {
            type = def.type,
            required = def.required,
            default = def.default,
        }
    end

    return schema
end

return M
