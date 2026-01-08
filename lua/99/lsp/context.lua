local Logger = require("99.logger.logger")
local lsp_util = require("99.lsp")
local geo = require("99.geo")
local Point = geo.Point

local M = {}

--- @class _99.lsp.FunctionSignature
--- @field name string
--- @field parameters table[]
--- @field return_type string?
--- @field documentation string?

--- @class _99.lsp.SymbolInfo
--- @field name string
--- @field kind string
--- @field detail string?
--- @field documentation string?
--- @field range table?

--- Get function signature with type information
--- @param context _99.RequestContext
--- @param range _99.Range
--- @return _99.lsp.FunctionSignature?
function M.get_function_signature(context, range)
    local cursor = range.start
    local signature_help, err = lsp_util.get_signature_help(
        context.buffer,
        cursor:to_ts()
    )

    if err or not signature_help or #signature_help == 0 then
        Logger:debug("get_function_signature", "error", err, "signature", signature_help)
        return nil
    end

    local sig = signature_help[1]
    local signature = {
        name = sig.label,
        parameters = {},
        return_type = nil,
        documentation = nil,
    }

    if sig.documentation then
        signature.documentation = sig.documentation.value or sig.documentation
    end

    if sig.parameters then
        for _, param in ipairs(sig.parameters) do
            table.insert(signature.parameters, {
                label = param.label,
                documentation = param.documentation,
            })
        end
    end

    return signature
end

--- Get type information for a symbol
--- @param context _99.RequestContext
--- @param point _99.Point
--- @return string? type_info
function M.get_type_at_position(context, point)
    local type_info, err = lsp_util.get_type_at_cursor(
        context.buffer,
        point:to_ts()
    )

    if err or not type_info then
        Logger:debug("get_type_at_position", "error", err)
        return nil
    end

    return type_info
end

--- Get symbol information at position
--- @param context _99.RequestContext
--- @param point _99.Point
--- @return _99.lsp.SymbolInfo?
function M.get_symbol_info(context, point)
    local definitions, err = lsp_util.get_definition(
        context.buffer,
        point:to_ts()
    )

    if err or not definitions or #definitions == 0 then
        Logger:debug("get_symbol_info", "error", err)
        return nil
    end

    local def = definitions[1]
    return {
        name = def.name or "unknown",
        kind = def.kind or "unknown",
        detail = def.detail,
        documentation = def.documentation,
        range = def.range,
    }
end

--- Get surrounding symbols context
--- @param context _99.RequestContext
--- @param range _99.Range
--- @return _99.lsp.SymbolInfo[]
function M.get_surrounding_context(context, range)
    local symbols, err = lsp_util.get_document_symbols(context.buffer)

    if err or not symbols then
        Logger:debug("get_surrounding_context", "error", err)
        return {}
    end

    local surrounding = {}
    local start_pos = range.start:to_lsp()
    local end_pos = range.end_:to_lsp()

    for _, symbol in ipairs(symbols) do
        if symbol.range then
            local sym_start = symbol.range.start
            local sym_end = symbol.range["end"]

            local is_before = sym_end.line < start_pos.line or
                (sym_end.line == start_pos.line and sym_end.character <= start_pos.character)

            local is_after = sym_start.line > end_pos.line or
                (sym_start.line == end_pos.line and sym_start.character >= end_pos.character)

            if is_before or is_after then
                table.insert(surrounding, {
                    name = symbol.name,
                    kind = symbol.kind,
                    detail = symbol.detail,
                    range = symbol.range,
                })
            end
        end
    end

    return surrounding
end

--- Get variable types in range
--- @param context _99.RequestContext
--- @param range _99.Range
--- @return table<string, string> var_types
function M.get_variable_types_in_range(context, range)
    local diagnostics = lsp_util.get_diagnostics(context.buffer)
    local var_types = {}

    for _, diag in ipairs(diagnostics) do
        local diag_range = diag.range
        if diag_range then
            local start = range.start:to_lsp()
            local end_pos = range.end_:to_lsp()

            local within_range = diag_range.start.line >= start.line and
                diag_range["end"].line <= end_pos.line

            if within_range and diag.message then
                local var, type_info = diag.message:match("^(.+) has type (.+)$")
                if var and type_info then
                    var_types[var] = type_info
                end
            end
        end
    end

    return var_types
end

--- Build context string from LSP information
--- @param context _99.RequestContext
--- @param range _99.Range
--- @param include_diagnostics boolean?
--- @return string[] context_lines
function M.build_lsp_context(context, range, include_diagnostics)
    local context_lines = {}

    local function_signature = M.get_function_signature(context, range)
    if function_signature then
        table.insert(context_lines, "-- Function Signature --")
        table.insert(context_lines, string.format("  Name: %s", function_signature.name))

        if #function_signature.parameters > 0 then
            table.insert(context_lines, "  Parameters:")
            for _, param in ipairs(function_signature.parameters) do
                table.insert(context_lines, string.format("    - %s", param.label))
            end
        end

        if function_signature.documentation then
            table.insert(context_lines, "  Documentation: " .. function_signature.documentation)
        end
        table.insert(context_lines, "")
    end

    local surrounding = M.get_surrounding_context(context, range)
    if #surrounding > 0 then
        table.insert(context_lines, "-- Surrounding Symbols --")
        for _, symbol in ipairs(surrounding) do
            table.insert(context_lines, string.format(
                "  %s (%s)",
                symbol.name,
                symbol.kind
            ))
        end
        table.insert(context_lines, "")
    end

    if include_diagnostics then
        local diagnostics = lsp_util.get_diagnostics(context.buffer)
        local relevant_diags = {}

        for _, diag in ipairs(diagnostics) do
            if diag.range then
                local start = range.start:to_lsp()
                local end_pos = range.end_:to_lsp()

                local within_range = diag.range.start.line >= start.line and
                    diag.range["end"].line <= end_pos.line

                if within_range then
                    table.insert(relevant_diags, diag)
                end
            end
        end

        if #relevant_diags > 0 then
            table.insert(context_lines, "-- Diagnostics --")
            for _, diag in ipairs(relevant_diags) do
                table.insert(context_lines, string.format(
                    "  %s: %s",
                    diag.severity or "warning",
                    diag.message
                ))
            end
            table.insert(context_lines, "")
        end
    end

    return context_lines
end

return M
