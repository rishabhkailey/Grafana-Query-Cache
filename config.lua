local lyaml = require "lyaml"
local utils = require "utils"

---@class CacheConfig
---@field enabled boolean
---@field acceptable_time_delta_seconds number
---@field acceptable_time_range_delta_seconds number
---@field acceptable_max_points_delta number
---@field id? string|number
CacheConfig = {}

---@class Config
---@field default CacheConfig
---@field cache_rules table<number, number|boolean|string>: { [K]: V }
Config = {}

---@param self Config
---@param config_file_path string
---@return Config|nil config
---@return string errorMessage
function Config:New(config_file_path)
    local config = {}
    setmetatable(config, self)
    self.__index = self

    local file, err_msg = io.open(config_file_path, "rb")
    if file == nil then
        return nil, "unable to open config file, ERR: " .. err_msg
    end

    local config_data = file:read("a")
    io.close(file)
    local parsed_config, err_msg = parse_and_validate_config(config_data)
    if parsed_config == nil then
        return nil, "config parse and validation failed, ERR: " .. err_msg
    end

    self.default = parsed_config.default
    self.cache_rules = parsed_config.cache_rules
    return config, ""
end

--- returns cache config for the input labels, by default returns default cache config if labels do not match any rule.
--- @param query_labels table
--- @return CacheConfig
function Config:get_cache_config(query_labels)
    if utils.table_length(query_labels) == 0 then
        return self.default
    end
    for _, cache_rule in pairs(self.cache_rules) do
        local all_labels_matched = true
        for key, value in pairs(cache_rule["panel_selector"]) do
            if query_labels[key] ~= value then
                all_labels_matched = false
            end
        end
        if all_labels_matched == true then
            return cache_rule["cache_config"]
        end
    end
    return self.default
end

--- @param config_data string
--- @return Config|nil config
--- @return string errorMessage
function parse_and_validate_config(config_data)
    -- check if it has default
    -- default is optional
    -- either default or cache_rules required
    local config = lyaml.load(config_data)
    if type(config) ~= "table" then
        return nil, "invalid config type " .. type(config)
    end

    if type(config["default"]) ~= "table" and type(config["cache_rules"]) ~= "table" then
        error("either default and cache_rules both are missing or they have invalid types " ..
            type(config["default"]) .. " " .. type(config["cache_rules"]))
    end

    if (type(config["default"])) == "table" then
        local valid, message = validate_cache_config_key(config["default"])
        if valid == false then
            return nil, "invalid default config " .. message
        end
    end

    if type(config["cache_rules"]) == "table" then
        local valid, message = validate_cache_rules_key(config["cache_rules"])
        if valid == false then
            return nil, "invalid default config " .. message
        end
    end

    return {
        default = config["default"],
        cache_rules = config["cache_rules"]
    }, ""
end

--- @param cache_rules table
--- @return boolean valid
--- @return string errorMessage
function validate_cache_rules_key(cache_rules)
    for index, cache_config in pairs(cache_rules) do
        local is_valid, message = utils.check_table_type(cache_config, {
            { key = "panel_selector", type = "table" },
            { key = "cache_config",   type = "table" },
        })
        if is_valid == false then
            return false, string.format("%d[st/nd/th] entry in cache_config invalid type. message: %s", index, message)
        end

        is_valid, message = validate_cache_config_key(cache_config["cache_config"])
        if is_valid == false then
            return false,
                string.format("%d[st/nd/th] entry in cache_rules, invalid cache_config type. message: %s", index, message)
        end

        is_valid, message = validate_panel_selector_key(cache_config["panel_selector"])
        if is_valid == false then
            return false,
                string.format("%d[st/nd/th] entry in cache_rules invalid panel_selector type. message: %s", index,
                    message)
        end
    end
    return true, ""
end

--- @param panel_selector table
--- @return boolean valid
--- @return string errorMessage
function validate_panel_selector_key(panel_selector)
    if type(panel_selector) ~= "table" then
        return false, string.format("expected table got %s", type(panel_selector))
    end
    for key, value in pairs(panel_selector) do
        if type(key) ~= "string" or type(value) ~= "string" then
            return false, string.format("invalid key or value type, (key, value) = (%s, %s)", type(key), type(value))
        end
    end
    return true, ""
end

--- @param config CacheConfig
--- @return boolean valid
--- @return string errorMessage
function validate_cache_config_key(config)
    return utils.check_table_type(
        config, {
            { key = "enabled",                             type = "boolean" },
            { key = "acceptable_time_delta_seconds",       type = "number" },
            { key = "acceptable_time_range_delta_seconds", type = "number" },
            { key = "acceptable_max_points_delta",         type = "number" },
            { key = "id",                                  type = "number|string", required = false },
        })
end

---in context of nginx, this will be loaded only once during the first require
---@type Config|nil
GloablConfig = nil

---loads the input config file in memory 
---@param config_file_path string
---@return string|nil errorMessage
function load_config(config_file_path)
    local config, errorMessage = Config:New(config_file_path)
    if config == nil then
        return "unable to load config file " .. errorMessage
    end
    GloablConfig = config
    return nil
end

---@return Config|nil
function get_config()
    return GloablConfig
end

return {
    config = GloablConfig,
    get_config = get_config,
    load_config = load_config
}
