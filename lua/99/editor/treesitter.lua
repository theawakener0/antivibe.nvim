local geo = require("99.geo")
local Logger = require("99.logger.logger")
local Range = geo.Range

local M = {}

local function_query = "99-function"
local fn_call_query = "99-fn-call"

--- Query cache with language+query_name key
--- @type table<string, vim.treesitter.Query>
local QUERY_CACHE = {}

--- Cache statistics
--- @type table<string, {hits: number, misses: number}>
local CACHE_STATS = {}

--- @param lang string
--- @param query_name string
--- @return string cache_key
local function get_cache_key(lang, query_name)
    return lang .. "::" .. query_name
end

--- Get or create cached query
--- @param lang string
--- @param query_name string
--- @return vim.treesitter.Query?
function M.get_cached_query(lang, query_name)
    local key = get_cache_key(lang, query_name)

    if QUERY_CACHE[key] then
        CACHE_STATS[key] = CACHE_STATS[key] or { hits = 0, misses = 0 }
        CACHE_STATS[key].hits = CACHE_STATS[key].hits + 1
        Logger:debug("cache hit", "lang", lang, "query", query_name)
        return QUERY_CACHE[key]
    end

    CACHE_STATS[key] = CACHE_STATS[key] or { hits = 0, misses = 0 }
    CACHE_STATS[key].misses = CACHE_STATS[key].misses + 1
    Logger:debug("cache miss", "lang", lang, "query", query_name)

    local ok, query = pcall(vim.treesitter.query.get, lang, query_name)
    if not ok or query == nil then
        Logger:warn(
            "unable to cache query",
            "lang",
            lang,
            "query",
            query_name
        )
        return nil
    end

    QUERY_CACHE[key] = query
    return query
end

--- Clear all query caches
function M.clear_query_cache()
    QUERY_CACHE = {}
    CACHE_STATS = {}
    Logger:debug("query cache cleared")
end

--- Get cache statistics
--- @return table
function M.get_cache_stats()
    return vim.deepcopy(CACHE_STATS)
end

--- @param buffer number
---@param lang string
local function tree_root(buffer, lang)
    -- Load the parser and the query.
    local ok, parser = pcall(vim.treesitter.get_parser, buffer, lang)
    if not ok then
        return nil
    end

    local tree = parser:parse()[1]
    return tree:root()
end

--- @param context _99.RequestContext
--- @param cursor _99.Point
--- @return _99.treesitter.TSNode | nil
function M.fn_call(context, cursor)
    local buffer = context.buffer
    local lang = context.file_type
    local logger = context.logger:set_area("treesitter")
    local root = tree_root(buffer, lang)
    if not root then
        Logger:error(
            "unable to find treeroot, this should never happen",
            "buffer",
            buffer,
            "lang",
            lang
        )
        return nil
    end

    local query = M.get_cached_query(lang, fn_call_query)
    if not query then
        Logger:error(
            "unable to get the fn_call_query",
            "lang",
            lang,
            "buffer",
            buffer,
            "ok",
            type(query)
        )
        return nil
    end

    local found = nil
    for _, match, _ in query:iter_matches(root, buffer, 0, -1, { all = true }) do
        for _, nodes in pairs(match) do
            for _, node in ipairs(nodes) do
                local range = Range:from_ts_node(node, buffer)
                if range:contains(cursor) then
                    found = node
                    goto end_of_loops
                end
            end
        end
    end
    ::end_of_loops::

    logger:debug("treesitter#fn_call", "found", found ~= nil)

    return found
end

--- @class _99.treesitter.Function
--- @field function_range _99.Range
--- @field function_node _99.treesitter.TSNode
--- @field body_range _99.Range
--- @field body_node _99.treesitter.TSNode
local Function = {}
Function.__index = Function

--- uses the function_node to replace the text within vim using nvim_buf_set_text
--- to replace at the exact function begin / end
--- @param replace_with string[]
function Function:replace_text(replace_with)
    self.function_range:replace_text(replace_with)
end

--- @param ts_node _99.treesitter.TSNode
---@param cursor _99.Point
---@param context _99.RequestContext
---@return _99.treesitter.Function
function Function.from_ts_node(ts_node, cursor, context)
    local ok, query =
        pcall(vim.treesitter.query.get, context.file_type, function_query)
    local logger = context.logger:set_area("Function")
    if not ok or query == nil then
        logger:fatal("not query or not ok")
        error("failed")
    end

    local func = {}
    for id, node, _ in
        query:iter_captures(ts_node, context.buffer, 0, -1, { all = true })
    do
        local range = Range:from_ts_node(node, context.buffer)
        local name = query.captures[id]
        if range:contains(cursor) then
            if name == "context.function" then
                func.function_node = node
                func.function_range = range
            elseif name == "context.body" then
                func.body_node = node
                func.body_range = range
            end
        end
    end

    --- NOTE: not all functions have bodies... (lua: local function foo() end)
    logger:assert(func.function_node ~= nil, "function_node not found")
    logger:assert(func.function_range ~= nil, "function_range not found")

    return setmetatable(func, Function)
end

--- @param context _99.RequestContext
--- @param cursor _99.Point
--- @return _99.treesitter.Function?
function M.containing_function(context, cursor)
    local buffer = context.buffer
    local lang = context.file_type
    local logger = context and context.logger:set_area("treesitter") or Logger

    local root = tree_root(buffer, lang)
    if not root then
        logger:debug("LSP: could not find tree root")
        return nil
    end

    local query = M.get_cached_query(lang, function_query)
    if not query then
        logger:debug(
            "LSP: unable to get query",
            "query",
            vim.inspect(query),
            "lang",
            lang
        )
        return nil
    end

    --- @type _99.Range
    local found_range = nil
    --- @type _99.treesitter.TSNode
    local found_node = nil
    for id, node, _ in query:iter_captures(root, buffer, 0, -1, { all = true }) do
        local range = Range:from_ts_node(node, buffer)
        local name = query.captures[id]
        if name == "context.function" and range:contains(cursor) then
            if not found_range then
                found_range = range
                found_node = node
            elseif found_range:area() > range:area() then
                found_range = range
                found_node = node
            end
        end
    end

    logger:debug(
        "treesitter#containing_function",
        "found_range",
        found_range and found_range:to_string() or "found_range is nil"
    )

    if not found_range then
        return nil
    end
    logger:assert(
        found_node,
        "INVARIANT: found_range is not nil but found node is"
    )

    local ok, query2 = pcall(vim.treesitter.query.get, lang, function_query)
    if not ok or query2 == nil then
        logger:fatal("INVARIANT: found_range ", "range", found_range:to_text())
        return
    end

    --- TODO: we need some language specific things here.
    --- that is because comments above the function needs to considered
    return Function.from_ts_node(found_node, cursor, context)
end

return M
