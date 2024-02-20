local grafana_request = require "grafana_request"
local json = require "cjson";
local config = require "config";

--- set generated_cache_key and cache_access_denied nginx variables
function set_cache_key()
    local body_data = get_body_data()
    if not body_data then
        -- no caching
        ngx.var.generated_cache_key = ""
        return
    end

    local parsed_request_body = json.decode(body_data)
    if type(parsed_request_body) ~= "table" or tonumber(parsed_request_body.to) == nil or tonumber(parsed_request_body.from) == nil or type(parsed_request_body.queries) ~= "table" then
      error("invalid request body")
    end

    local cfg = config.get_config()
    if cfg == nil then
        error("unable to get the global config")
    end
    local request_cache_config = grafana_request.get_queries_config(cfg, parsed_request_body.queries)
    if request_cache_config.enabled == false then
        return
    end
    if tostring(request_cache_config.id) ~= nil then
        ngx.var.cache_config_id = tostring(request_cache_config.id)
    end

    local generated_cache_key, datasource_uids, errorMessage = grafana_request.get_cache_key_and_datasource_uids(
        parsed_request_body,
        request_cache_config.acceptable_time_delta_seconds, 
        request_cache_config.acceptable_time_range_delta_seconds, 
        request_cache_config.acceptable_max_points_delta
    )
    if type(generated_cache_key) ~= "string" or string.len(generated_cache_key) == 0 or type(datasource_uids) ~= "table" or #datasource_uids == 0 then
        ngx.log(ngx.DEBUG, type(generated_cache_key), type(datasource_uids))
        error("empty cache key or empty datasource_uids table" .. errorMessage)
        return
    end

    local cookie_header = ngx.req.get_headers()["Cookie"]

    if not cookie_header then
        cookie_header = ""
    end
    local authorization_header = ngx.req.get_headers()["Authorization"]
    if not authorization_header then
        authorization_header = ""
    end

    local user_access, errorMessage = grafana_request.check_user_access(
        string.format("%s://%s", ngx.var.grafana_scheme, ngx.var.grafana_host), 
        datasource_uids, 
        cookie_header,
        authorization_header
    )
    if user_access == true then
        ngx.var.cache_access_denied = 0
    end
    local shared_dict = ngx.shared.shared
    local cache_key_prefix = shared_dict:get("cache_prefix")
    if tostring(cache_key_prefix) == nil then
        cache_key_prefix = ""
    end

    ngx.var.generated_cache_key = tostring(cache_key_prefix) .. "_" .. generated_cache_key
    ngx.log(ngx.DEBUG, "cache key: ", ngx.var.generated_cache_key)
end

function error_handler(err) 
    ngx.log(ngx.STDERR, "failed to generate cache key: ", err)
    ngx.var.generated_cache_key = ""
    ngx.var.cache_access_denied = 1
end

---@return string|nil body_data
function get_body_data()
    ngx.req.read_body()  
    ---@type string|nil
    local body_data = ngx.req.get_body_data()
    if not body_data then
        -- try reading body file
        local body_file = ngx.req.get_body_file()
        if not body_file then
            ngx.log(ngx.STDERR, "request doesn't have body, tried both body_data and body_file")
            return nil
        end
        if body_file then
            -- we are not checking the body size before reading it into memory
            -- we should set max request size in nginx config
            -- todo document above somewhere
            local file = io.open(body_file, "rb")
            if not file then
                ngx.log(ngx.STDERR, "unable to open request file")
                return nil
            end
            body_data = file:read("*all")
        else
            ngx.log(ngx.STDERR, "unable to get request body")
            return nil
        end
    end
    return body_data
end

xpcall(set_cache_key, error_handler)
