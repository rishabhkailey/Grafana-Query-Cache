local json = require "cjson";
-- resty md5 doesn't work without nginx. (unit test fails due to `luajit: undefined symbol: MD5_Init` error)
-- local resty_md5 = require "resty.md5";
local md5 = require "md5";
local resty_string = require "resty.string";


-- get_datasource_uids
--- @param queries table
--- @return table
local function get_datasource_uids(queries)
  -- to avoid duplicates
  local data_source_already_added = {}
  local data_sources = {}
  for _, query in pairs(queries) do
    if type(query.datasource) ~= "table" and type(query.datasource.uid) ~= "string" and string.len(query.datasource.uid) ~= 0 then
      error("invalid request body, unable to get datasource uid")
      return data_sources
    end
    if not data_source_already_added[query.datasource.uid] then
      table.insert(data_sources, query.datasource.uid)
      data_source_already_added[query.datasource.uid] = true
    end
  end
  return data_sources
end

--- sorted_table_json_encode returns the json encoding of the table with sorted keys
--- @param input_table table
--- @return string
local function sorted_table_json_encode(input_table) 
  
  local sorted_keys = {}
  for key in pairs(input_table) do table.insert(sorted_keys, key) end
  table.sort(sorted_keys)
  
  local output = ""
  output = output .. "{"
  for _, key in pairs(sorted_keys) do
    local encoded_value = ""
    if type(input_table[key]) == "table" then
      encoded_value = sorted_table_json_encode(input_table[key])
    else
      encoded_value = json.encode(input_table[key])
    end

    output = output .. string.format("\"%s\": %s", key, encoded_value)
    if next(sorted_keys, _) ~= nil then
      output = output .. ","
    end
  end
  output = output .. "}"
  return output
end

--- sorted_json_encode returns the json encoding of the queries with sorted query keys
--- this might not be the correct json encoding it might convert array to map. but this will be consistent and thats what we want
--- @param queries table
--- @return string
local function sorted_queries_json_encode(queries)
  local output = ""
  output = output .. "["
  for _, query in pairs(queries) do
    output = output .. sorted_table_json_encode(query)
    if next(queries, _) ~= nil then
      output = output .. ","
    end
  end
  output = output .. "]"
  return output
end

--- @param input string
--- @return string
local function tomd5(input)
  return md5.sumhexa(input)
  -- local md5 = resty_md5:new()
  -- if not md5 then
  --     error("failed to create md5 object")
  --     return ""
  -- end

  -- local ok = md5:update(input)
  -- if not ok then
  --     error("failed to add data to md5")
  --     return ""
  -- end
  -- return resty_string.to_hex(md5:final())
end

-- adds key value pair in the cache key. 
-- format = key1=value1;key2=value2
--- @param cache_key string
--- @param property_name string
--- @param property_value string
--- @return string
local function add_property_in_cache_key(cache_key, property_name, property_value)
  if string.len(cache_key) ~= 0 then
    cache_key = cache_key .. ";"
  end
  cache_key = cache_key .. string.format("%s=%s", property_name, property_value)
  return cache_key
end

--- get_grafana_query_cache_key returns the cache key for the request
--- it consider time (to), time frame (to - from) and queries 
--- @param to string
--- @param from string
--- @param queries table
--- @return string
local function get_grafana_query_cache_key(to, from, queries, time_bucket_length_ms, time_frame_bucket_length_ms, max_data_points_bucket_length)
  local cache_key = ""

  local time_bucket_number = math.ceil(
    tonumber(to) / time_bucket_length_ms
  )
  cache_key = add_property_in_cache_key(cache_key, "time_bucket_number", tostring(time_bucket_number))

  local time_frame_bucket_number = math.ceil(
    (tonumber(to) - tonumber(from)) / time_frame_bucket_length_ms
  )
  cache_key = add_property_in_cache_key(cache_key, "time_frame_bucket_number", tostring(time_frame_bucket_number))

  -- if queries
  for _, query in pairs(queries) do
    if type(query.maxDataPoints) ~= "nil" and tonumber(query.maxDataPoints) ~= "nil" then
      query.maxDataPoints = math.ceil(
        tonumber(query.maxDataPoints) / max_data_points_bucket_length
      )
    end
  end
  local queries_hash = tomd5(sorted_queries_json_encode(queries))
  cache_key = add_property_in_cache_key(cache_key, "queries", queries_hash)

  return cache_key
