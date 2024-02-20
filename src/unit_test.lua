local luaunit         = require "luaunit"
local json            = require "cjson";
local grafana_request = require "grafana_request"
local utils           = require "utils"
local config          = require "config"

function test_sorted_queries_json_encode()
    local queries = {
        {
            refId = "2 Days",
            datasource = {
                type = "grafana-postgresql-datasource",
                uid = "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
            },
            rawSql =
            "WITH start_and_end_time AS (\n  SELECT\n    first(time, time) as first_time,\n    last(time, time) as last_time\n  FROM\n    fund_holdings_data\n  WHERE\n    time > now() - INTERVAL '2 days'\n),\nfiltered_holding_ids as (\n  SELECT\n    fund_holdings.id as id\n  FROM\n    fund_holdings\n    JOIN funds ON fund_holdings.fund_id = funds.id\n  WHERE\n    fund_holdings.type IN ('equity')\n    AND funds.category IN ('emerging','long term','fund of fund','liquid','large cap','small cap','unknown','mid cap','multi cap','debt','value','advantage','fixed maturity plan','contra','large & mid cap','opportunities','hybrid fund')\n    AND funds.one_year_cagr > 0\n    AND funds.three_year_cagr > 20\n    AND funds.five_year_cagr > 0\n    AND funds.marked_as_duplicate != 'true'\n),\nfirst_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.first_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n),\nlast_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.last_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n)\nSELECT\n  COALESCE (\n    first_sum.holding_name,\n    last_sum.holding_name,\n    'something went wrong'\n  ) AS \"Holding Name\",\n  (\n    COALESCE (last_sum.value, 0) - COALESCE (first_sum.value, 0)\n  ) AS \"2 Days\"\nFROM\n  first_sum FULL\n  OUTER JOIN last_sum ON first_sum.holding_name = last_sum.holding_name;",
            format = "table",
            datasourceId = 1,
            intervalMs = 60000,
            maxDataPoints = 743
        },
        {
            refId = "7 Days",
            datasource = {
                type = "grafana-postgresql-datasource",
                uid = "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
            },
            rawSql =
            "WITH start_and_end_time AS (\n  SELECT\n    first(time, time) as first_time,\n    last(time, time) as last_time\n  FROM\n    fund_holdings_data\n  WHERE\n    time > now() - INTERVAL '7 days'\n),\nfiltered_holding_ids as (\n  SELECT\n    fund_holdings.id as id\n  FROM\n    fund_holdings\n    JOIN funds ON fund_holdings.fund_id = funds.id\n  WHERE\n    fund_holdings.type IN ('equity')\n    AND funds.category IN ('emerging','long term','fund of fund','liquid','large cap','small cap','unknown','mid cap','multi cap','debt','value','advantage','fixed maturity plan','contra','large & mid cap','opportunities','hybrid fund')\n    AND funds.one_year_cagr > 0\n    AND funds.three_year_cagr > 20\n    AND funds.five_year_cagr > 0\n    AND funds.marked_as_duplicate != 'true'\n),\nfirst_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.first_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n),\nlast_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.last_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n)\nSELECT\n  COALESCE (\n    first_sum.holding_name,\n    last_sum.holding_name,\n    'something went wrong'\n  ) AS \"Holding Name\",\n  (\n    COALESCE (last_sum.value, 0) - COALESCE (first_sum.value, 0)\n  ) AS \"1 Week\"\nFROM\n  first_sum FULL\n  OUTER JOIN last_sum ON first_sum.holding_name = last_sum.holding_name;",
            format = "table",
            datasourceId = 1,
            intervalMs = 60000,
            maxDataPoints = 743
        },
        {
            refId = "1 Month",
            datasource = {
                type = "grafana-postgresql-datasource",
                uid = "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
            },
            rawSql =
            "WITH start_and_end_time AS (\n  SELECT\n    first(time, time) as first_time,\n    last(time, time) as last_time\n  FROM\n    fund_holdings_data\n  WHERE\n    time > now() - INTERVAL '30 days'\n),\nfiltered_holding_ids as (\n  SELECT\n    fund_holdings.id as id\n  FROM\n    fund_holdings\n    JOIN funds ON fund_holdings.fund_id = funds.id\n  WHERE\n    fund_holdings.type IN ('equity')\n    AND funds.category IN ('emerging','long term','fund of fund','liquid','large cap','small cap','unknown','mid cap','multi cap','debt','value','advantage','fixed maturity plan','contra','large & mid cap','opportunities','hybrid fund')\n    AND funds.one_year_cagr > 0\n    AND funds.three_year_cagr > 20\n    AND funds.five_year_cagr > 0\n),\nfirst_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.first_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n),\nlast_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.last_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n)\nSELECT\n  COALESCE (\n    first_sum.holding_name,\n    last_sum.holding_name,\n    'something went wrong'\n  ) AS \"Holding Name\",\n  (\n    COALESCE (last_sum.value, 0) - COALESCE (first_sum.value, 0)\n  ) AS \"1 Month\"\nFROM\n  first_sum FULL\n  OUTER JOIN last_sum ON first_sum.holding_name = last_sum.holding_name;",
            format = "table",
            datasourceId = 1,
            intervalMs = 60000,
            maxDataPoints = 743
        },
        {
            refId = "Selected Time",
            datasource = {
                type = "grafana-postgresql-datasource",
                uid = "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
            },
            rawSql =
            "WITH start_and_end_time AS (\n  SELECT\n    first(time, time) as first_time,\n    last(time, time) as last_time\n  FROM\n    fund_holdings_data\n  WHERE\n    $__timeFilter(fund_holdings_data.time)\n),\nfiltered_holding_ids as (\n  SELECT\n    fund_holdings.id as id\n  FROM\n    fund_holdings\n    JOIN funds ON fund_holdings.fund_id = funds.id\n  WHERE\n    fund_holdings.type IN ('equity')\n    AND funds.category IN ('emerging','long term','fund of fund','liquid','large cap','small cap','unknown','mid cap','multi cap','debt','value','advantage','fixed maturity plan','contra','large & mid cap','opportunities','hybrid fund')\n    AND funds.one_year_cagr > 0\n    AND funds.three_year_cagr > 20\n    AND funds.five_year_cagr > 0\n    AND funds.marked_as_duplicate != 'true'\n),\nfirst_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.first_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n),\nlast_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.last_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n)\nSELECT\n  COALESCE (\n    first_sum.holding_name,\n    last_sum.holding_name,\n    'something went wrong'\n  ) AS \"Holding Name\",\n  (\n    COALESCE (last_sum.value, 0) - COALESCE (first_sum.value, 0)\n  ) AS \"Selected Time\"\nFROM\n  first_sum FULL\n  OUTER JOIN last_sum ON first_sum.holding_name = last_sum.holding_name;",
            format = "table",
            datasourceId = 1,
            intervalMs = 60000,
            maxDataPoints = 743
        }

    }
    local json_encoded = grafana_request.sorted_queries_json_encode(queries)
    local json_decoded = json.decode(json_encoded)
    luaunit.assertEquals(queries, json_decoded)
