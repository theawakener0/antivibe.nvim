local Window = require("99.window")
local Logger = require("99.logger.logger")

local M = {}

--- @class _99.MenuItem
--- @field label string
--- @field action fun()
--- @field keybinding string?

local function show_menu(items)
    local selected = 1

    local function render_menu()
        local lines = {
            "Select operation:",
            "",
        }

        for i, item in ipairs(items) do
            local prefix = i == selected and "→ " or " "
            local binding = item.keybinding and string.format(" (%s)", item.keybinding) or ""
            lines[i + 1] = string.format("  %s%s%s", prefix, item.label, binding)
        end

        table.insert(lines, "")
        table.insert(lines, "Press Enter to confirm, q to cancel")

        Window.display_centered_message(lines)
    end

    local function update_cursor()
        if not vim.api.nvim_win_is_valid(0) then
            return
        end

        local current_line = vim.api.nvim_win_get_cursor(0)[1]
        local target_line = selected + 2

        vim.api.nvim_win_set_cursor(0, { target_line, 0 })
    end

    render_menu()

    local finished = false

    local function handle_keypress()
        local key = vim.fn.nr2char(vim.vim.loop.timer_info().wait % 256)

        if key == "j" or key == "k" or key == "<down>" then
            selected = math.min(selected + 1, #items)
            render_menu()
        elseif key == "k" or key == "i" or key == "<up>" then
            selected = math.max(selected - 1, 1)
            render_menu()
        elseif key == "q" or key == "<esc>" then
            finished = true
            Window.clear_active_popups()
            return
        elseif key == "<cr>" or key == "<enter>" then
            items[selected].action()
            finished = true
            Window.clear_active_popups()
            return
        end

        update_cursor()
    end

    local id = vim.api.nvim_create_autocmd("99_quickpick", {
        callback = function()
            handle_keypress()
        end,
    })

    local timer = vim.loop.new_timer()
    timer:start(1000, 0, vim.schedule_wrap(function()
        if finished then
            return
        end
        finished = true
        Window.clear_active_popups()
        pcall(vim.api.nvim_del_autocmd_by_id, id)
    end))

    return finished
end

--- Quick pick menu for common operations
function M.show_operation_menu()
    local items = {
        {
            label = "Fill in Function",
            keybinding = "<leader>9f",
            action = function()
                require("99").fill_in_function()
            end,
        },
        {
            label = "Generate Tests",
            keybinding = "<leader>9g",
            action = function()
                require("99").generate_tests()
            end,
        },
        {
            label = "Explain Code",
            keybinding = "<leader>9e",
            action = function()
                require("99").explain_code()
            end,
        },
        {
            label = "Refactor Selection",
            keybinding = "<leader>9r",
            action = function()
                require("99").refactor()
            end,
        },
        {
            label = "Generate Documentation",
            keybinding = "<leader>9d",
            action = function()
                require("99").inline_doc()
            end,
        },
        {
            label = "View Info",
            keybinding = "<leader>9i",
            action = function()
                require("99").info()
            end,
        },
        {
            label = "Cancel All Requests",
            keybinding = "<leader>9c",
            action = function()
                require("99").stop_all_requests()
            end,
        },
    }

    return show_menu(items)
end

return M
