function update_cache_key_prefix() 
    local shared_dict = ngx.shared.shared
    local timestamp = os.time(os.date("!*t"))
    local success, err = shared_dict:set("cache_prefix", timestamp)
    if success ~= true then
        ngx.log(ngx.STDERR, "failed to set cache_key_prefix" .. err)
    end
end

return {
    update_cache_key_prefix = update_cache_key_prefix,
}