end

function test_get_datasource_uids()
    local queries = {
        {
            refId = "2 Days",
            datasource = {
                type = "grafana-postgresql-datasource",
                uid = "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
            },
            rawSql =
            "WITH start_and_end_time AS (\n  SELECT\n    first(time, time) as first_time,\n    last(time, time) as last_time\n  FROM\n    fund_holdings_data\n  WHERE\n    time > now() - INTERVAL '2 days'\n),\nfiltered_holding_ids as (\n  SELECT\n    fund_holdings.id as id\n  FROM\n    fund_holdings\n    JOIN funds ON fund_holdings.fund_id = funds.id\n  WHERE\n    fund_holdings.type IN ('equity')\n    AND funds.category IN ('emerging','long term','fund of fund','liquid','large cap','small cap','unknown','mid cap','multi cap','debt','value','advantage','fixed maturity plan','contra','large & mid cap','opportunities','hybrid fund')\n    AND funds.one_year_cagr > 0\n    AND funds.three_year_cagr > 20\n    AND funds.five_year_cagr > 0\n    AND funds.marked_as_duplicate != 'true'\n),\nfirst_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.first_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n),\nlast_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.last_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n)\nSELECT\n  COALESCE (\n    first_sum.holding_name,\n    last_sum.holding_name,\n    'something went wrong'\n  ) AS \"Holding Name\",\n  (\n    COALESCE (last_sum.value, 0) - COALESCE (first_sum.value, 0)\n  ) AS \"2 Days\"\nFROM\n  first_sum FULL\n  OUTER JOIN last_sum ON first_sum.holding_name = last_sum.holding_name;",
            format = "table",
            datasourceId = 1,
            intervalMs = 60000,
            maxDataPoints = 743
        },
        {
            refId = "7 Days",
            datasource = {
                type = "grafana-postgresql-datasource",
                uid = "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
            },
            rawSql =
            "WITH start_and_end_time AS (\n  SELECT\n    first(time, time) as first_time,\n    last(time, time) as last_time\n  FROM\n    fund_holdings_data\n  WHERE\n    time > now() - INTERVAL '7 days'\n),\nfiltered_holding_ids as (\n  SELECT\n    fund_holdings.id as id\n  FROM\n    fund_holdings\n    JOIN funds ON fund_holdings.fund_id = funds.id\n  WHERE\n    fund_holdings.type IN ('equity')\n    AND funds.category IN ('emerging','long term','fund of fund','liquid','large cap','small cap','unknown','mid cap','multi cap','debt','value','advantage','fixed maturity plan','contra','large & mid cap','opportunities','hybrid fund')\n    AND funds.one_year_cagr > 0\n    AND funds.three_year_cagr > 20\n    AND funds.five_year_cagr > 0\n    AND funds.marked_as_duplicate != 'true'\n),\nfirst_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.first_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n),\nlast_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.last_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n)\nSELECT\n  COALESCE (\n    first_sum.holding_name,\n    last_sum.holding_name,\n    'something went wrong'\n  ) AS \"Holding Name\",\n  (\n    COALESCE (last_sum.value, 0) - COALESCE (first_sum.value, 0)\n  ) AS \"1 Week\"\nFROM\n  first_sum FULL\n  OUTER JOIN last_sum ON first_sum.holding_name = last_sum.holding_name;",
            format = "table",
            datasourceId = 1,
            intervalMs = 60000,
            maxDataPoints = 743
        },
        {
            refId = "1 Month",
            datasource = {
                type = "grafana-postgresql-datasource",
                uid = "bebc8c1a-8a2c-4b65-8352-f0cb1982615a"
            },
            rawSql =
            "WITH start_and_end_time AS (\n  SELECT\n    first(time, time) as first_time,\n    last(time, time) as last_time\n  FROM\n    fund_holdings_data\n  WHERE\n    time > now() - INTERVAL '30 days'\n),\nfiltered_holding_ids as (\n  SELECT\n    fund_holdings.id as id\n  FROM\n    fund_holdings\n    JOIN funds ON fund_holdings.fund_id = funds.id\n  WHERE\n    fund_holdings.type IN ('equity')\n    AND funds.category IN ('emerging','long term','fund of fund','liquid','large cap','small cap','unknown','mid cap','multi cap','debt','value','advantage','fixed maturity plan','contra','large & mid cap','opportunities','hybrid fund')\n    AND funds.one_year_cagr > 0\n    AND funds.three_year_cagr > 20\n    AND funds.five_year_cagr > 0\n),\nfirst_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.first_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n),\nlast_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.last_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n)\nSELECT\n  COALESCE (\n    first_sum.holding_name,\n    last_sum.holding_name,\n    'something went wrong'\n  ) AS \"Holding Name\",\n  (\n    COALESCE (last_sum.value, 0) - COALESCE (first_sum.value, 0)\n  ) AS \"1 Month\"\nFROM\n  first_sum FULL\n  OUTER JOIN last_sum ON first_sum.holding_name = last_sum.holding_name;",
            format = "table",
            datasourceId = 1,
            intervalMs = 60000,
            maxDataPoints = 743
        },
        {
            refId = "Selected Time",
            datasource = {
                type = "grafana-postgresql-datasource",
                uid = "bebc8c1a-8a2c-4b65-8352-f0cb1982615a"
            },
            rawSql =
            "WITH start_and_end_time AS (\n  SELECT\n    first(time, time) as first_time,\n    last(time, time) as last_time\n  FROM\n    fund_holdings_data\n  WHERE\n    $__timeFilter(fund_holdings_data.time)\n),\nfiltered_holding_ids as (\n  SELECT\n    fund_holdings.id as id\n  FROM\n    fund_holdings\n    JOIN funds ON fund_holdings.fund_id = funds.id\n  WHERE\n    fund_holdings.type IN ('equity')\n    AND funds.category IN ('emerging','long term','fund of fund','liquid','large cap','small cap','unknown','mid cap','multi cap','debt','value','advantage','fixed maturity plan','contra','large & mid cap','opportunities','hybrid fund')\n    AND funds.one_year_cagr > 0\n    AND funds.three_year_cagr > 20\n    AND funds.five_year_cagr > 0\n    AND funds.marked_as_duplicate != 'true'\n),\nfirst_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.first_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n),\nlast_sum AS (\n  SELECT\n    holding_name,\n    SUM(holding_percentage) as value\n  FROM\n    fund_holdings\n    JOIN fund_holdings_data ON fund_holdings.id = fund_holdings_data.holding_id\n  WHERE\n    time = (\n      SELECT\n        start_and_end_time.last_time\n      from\n        start_and_end_time\n      limit\n        1\n    )\n    AND fund_holdings.id IN (\n      select\n        id\n      from\n        filtered_holding_ids\n    )\n  group by\n    holding_name\n)\nSELECT\n  COALESCE (\n    first_sum.holding_name,\n    last_sum.holding_name,\n    'something went wrong'\n  ) AS \"Holding Name\",\n  (\n    COALESCE (last_sum.value, 0) - COALESCE (first_sum.value, 0)\n  ) AS \"Selected Time\"\nFROM\n  first_sum FULL\n  OUTER JOIN last_sum ON first_sum.holding_name = last_sum.holding_name;",
            format = "table",
            datasourceId = 1,
            intervalMs = 60000,
            maxDataPoints = 743
        }
    }

    local data_sources = grafana_request.get_datasource_uids(queries)
    luaunit.assertItemsEquals({
        "bebc8c1a-8a2c-4b65-8352-f0cb1982615a",
        "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
    }, data_sources)

    luaunit.assertError(
        function()
            grafana_request.get_datasource_uids({
                {}
            })
        end
    )
