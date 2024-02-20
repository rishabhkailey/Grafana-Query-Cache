local json = require "cjson";
local md5 = require "md5";
local utils = require "utils"

-- get_datasource_uids
--- @param queries table
--- @return table|nil uids
--- @return string errorMessage
local function get_datasource_uids(queries)
  -- to avoid duplicates
  local data_source_already_added = {}
  local data_sources = {}
  for _, query in pairs(queries) do
    if type(query.datasource) ~= "table" and type(query.datasource.uid) ~= "string" and string.len(query.datasource.uid) ~= 0 then
      return nil, "invalid request body, unable to get datasource uid"
    end
    if not data_source_already_added[query.datasource.uid] then
      table.insert(data_sources, query.datasource.uid)
      data_source_already_added[query.datasource.uid] = true
    end
  end
  return data_sources, ""
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
local function get_grafana_query_cache_key(to, from, queries, time_bucket_length_ms, time_frame_bucket_length_ms,
                                           max_data_points_bucket_length)
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
--- @param parsed_request_body table
--- @param acceptable_time_delta_seconds number
--- @param acceptable_time_range_delta_seconds number
--- @param acceptable_max_points_delta number
--- @return string cache_key
--- @return table|nil datasource_uids
--- @return string errorMessage
function get_cache_key_and_datasource_uids(parsed_request_body, acceptable_time_delta_seconds,
                                           acceptable_time_range_delta_seconds, acceptable_max_points_delta)
  local cache_key = get_grafana_query_cache_key(
    parsed_request_body.to,
    parsed_request_body.from,
    parsed_request_body.queries,
    acceptable_time_delta_seconds * 1000,
    acceptable_time_range_delta_seconds * 1000,
    acceptable_max_points_delta
  )
  -- print(#parsed_request_body.queries)
  local data_sources, errorMessage = get_datasource_uids(parsed_request_body.queries)
  return cache_key, data_sources, errorMessage
end

--- check_user_access returns true if the user has access to all the datasources
--- @param grafana_base_url string
--- @param data_sources table
--- @param cookie_header_value string
--- @param authorization_header_value string
--- @return boolean user_access
--- @return string errorMessage
function check_user_access(grafana_base_url, data_sources, cookie_header_value, authorization_header_value)
  local http = require "resty.http"
  local http_client = http.new()

  if string.len(grafana_base_url) == 0 then
    return false, "empty grafana base url"
  end

  for _, data_source in pairs(data_sources) do
    local request_url = grafana_base_url
    if request_url:sub(-1) == "/" then
      request_url = request_url .. "/"
    end
    request_url = request_url .. string.format("/api/datasources/uid/%s", data_source)

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
      return false, "got nil response"
    end
    if res.status == nil or type(res.status) ~= "number" or res.status ~= 200 then
      return false, "non 200 status code"
    end
  end
  return true, ""
end

---comment
---@param queries table
---@param config Config
---@return CacheConfig
function get_queries_config(config, queries) 
  local labels = get_queries_labels(queries)
  if labels == nil then
    return config.default
  end
  return config:get_cache_config(labels)
end

POSSIBLE_QUERY_KEYS = {
  "expr", -- prometheus 
  "rawSql", -- sql
  "query", -- influx, mongodb
}
---comment
---@param queries table
---@return table|nil labels returns `nil` if no label found
function get_queries_labels(queries)
  local raw_query = ""
  ---@type nil|table
  local labels = nil
  for _, query in pairs(queries) do
    for _, key in pairs(POSSIBLE_QUERY_KEYS) do
      if type(query[key]) == "string" and string.len(query[key]) > 0 then
        raw_query = query[key]
        break
      end
    end
    if raw_query:len() > 0 then
      labels = get_query_labels(raw_query)
    end
    if labels ~= nil then
      return labels
    end
  end
  return nil
end

---comment
---@param query string
---@return table|nil labels returns `nil` if no label found
function get_query_labels(query)
  local _, comment_sequence_end = query:find("^[^a-zA-Z0-9 \t]+")
  if comment_sequence_end == nil then
    return nil
  end

  local line_end, _ = query:find("\n")
  line_end = line_end or query:len()
  local label_string = query:sub(comment_sequence_end + 1, line_end - 1)

  local labels = {}
  local label_pattern = "%s*[a-zA-Z0-9][a-zA-Z0-9-]+%s*=%s*[a-zA-Z0-9-]+%s*;"

  local label_count = 0
  for label in string.gmatch(label_string, label_pattern) do
    label = label:gsub("[%s;]", "")
    local equal_char_index = string.find(label, "=")
    if equal_char_index ~= nil then
      local key = label:sub(0, equal_char_index - 1)
      local value = label:sub(equal_char_index + 1, label:len())
      labels[key] = value
      label_count = label_count + 1
    end
  end
  if label_count == 0 then
    return nil
  end
  return labels
end

return {
  get_cache_key_and_datasource_uids = get_cache_key_and_datasource_uids,
  check_user_access = check_user_access,
  -- returning below functions for unit tests. not sure if this is a good approach
  sorted_queries_json_encode = sorted_queries_json_encode,
  get_datasource_uids = get_datasource_uids,
  get_grafana_query_cache_key = get_grafana_query_cache_key,
  get_queries_config = get_queries_config,
  get_query_labels = get_query_labels,
  get_queries_labels = get_queries_labels
}
