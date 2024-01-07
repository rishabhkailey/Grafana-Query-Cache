local requestBody = [[
  {
      "from": "1703631956991",
      "to": "1703653556991",
      "queries": [
        {
          "refId": "FundCategory",
          "datasource": {
            "type": "postgres",
            "uid": "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
          },
          "rawSql": "select distinct COALESCE(NULLIF(category, ''), 'unknown') from funds;",
          "format": "table"
        },
        {
          "refId": "FundCategory",
          "datasource": {
            "type": "postgres",
            "uid": "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
          },
          "rawSql": "select distinct COALESCE(NULLIF(category, ''), 'unknown') from funds;",
          "format": "table"
        }
      ]
    }
]]
local json = require "cjson";
local resty_md5 = require "resty.md5";
local resty_string = require "resty.string";


-- luarocks install lua-resty-http
-- 30 mins
local time_bucket_length_ms = 30 * 60 * 1000;
-- 10 mins
local time_frame_bucket_length_ms = 10 * 60 * 1000;


local function get_datasource_uids(queries)
  -- to avoid duplicates
  local data_source_already_added = {}
  local data_sources = {}
  for _, query in pairs(queries) do
    if type(query.datasource) ~= "table" and type(query.datasource.uid) ~= "string" and string.len(query.datasource.uid) ~= 0 then
      error("invalid request body, unable to get datasource uid")
      return
    end
    if not data_source_already_added[query.datasource.uid] then
      table.insert(data_sources, query.datasource.uid)
      data_source_already_added[query.datasource.uid] = true
    end
  end
  return data_sources
end

local function tomd5(input)
  -- -- todo remove this
  -- return input
  local md5 = resty_md5:new()
    if not md5 then
        error("failed to create md5 object")
        return
    end

    local ok = md5:update(input)
    if not ok then
        error("failed to add data to md5")
        return
    end
    return resty_string.to_hex(md5:final())
end

-- cache_key, property_name and property_value should be strings
-- returns the new cache key after adding the mentioned property
local function add_property_in_cache_key(cache_key, property_name, property_value)
  if string.len(cache_key) ~= 0 then
    cache_key = cache_key .. ";"
  end
  cache_key = cache_key .. string.format("%s=%s", property_name, property_value)
  return cache_key
end

local function get_grafana_query_cache_key(to, from, queries)
  local cache_key = ""

  local time_bucket_number = math.floor(
    tonumber(to) / time_bucket_length_ms
  )
  cache_key = add_property_in_cache_key(cache_key, "time_bucket_number", tostring(time_bucket_number))

  local time_frame_bucket_number = math.floor(
    (tonumber(to) - tonumber(from)) / time_frame_bucket_length_ms
  )
  cache_key = add_property_in_cache_key(cache_key, "time_frame_bucket_number", tostring(time_frame_bucket_number))

  local queries = tomd5(json.encode(queries))
  cache_key = add_property_in_cache_key(cache_key, "queries", queries)

  return cache_key
end


function get_cache_key_and_datasource_uids(request_body)
  local parsed_request_body = json.decode(request_body)
  if type(parsed_request_body) ~= "table" or tonumber(parsed_request_body.to) == nil or tonumber(parsed_request_body.from) == nil or type(parsed_request_body.queries) ~= "table" then
    return error("invalid request body")
  end
  local cache_key = get_grafana_query_cache_key(parsed_request_body.to, parsed_request_body.from,
    parsed_request_body.queries)
  -- print(#parsed_request_body.queries)
  local data_sources = get_datasource_uids(parsed_request_body.queries)
  return cache_key, data_sources
end

--- check_user_access returns true if the user has access to all the datasources
--- @param grafana_base_url string
--- @param data_sources table
--- @param cookie_header_value string
--- @param authorization_header_value string
---@return boolean
function check_user_access(grafana_base_url, data_sources, cookie_header_value, authorization_header_value)
  local http = require "resty.http"
  local http_client = http.new()

  if string.len(grafana_base_url) == 0 then
    error("")
    return false
  end

  for _, data_source in pairs(data_sources) do
    local request_url = grafana_base_url
    if request_url:sub(-1) == "/" then
      request_url = request_url .. "/"
    end
    request_url = request_url .. string.format("/api/datasources/uid/%s/health", data_source)
    ngx.log(ngx.STDERR, "auth_request url", request_url)
    ngx.log(ngx.STDERR, "auth_request authorization_header", authorization_header_value)

    local request_headeres = {}
    if string.len(cookie_header_value) ~= 0 then
      request_headeres["Cookie"] = cookie_header_value
    end
    if string.len(authorization_header_value) ~= 0 then
      request_headeres["Authorization"] = authorization_header_value
    end

    local res, err = http_client:request_uri(request_url, {
      method = "GET",
      headers = request_headeres
    })
    if err ~= nil or res == nil then
      ngx.log(ngx.STDERR, err, res)
      return false
    end
    ngx.log(ngx.STDERR, "auth_requst response status", res.status)
    if res.status == nil or type(res.status) ~= "number" or res.status ~= 200 then
      return false
    end
  end
  return true
end

xpcall(function()
  local cache_key, data_sources = get_cache_key_and_datasource_uids(requestBody)
  if type(cache_key) ~= "string" or type(data_sources) ~= "table" then
    error("received nil data from get_cache_key_and_datasource_uids")
    return
  end
  print(cache_key)
  for _, datasource in pairs(data_sources) do
    print(datasource)
  end
end, function(err)
  print("failed", err)
end)



return {
  get_cache_key_and_datasource_uids = get_cache_key_and_datasource_uids,
  check_user_access = check_user_access
}