end

function test_get_grafana_query_cache_key()
    local base_request_body = {
        from = "1703631956991",
        to = "1703653556991",
        queries = {
            {
                refId = "FundCategory",
                datasource = {
                    type = "postgres",
                    uid = "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
                },
                rawSql = "select distinct COALESCE(NULLIF(category, ''), 'unknown') from funds;",
                format = "table"
            },
            {
                refId = "FundCategory",
                datasource = {
                    type = "postgres",
                    uid = "cebc8c1a-8a2c-4b65-8352-f0cb1982615a"
                },
                rawSql = "select distinct COALESCE(NULLIF(category, ''), 'unknown') from funds;",
                format = "table"
            }
        }
    }


    local time_bucket_length_ms = 100000
    local time_frame_bucket_length_ms = 100000
    local max_data_points_bucket_length = 1000

    local tests = {
        {
            name = "acceptable end time delta - delta < max allowed",
            same_cache_key = true,
            request_body1 = {
                from = tostring(0),
                to = tostring(1),
                queries = base_request_body.queries
            },
            request_body2 = {
                from = tostring(0 + time_bucket_length_ms - 1), -- for keeping time range/frame same
                to = tostring(1 + time_bucket_length_ms - 1),
                queries = base_request_body.queries
            }
        },
        {
            name = "acceptable end time delta - delta = max allowed",
            same_cache_key = false,
            request_body1 = {
                from = "0",
                to = tostring(1),
                queries = base_request_body.queries
            },
            request_body2 = {
                from = tostring(0 + time_bucket_length_ms), -- for keeping time range/frame same
                to = tostring(1 + time_bucket_length_ms),
                queries = base_request_body.queries
            }
        },
        {
            name = "acceptable end time delta - delta > max allowed",
            same_cache_key = false,
            request_body1 = {
                from = "0",
                to = tostring(1),
                queries = base_request_body.queries
            },
            request_body2 = {
                from = tostring(0 + time_bucket_length_ms + 1), -- for keeping time range/frame same
                to = tostring(1 + time_bucket_length_ms + 1),
                queries = base_request_body.queries
            }
        },
        {
            name = "acceptable time frame delta - delta < max allowed",
            same_cache_key = true,
            request_body1 = {
                from = base_request_body.from,
                to = base_request_body.to,
                queries = base_request_body.queries
            },
            request_body2 = {
                from = tostring(tonumber(base_request_body.from) + time_bucket_length_ms - 1), -- for keeping time range/frame same
                to = base_request_body.to,
                queries = base_request_body.queries
            }
        },
        {
            name = "acceptable time frame delta - delta = max allowed",
            same_cache_key = false,
            request_body1 = {
                from = base_request_body.from,
                to = base_request_body.to,
                queries = base_request_body.queries
            },
            request_body2 = {
                from = tostring(tonumber(base_request_body.from) + time_bucket_length_ms), -- for keeping time range/frame same
                to = base_request_body.to,
                queries = base_request_body.queries
            }
        },
        {
            name = "acceptable time frame delta - delta > max allowed",
            same_cache_key = false,
            request_body1 = {
                from = base_request_body.from,
                to = base_request_body.to,
                queries = base_request_body.queries
            },
            request_body2 = {
                from = tostring(tonumber(base_request_body.from) + time_bucket_length_ms + 1), -- for keeping time range/frame same
                to = base_request_body.to,
                queries = base_request_body.queries
            }
        },
        {
            name = "acceptable max data points delta - delta < max allowed",
            same_cache_key = true,
            request_body1 = {
                from = base_request_body.from,
                to = base_request_body.to,
                queries = {
                    {
                        maxDataPoints = 1001,
                    }
                }
            },
            request_body2 = {
                from = base_request_body.from,
                to = base_request_body.to,
                queries = {
                    {
                        maxDataPoints = 1001 + max_data_points_bucket_length - 1,
                    }
                }
            }
        },
        {
            name = "acceptable max data points delta - delta = max allowed",
            same_cache_key = false,
            request_body1 = {
                from = base_request_body.from,
                to = base_request_body.to,
                queries = {
                    {
                        maxDataPoints = 1001,
                    }
                }
            },
            request_body2 = {
                from = base_request_body.from,
                to = base_request_body.to,
                queries = {
                    {
                        maxDataPoints = 1001 + max_data_points_bucket_length,
                    }
                }
            }
        },
        {
            name = "acceptable max data points delta - delta > max allowed",
            same_cache_key = false,
            request_body1 = {
                from = base_request_body.from,
                to = base_request_body.to,
                queries = {
                    {
                        maxDataPoints = 1001,
                    }
                }
            },
            request_body2 = {
                from = base_request_body.from,
                to = base_request_body.to,
                queries = {
                    {
                        maxDataPoints = 1001 + max_data_points_bucket_length + 1,
                    }
                }
            }
        }
    }

    for _, test in pairs(tests) do
        print(string.format("\ntest: [%s]", test.name))
        local cache_key1 = grafana_request.get_grafana_query_cache_key(
            test.request_body1.to,
            test.request_body1.from,
            test.request_body1.queries,
            time_bucket_length_ms,
            time_frame_bucket_length_ms,
            max_data_points_bucket_length
        )
        luaunit.assertStrMatches(
            cache_key1,
            "time_bucket_number=[0-9]+;time_frame_bucket_number=[0-9]+;queries=[a-zA-Z0-9]+"
        )

        local cache_key2 = grafana_request.get_grafana_query_cache_key(
            test.request_body2.to,
            test.request_body2.from,
            test.request_body2.queries,
            time_bucket_length_ms,
            time_frame_bucket_length_ms,
            max_data_points_bucket_length
        )
        luaunit.assertStrMatches(
            cache_key2,
            "time_bucket_number=[0-9]+;time_frame_bucket_number=[0-9]+;queries=[a-zA-Z0-9]+"
        )
        if test.same_cache_key then
            luaunit.assertEquals(
                cache_key1,
                cache_key2
            )
        else
            luaunit.assertNotEquals(
                cache_key1,
                cache_key2
            )
        end
    end
