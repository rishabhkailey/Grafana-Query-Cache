--- usage = check_table_type(table, { {key = "name", type = "string"}, {key = "age", type = "number"},  })
--- @param input_table table
--- @param key_types table
--- @return boolean
--- @return string
function check_table_type(input_table, key_types)
    for _, key_type in pairs(key_types) do
        local table_key = key_type["key"]
        local expected_type = key_type["type"]
        if type(key_types) ~= "table" and
            type(table_key) ~= "string" and
            type(expected_type) ~= "string"
        then
            return false, "invalid key_types argument"
        end
        local actual_type = type(input_table[table_key])

        if key_type["required"] == false and actual_type == "nil" then
            goto continue
        end
        if check_type(actual_type, expected_type) == false then
            return false, string.format("key = \"%s\", expected type = %s, got = %s", table_key, expected_type, actual_type)            
        end
        -- if type(input_table[table_key]) ~= expected_type then
        --     return false, string.format("key = \"%s\", expected type = %s, got = %s", table_key, expected_type, type(input_table[table_key]))
        -- end
        ::continue::
    end
    return true, ""
end

---@usage check_type(type(variable), "number|string")
---@param actual string
---@param expected string
---@return boolean
function check_type(actual, expected)
    for expected_type in string.gmatch(expected, "[^|]+") do
        if actual == expected_type then
            return true
        end
    end
    return false
end

---returns number of keys in a table
---@param t table
---@return number
function table_length(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
  end

return {
    check_table_type = check_table_type,
    table_length = table_length,
    dump = dump,
    check_type = check_type
}