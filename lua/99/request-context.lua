local Logger = require("99.logger.logger")
local utils = require("99.utils")
local random_file = utils.random_file
local lsp_util = require("99.lsp")
local lsp_context = require("99.lsp.context")

--- @class _99.RequestContext
--- @field md_file_names string[]
--- @field ai_context string[]
--- @field model string
--- @field tmp_file string
--- @field full_path string
--- @field buffer number
--- @field file_type string
--- @field marks table<string, _99.Mark>
--- @field logger _99.Logger
--- @field xid number
--- @field range _99.Range?
--- @field _99 _99.State
local RequestContext = {}
RequestContext.__index = RequestContext

--- @param _99 _99.State
--- @param xid number
--- @return _99.RequestContext
function RequestContext.from_current_buffer(_99, xid)
    local buffer = vim.api.nvim_get_current_buf()
    local full_path = vim.api.nvim_buf_get_name(buffer)
    local file_type = vim.bo[buffer].ft

    local mds = {}
    for _, md in ipairs(_99.md_files) do
        table.insert(mds, md)
    end

    return setmetatable({
        _99 = _99,
        md_file_names = mds,
        ai_context = {},
        tmp_file = random_file(),
        buffer = buffer,
        full_path = full_path,
        file_type = file_type,
        logger = Logger:set_id(xid),
        xid = xid,
        model = _99.model,
        marks = {},
    }, RequestContext)
end

--- @param md_file_name string
--- @return self
function RequestContext:add_md_file_name(md_file_name)
    table.insert(self.md_file_names, md_file_name)
    return self
end

--- AGENT.md file cache with modification time tracking
--- @type table<string, {content: string, mtime: number}>
local MD_FILE_CACHE = {}

--- Check if AGENT.md file has been modified since last read
--- @param file_path string
--- @param cached_content table?
--- @return boolean needs_reload
local function needs_md_reload(file_path, cached_content)
    if not cached_content then
        return true
    end

    local ok, stat = pcall(vim.loop.fs_stat, file_path)
    if not ok or not stat then
        return false
    end

    return stat.mtime.sec > cached_content.mtime
end

function RequestContext:_read_md_files()
    local cwd = vim.uv.cwd()
    local dir = vim.fn.fnamemodify(self.full_path, ":h")

    while dir:find(cwd, 1, true) == 1 do
        for _, md_file_name in ipairs(self.md_file_names) do
            local md_path = dir .. "/" .. md_file_name
            local cached = MD_FILE_CACHE[md_path]

            if not cached or needs_md_reload(md_path, cached) then
                local file = io.open(md_path, "r")
                if file then
                    local content = file:read("*a")
                    file:close()
                    local ok, stat = pcall(vim.loop.fs_stat, md_path)
                    local mtime = ok and stat and stat.mtime.sec or 0

                    MD_FILE_CACHE[md_path] = {
                        content = content,
                        mtime = mtime,
                    }

                    self.logger:info(
                        "Context#adding md file to the context",
                        "md_path",
                        md_path
                    )
                    table.insert(self.ai_context, content)
                end
            else
                if cached then
                    table.insert(self.ai_context, cached.content)
                end
            end
        end

        if dir == cwd then
            break
        end

        dir = vim.fn.fnamemodify(dir, ":h")
    end
end

--- @return string[]
function RequestContext:content()
    return self.ai_context
end

--- @return self
function RequestContext:finalize()
    self:_read_md_files()
    if self.range then
        table.insert(self.ai_context, self._99.prompts.get_file_location(self))
        table.insert(
            self.ai_context,
            self._99.prompts.get_range_text(self.range)
        )
    end
    table.insert(
        self.ai_context,
        self._99.prompts.tmp_file_location(self.tmp_file)
    )

    if lsp_util.is_lsp_available(self.buffer) and self.range then
        local lsp_ctx = lsp_context.build_lsp_context(self, self.range, true)
        for _, line in ipairs(lsp_ctx) do
            table.insert(self.ai_context, line)
        end

        self.logger:debug("LSP context added", "lines", #lsp_ctx)
    end

    return self
end

function RequestContext:clear_marks()
    for _, mark in pairs(self.marks) do
        mark:delete()
    end
end

return RequestContext
