---@param context _99.RequestContext
---@param clean_up_fn fun(): nil
---@param operation_type string?
---@return fun(): nil
return function(context, clean_up_fn, operation_type)
    local called = false
    local request_id = -1
    local function clean_up()
        if called then
            return
        end

        called = true
        clean_up_fn()
        context._99:remove_request(request_id)
    end
    request_id = context._99:add_request(clean_up, operation_type or "unknown")

    return clean_up
end
