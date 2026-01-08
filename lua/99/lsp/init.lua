local Logger = require("99.logger.logger")
local Error = require("99.error")

local M = {}

--- Get LSP client for current buffer
--- @param buf number?
--- @return vim.lsp.Client?
local function get_lsp_client(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients({ bufnr = buf })

    if #clients == 0 then
        return nil
    end

    return clients[1]
end

--- Get LSP client with timeout protection
--- @param buf number?
--- @param timeout_ms number?
--- @return boolean success
--- @return vim.lsp.Client? client
--- @return string? error_msg
local function get_lsp_client_with_timeout(buf, timeout_ms)
    timeout_ms = timeout_ms or 5000
    local client = get_lsp_client(buf)

    if not client then
        return false, nil, "No LSP client attached to buffer"
    end

    if not client.is_initialized() then
        return false, nil, "LSP client is not initialized"
    end

    return true, client, nil
end

--- Get type information at cursor position (hover)
--- @param buf number?
--- @param row number?
--- @param col number?
--- @param timeout_ms number?
--- @return string? type_info
--- @return string? error_msg
function M.get_type_at_cursor(buf, row, col, timeout_ms)
    local success, client, err = get_lsp_client_with_timeout(buf, timeout_ms)
    if not success then
        return nil, err
    end

    buf = buf or vim.api.nvim_get_current_buf()
    local params = vim.lsp.util.make_position_params({
        bufnr = buf,
        row = row or (vim.api.nvim_win_get_cursor(0)[1] - 1),
        col = col or vim.api.nvim_win_get_cursor(0)[2],
    })

    local results, err = client.request_sync("textDocument/hover", params, timeout_ms or 5000)
    if not results or err then
        return nil, err or "No hover information available"
    end

    local result = results.result
    if not result then
        return nil, "No type information available"
    end

    if type(result.contents) == "table" then
        return vim.lsp.util.convert_input_to_markdown_lines(result.contents, {})
    else
        return result.contents.value or result.contents
    end
end

--- Get definition at cursor position
--- @param buf number?
--- @param row number?
--- @param col number?
--- @param timeout_ms number?
--- @return table[]? definitions
--- @return string? error_msg
function M.get_definition(buf, row, col, timeout_ms)
    local success, client, err = get_lsp_client_with_timeout(buf, timeout_ms)
    if not success then
        return nil, err
    end

    buf = buf or vim.api.nvim_get_current_buf()
    local params = vim.lsp.util.make_position_params({
        bufnr = buf,
        row = row or (vim.api.nvim_win_get_cursor(0)[1] - 1),
        col = col or vim.api.nvim_win_get_cursor(0)[2],
    })

    local results, err = client.request_sync("textDocument/definition", params, timeout_ms or 5000)
    if not results or err then
        return nil, err or "No definition available"
    end

    return results.result, nil
end

--- Get references to symbol at cursor
--- @param buf number?
--- @param row number?
--- @param col number?
--- @param timeout_ms number?
--- @return table[]? references
--- @return string? error_msg
function M.get_references(buf, row, col, timeout_ms)
    local success, client, err = get_lsp_client_with_timeout(buf, timeout_ms)
    if not success then
        return nil, err
    end

    buf = buf or vim.api.nvim_get_current_buf()
    local params = vim.lsp.util.make_position_params({
        bufnr = buf,
        row = row or (vim.api.nvim_win_get_cursor(0)[1] - 1),
        col = col or vim.api.nvim_win_get_cursor(0)[2],
    })

    local results, err = client.request_sync("textDocument/references", params, timeout_ms or 5000)
    if not results or err then
        return nil, err or "No references available"
    end

    return results.result, nil
end

--- Get all document symbols
--- @param buf number?
--- @param timeout_ms number?
--- @return table[]? symbols
--- @return string? error_msg
function M.get_document_symbols(buf, timeout_ms)
    local success, client, err = get_lsp_client_with_timeout(buf, timeout_ms)
    if not success then
        return nil, err
    end

    buf = buf or vim.api.nvim_get_current_buf()
    local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }

    local results, err = client.request_sync("textDocument/documentSymbol", params, timeout_ms or 5000)
    if not results or err then
        return nil, err or "No document symbols available"
    end

    return results.result, nil
end

--- Get diagnostics for buffer
--- @param buf number?
--- @return table[]? diagnostics
function M.get_diagnostics(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local diagnostics = vim.diagnostic.get(buf)

    return diagnostics
end

--- Get function signature at cursor
--- @param buf number?
--- @param row number?
--- @param col number?
--- @param timeout_ms number?
--- @return table? signature_help
--- @return string? error_msg
function M.get_signature_help(buf, row, col, timeout_ms)
    local success, client, err = get_lsp_client_with_timeout(buf, timeout_ms)
    if not success then
        return nil, err
    end

    buf = buf or vim.api.nvim_get_current_buf()
    local params = vim.lsp.util.make_position_params({
        bufnr = buf,
        row = row or (vim.api.nvim_win_get_cursor(0)[1] - 1),
        col = col or vim.api.nvim_win_get_cursor(0)[2],
    })

    local results, err = client.request_sync("textDocument/signatureHelp", params, timeout_ms or 5000)
    if not results or err then
        return nil, err or "No signature help available"
    end

    return results.result, nil
end

--- Check if LSP is available for buffer
--- @param buf number?
--- @return boolean
function M.is_lsp_available(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local client = get_lsp_client(buf)
    return client ~= nil and client.is_initialized()
end

--- Get all LSP clients for buffer
--- @param buf number?
--- @return vim.lsp.Client[]
function M.get_lsp_clients(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    return vim.lsp.get_clients({ bufnr = buf })
end

--- Get LSP capabilities
--- @param buf number?
--- @return table?
function M.get_capabilities(buf)
    local client = get_lsp_client(buf)
    if not client then
        return nil
    end

    return client.server_capabilities
end

return M