end

-- get cache_key and datasources are individualy tested above. here we will doing basic testing
function test_get_cache_key_and_datasource_uids()
    local acceptable_time_delta_seconds = 100
    local acceptable_time_range_delta_seconds = 100
    local acceptable_max_points_delta = 100

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

    -- invalid body
    luaunit.assertError(
        function()
            grafana_request.get_cache_key_and_datasource_uids({}, acceptable_time_delta_seconds,
                acceptable_time_range_delta_seconds, acceptable_max_points_delta)
        end
    )

    local cache_key, data_sources = grafana_request.get_cache_key_and_datasource_uids(
        json.decode(requestBody),
        acceptable_time_delta_seconds, acceptable_time_range_delta_seconds, acceptable_max_points_delta
    )

    luaunit.assertStrMatches(cache_key, "time_bucket_number=[0-9]+;time_frame_bucket_number=[0-9]+;queries=[a-zA-Z0-9]+")
    luaunit.assertItemsEquals(data_sources, { "cebc8c1a-8a2c-4b65-8352-f0cb1982615a" })
end

function test_check_table_type()
    local tests = {
        {
            name = "valid-required-fields",
            table = {
                name = "tom",
                age = 10,
                funny = true,
            },
            type = {
                { key = "name",  type = "string" },
                { key = "age",   type = "number" },
                { key = "funny", type = "boolean" },
            },
            expected_output = true,
        },
        {
            name = "valid-optional-field",
            table = {
                name = "jerry",
                age = 11,
            },
            type = {
                { key = "name",  type = "string" },
                { key = "age",   type = "number" },
                { key = "funny", type = "boolean", required = false }
            },
            expected_output = true,
        },
        {
            name = "invalid-field-type",
            table = {
                name = "jerry",
                age = 11,
            },
            type = {
                { key = "name",  type = "string" },
                { key = "age",   type = "string" },
                { key = "funny", type = "boolean", required = false }
            },
            expected_output = false,
        },
        {
            name = "valid-multiple-type-field",
            table = {
                id = 10,
                name = "jerry",
                age = 11,
            },
            type = {
                { key = "name",  type = "string" },
                { key = "age",   type = "number" },
                { key = "funny", type = "boolean",      required = false },
                { key = "id",    type = "string|number" }
            },
            expected_output = true,
        },
        {
            name = "invalid-multiple-type-field",
            table = {
                id = 10,
                name = "jerry",
                age = 11,
            },
            type = {
                { key = "name",  type = "string" },
                { key = "age",   type = "number" },
                { key = "funny", type = "boolean",     required = false },
                { key = "id",    type = "string|table" }
            },
            expected_output = false,
        }
    }
    for _, test in pairs(tests) do
        local valid = utils.check_table_type(test.table, test.type)
        print(string.format("\ntest_check_table_type: [%s]", test.name))
        if test.expected_output then
            luaunit.assertTrue(valid)
        else
            luaunit.assertFalse(valid)
        end
    end
