local M = {}

--- @class _99.StatusLineComponent
--- @field enabled boolean
--- @field highlight string
--- @field icon string
--- @field update_fun fun(): string?

local Component = {}
Component.__index = Component

--- @param icon string
--- @param update_fun fun(): string?
--- @param highlight string?
--- @return _99.StatusLineComponent
function Component.new(icon, update_fun, highlight)
    return setmetatable({
        enabled = true,
        icon = icon,
        update_fun = update_fun,
        highlight = highlight or "Comment",
    }, Component)
end

--- @return string
function Component:get_value()
    if not self.enabled then
        return ""
    end

    if self.update_fun then
        local value = self.update_fun()
        return self.icon .. value
    else
        return self.icon
    end
end

--- @param enabled boolean
function Component:set_enabled(enabled)
    self.enabled = enabled
end

M.Component = Component

return M
