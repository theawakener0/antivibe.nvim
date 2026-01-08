local Logger = require("99.logger.logger")

--- @class _99.LanguageOps
--- @field log_item fun(item_name: string): string
--- @field names table<string, string>

--- @class _99.Langauges
--- @field languages table<string, _99.LanguageOps>
local M = {
    languages = {},

    filetype_aliases = {
        ["h"] = "c",
        ["hpp"] = "cpp",
        ["cc"] = "cpp",
        ["cxx"] = "cpp",
    },
}

--- @alias _99.langauge.GetLangParam _99.Location | number?

--- @param bufferOrLoc _99.langauge.GetLangParam
--- @return _99.LanguageOps
--- @return string
--- @return number
local function get_langauge(bufferOrLoc)
    local file_type

    if type(bufferOrLoc) == "number" or not bufferOrLoc then
        local buffer = bufferOrLoc or vim.api.nvim_get_current_buf()
        file_type = vim.api.nvim_get_option_value("filetype", { buf = buffer })
    else
        file_type = bufferOrLoc.file_type
    end

    local resolved_type = M.filetype_aliases[file_type] or file_type
    local lang = M.languages[resolved_type]

    if not lang then
        Logger:warn("language currently not supported", "lang", file_type)
        return nil, file_type, bufferOrLoc and bufferOrLoc.buffer or vim.api.nvim_get_current_buf()
    end

    if type(bufferOrLoc) == "number" or not bufferOrLoc then
        local buffer = bufferOrLoc or vim.api.nvim_get_current_buf()
        return lang, resolved_type, buffer
    end

    return lang, resolved_type, bufferOrLoc.buffer
end

local function validate_function(fn, file_type)
    if type(fn) ~= "function" then
        Logger:fatal("language does not support log_item", "lang", file_type)
    end
end

--- @param _99 _99.State
function M.initialize(_99)
    M.languages = {}

    local supported_languages = {
        "lua",
        "typescript",
        "c",
        "cpp",
        "go",
    }

    for _, lang in ipairs(supported_languages) do
        M.languages[lang] = require("99.language." .. lang)
    end
end

--- @param _ _99.State
--- @param item_name string
--- @param buffer number?
--- @return string
function M.log_item(_, item_name, buffer)
    local lang, file_type = get_langauge(buffer)
    if not lang then
        return item_name
    end
    validate_function(lang.log_item, file_type)

    return lang.log_item(item_name)
end

return M