end

function test_check_type()
    local tests = {
        {
            name = "valid-type-number",
            variable = 10,
            type = "number",
            expected_output = true,
        },
        {
            name = "valid-type-string",
            variable = "hi",
            type = "string",
            expected_output = true,
        },
        {
            name = "valid-type-table",
            variable = {},
            type = "table",
            expected_output = true,
        },
        {
            name = "invalid-type-01",
            variable = "hi",
            type = "number",
            expected_output = false,
        },
        {
            name = "invalid-type-02",
            variable = {},
            type = "string",
            expected_output = false,
        },
        {
            name = "valid-multiple-type-01",
            variable = {},
            type = "table|string|number",
            expected_output = true,
        },
        {
            name = "valid-multiple-type-02",
            variable = 1,
            type = "table|string|number",
            expected_output = true,
        },
        {
            name = "valid-multiple-type-03",
            variable = "hi",
            type = "table|string|number",
            expected_output = true,
        },
        {
            name = "invalid-multiple-type-01",
            variable = "hi",
            type = "table|number",
            expected_output = false,
        },
        {
            name = "invalid-multiple-type-01",
            variable = 1,
            type = "table|string",
            expected_output = false,
        }
    }

    for _, test in pairs(tests) do
        print(string.format("\ntest_check_type: [%s]", test.name))
        luaunit.assertEquals(
            utils.check_type(type(test.variable), test.type),
            test.expected_output
        )
    end