end

--- get_cache_key_and_datasource_uids returns the cache key and table of datasource uids
--- @param request_body string
--- @param acceptable_time_delta_seconds number
--- @param acceptable_time_range_delta_seconds number
--- @param acceptable_max_points_delta number
--- @return string, table
function get_cache_key_and_datasource_uids(request_body, acceptable_time_delta_seconds, acceptable_time_range_delta_seconds, acceptable_max_points_delta)
  local parsed_request_body = json.decode(request_body)
  if type(parsed_request_body) ~= "table" or tonumber(parsed_request_body.to) == nil or tonumber(parsed_request_body.from) == nil or type(parsed_request_body.queries) ~= "table" then
    error("invalid request body")
    return "", {}
  end
  local cache_key = get_grafana_query_cache_key(
    parsed_request_body.to, 
    parsed_request_body.from,
    parsed_request_body.queries, 
    acceptable_time_delta_seconds * 1000, 
    acceptable_time_range_delta_seconds * 1000, 
    acceptable_max_points_delta
  )
  -- print(#parsed_request_body.queries)
  local data_sources = get_datasource_uids(parsed_request_body.queries)
  return cache_key, data_sources
end

--- check_user_access returns true if the user has access to all the datasources
--- @param grafana_base_url string
--- @param data_sources table
--- @param cookie_header_value string
--- @param authorization_header_value string
--- @return boolean
function check_user_access(grafana_base_url, data_sources, cookie_header_value, authorization_header_value)
  local http = require "resty.http"
  local http_client = http.new()

  if string.len(grafana_base_url) == 0 then
    error("empty grafana base url")
    return false
  end

  for _, data_source in pairs(data_sources) do
    local request_url = grafana_base_url
    if request_url:sub(-1) == "/" then
      request_url = request_url .. "/"
    end
    request_url = request_url .. string.format("/api/datasources/uid/%s/health", data_source)

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
      return false
    end
    if res.status == nil or type(res.status) ~= "number" or res.status ~= 200 then
      return false
    end
  end
  return true
end

-- local requestBody = [[
--   {
--       "from": "1703631956991",
--       "to": "1703653556991",
--       "queries": [
--         {
--           "refId": "FundCategory",
--           "datasource": {
--             "type": "postgres",
--             "uid": "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
--           },
--           "rawSql": "select distinct COALESCE(NULLIF(category, ''), 'unknown') from funds;",
--           "format": "table"
--         },
--         {
--           "refId": "FundCategory",
--           "datasource": {
--             "type": "postgres",
--             "uid": "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
--           },
--           "rawSql": "select distinct COALESCE(NULLIF(category, ''), 'unknown') from funds;",
--           "format": "table"
--         }
--       ]
--     }
-- ]]

-- xpcall(function()
--   local cache_key, data_sources = get_cache_key_and_datasource_uids(requestBody, 123124, 123123, 123)
--   if type(cache_key) ~= "string" or type(data_sources) ~= "table" then
--     error("received nil data from get_cache_key_and_datasource_uids")
--     return
--   end
--   print(cache_key)
--   for _, datasource in pairs(data_sources) do
--     print(datasource)
--   end
-- end, function(err)
--   print("failed", err)
-- end)



return {
  get_cache_key_and_datasource_uids = get_cache_key_and_datasource_uids,
  check_user_access = check_user_access,
  -- returning below functions for unit tests. not sure if this is a good approach
  sorted_queries_json_encode = sorted_queries_json_encode, 
  get_datasource_uids = get_datasource_uids,
  get_grafana_query_cache_key = get_grafana_query_cache_key
}