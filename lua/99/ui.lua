local StatusLineComponent = require("99.ui.statusline").Component
local Window = require("99.window")
local Logger = require("99.logger.logger")

local M = {}

--- @class _99.StatusLineManager
--- @field namespace number
--- @field components table<string, _99.StatusLineComponent>
--- @field autocommand number?

local StatusLineManager = {}
StatusLineManager.__index = StatusLineManager

--- @return _99.StatusLineManager
function StatusLineManager.new()
    local namespace = vim.api.nvim_create_namespace("99.statusline")

    return setmetatable({
        namespace = namespace,
        components = {},
        autocommand = nil,
    }, StatusLineManager)
end

--- Add a component to the status line
--- @param name string
--- @param component _99.StatusLineComponent
function StatusLineManager:add_component(name, component)
    self.components[name] = component
end

--- Get the status line string
--- @return string
function StatusLineManager:get_statusline()
    if not self.enabled then
        return ""
    end

    local parts = {}
    for name, component in pairs(self.components) do
        if component.enabled then
            table.insert(parts, component:get_value())
        end
    end

    return table.concat(parts, " ")
end

--- Enable the status line
function StatusLineManager:enable()
    self.enabled = true
    self.autocommand = vim.api.nvim_create_autocmd({
        "BufWinEnter",
        "BufWritePost",
    }, {
        group = vim.api.nvim_create_augroup("99_statusline_update", {}),
        callback = function()
            self:refresh()
        end,
    })
end

--- Disable the status line
function StatusLineManager:refresh()
    if not self.enabled then
        return
    end

    local value = self:get_statusline()
    vim.api.nvim_buf_set_var(0, "ninety_nine_statusline", value)
end

--- Disable the status line
function StatusLineManager:disable()
    self.enabled = false
    if self.autocommand then
        pcall(vim.api.nvim_del_autocmd_by_id, self.autocommand)
    end

    return manager
end

--- @param state _99.State
function M.init(state)
    state.ui_statusline_manager = StatusLineManager.new()
    state.ui_statusline_manager:enable()
end

M.StatusLineManager = StatusLineManager

return M