end

function test_get_query_labels()
    local tests = {
        {
            name = "valid-query-label-01",
            query = [[--key1=value1;key2=value2;key3=value3;
            select * from test where a=b;]],
            expected_output = {
                key1 = "value1",
                key2 = "value2",
                key3 = "value3",
            }
        },
        {
            name = "valid-query-label-02",
            query = [[--key1=value1; key2=value2; key3=value3;
            prometheus_metric{label="value1"}
            ]],
            expected_output = {
                key1 = "value1",
                key2 = "value2",
                key3 = "value3",
            }
        },
        {
            name = "valid-query-label-03",
            query = [[-- key1 = value1 ; key2 = value2 ; key3 = value3 ;
            prometheus_metric{label="value1"}
            ]],
            expected_output = {
                key1 = "value1",
                key2 = "value2",
                key3 = "value3",
            }
        },
        {
            name = "invalid-query-label-01",
            query = [[prometheus_metric{label=value1}]],
            expected_output = nil
        },
        {
            name = "invalid-query-label-01",
            query = [[select * from test where label=value1;]],
            expected_output = nil
        }
    }
    for _, test in pairs(tests) do
        print(string.format("\ntest_get_query_labels: [%s]", test.name))
        luaunit.assertItemsEquals(
            grafana_request.get_query_labels(test.query),
            test.expected_output
        )
    end
