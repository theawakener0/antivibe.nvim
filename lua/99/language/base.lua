local Logger = require("99.logger.logger")

--- @class _99.LanguageOps
--- @field log_item fun(item_name: string): string
--- @field get_prompt_template fun(operation_type: string): string?
--- @field supports_lsp fun(): boolean
--- @field filetypes string[]

local M = {}

--- Base language implementation
--- @param ops _99.LanguageOps
--- @return _99.LanguageOps
function M.new(ops)
    local default_ops = {
        log_item = function(item_name)
            return string.format("%s", item_name)
        end,
        get_prompt_template = function(_)
            return nil
        end,
        supports_lsp = function()
            return true
        end,
        filetypes = {},
    }

    return setmetatable(vim.tbl_extend("force", default_ops, ops or {}), {
        __index = function(self, key)
            return ops[key] or default_ops[key]
        end
    })
end

--- Check if filetype is supported by this language
--- @param ops _99.LanguageOps
--- @param filetype string
--- @return boolean
function M.supports_filetype(ops, filetype)
    for _, ft in ipairs(ops.filetypes) do
        if ft == filetype then
            return true
        end
    end
    return false
end

--- Format item for logging/debugging
--- @param ops _99.LanguageOps
--- @param item_name string
--- @return string
function M.log_item(ops, item_name)
    return ops.log_item(item_name)
end

--- Get language-specific prompt template
--- @param ops _99.LanguageOps
--- @param operation_type string
--- @return string?
function M.get_prompt_template(ops, operation_type)
    return ops.get_prompt_template(operation_type)
end

--- Check if language supports LSP
--- @param ops _99.LanguageOps
--- @return boolean
function M.supports_lsp(ops)
    return ops.supports_lsp()
end

return M