end

function test_get_queries_labels()
    local tests = {
        {
            name = "valid-labels-01",
            queries = {
                {
                    query = [[-- key1 = value1 ; key2 = value2 ; key3 = value3 ;
                    prometheus_metric{label="value1"}
                    ]],
                },
                {
                    query = [[prometheus_metric{label="value1"}]],
                },
                {
                    query = [[prometheus_metric{label="value1"}]],
                }
            },
            expected_output = {
                key1 = "value1",
                key2 = "value2",
                key3 = "value3",
            }
        },
        {
            name = "valid-labels-02",
            queries = {
                {
                    query = [[prometheus_metric{label="value1"}]],
                },
                {
                    query = [[-- key1 = value1 ; key2 = value2 ; key3 = value3 ;
                    prometheus_metric{label="value1"}
                    ]],
                },
                {
                    query = [[prometheus_metric{label="value1"}]],
                }
            },
            expected_output = {
                key1 = "value1",
                key2 = "value2",
                key3 = "value3",
            }
        },
        {
            name = "valid-labels-03",
            queries = {
                {
                    query = [[prometheus_metric{label="value1"}]],
                },
                {
                    query = [[prometheus_metric{label="value1"}]],
                },
                {
                    query = [[-- key1 = value1 ; key2 = value2 ; key3 = value3 ;
                    prometheus_metric{label="value1"}
                    ]],
                }
            },
            expected_output = {
                key1 = "value1",
                key2 = "value2",
                key3 = "value3",
            }
        },
        {
            name = "invalid-labels-01",
            queries = {
                {
                    query = [[prometheus_metric{label="value1"}]],
                },
                {
                    query = [[prometheus_metric{label="value1"}]],
                },
                {
                    query = [[prometheus_metric{label="value1"}]],
                }
            },
            expected_output = nil
        }
    }
    for _, test in pairs(tests) do
        print(string.format("\ntest_get_queries_labels: [%s]", test.name))
        luaunit.assertItemsEquals(
            grafana_request.get_queries_labels(test.queries),
            test.expected_output
        )
    end
end

REUSABLE_CACHE_RULE_01 = [[
      default:
        enabled: true
        acceptable_time_delta_seconds: 111
        acceptable_time_range_delta_seconds: 11
        acceptable_max_points_delta: 1111
        id: default
      cache_rules:
        - panel_selector:
            datasource: prometheus
            cacheable: "false"
          cache_config:
            enabled: true
            acceptable_time_delta_seconds: 222
            acceptable_time_range_delta_seconds: 22
            acceptable_max_points_delta: 2222
            id: prometheus
    
        - panel_selector:
            datasource: timescaledb
          cache_config:
            enabled: true
            acceptable_time_delta_seconds: 333
            acceptable_time_range_delta_seconds: 33
            acceptable_max_points_delta: 3333
            id: timescaledb
        ]]

function test_get_cache_config()
    local tests = {
        {
            name = "invalid-labels-01",
            config = REUSABLE_CACHE_RULE_01,
            labels = {},
            expected_cache_config_id = "default"
        },
        {
            name = "invalid-labels-02",
            config = REUSABLE_CACHE_RULE_01,
            labels = {
                abc = "def"
            },
            expected_cache_config_id = "default"
        },
        {
            name = "valid-labels-01",
            config = REUSABLE_CACHE_RULE_01,
            labels = {
                datasource = "timescaledb"
            },
            expected_cache_config_id = "timescaledb"
        },
        {
            name = "valid-labels-02",
            config = REUSABLE_CACHE_RULE_01,
            labels = {
                datasource = "prometheus",
                cacheable = "false"
            },
            expected_cache_config_id = "prometheus"
        },
    }
    for _, test in pairs(tests) do
        print(string.format("\ntest_get_cache_config: [%s]", test.name))
        local config_file_path = string.format("/tmp/test-config-%d.yaml", os.time(os.date("!*t")))
        local config_file = io.open(config_file_path, "w")
        if config_file == nil then
            error("unable to create temporary config_file")
        end
        config_file:write(test.config)
        config_file:close()

        config.load_config(config_file_path)
        os.remove(config_file_path)
        local cfg = config.get_config()
        if cfg == nil then
            error("nil config")
        end
        luaunit.assertItemsEquals(
            cfg:get_cache_config(test.labels).id,
            test.expected_cache_config_id
        )
    end
end

function test_get_queries_config()
    local tests = {
        {
            name = "invalid-queries-01",
            config = REUSABLE_CACHE_RULE_01,
            queries = {},
            expected_cache_config_id = "default"
        },
        {
            name = "valid-queries",
            config = REUSABLE_CACHE_RULE_01,
            queries = {
                {
                    query = [[-- datasource=timescaledb;
                    prometheus_metric{label="value1"}
                    ]],
                },
                {
                    query = [[prometheus_metric{label="value1"}]],
                },
                {
                    query = [[prometheus_metric{label="value1"}]],
                }
            },
            expected_cache_config_id = "timescaledb"
        },
    }
    for _, test in pairs(tests) do
        print(string.format("\ntest_get_queries_config: [%s]", test.name))
        local config_file_path = string.format("/tmp/test-config-%d.yaml", os.time(os.date("!*t")))
        local config_file = io.open(config_file_path, "w")
        if config_file == nil then
            error("unable to create temporary config_file")
        end
        config_file:write(test.config)
        config_file:close()

        config.load_config(config_file_path)
        os.remove(config_file_path)
        local cfg = config.get_config()
        if cfg == nil then
            error("nil config")
        end
        luaunit.assertItemsEquals(
            grafana_request.get_queries_config(cfg, test.queries).id,
            test.expected_cache_config_id
        )
    end
end
os.exit(luaunit.LuaUnit.run())
