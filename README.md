# Grafana Query Cache

Grafana Query Cache is an Nginx-powered proxy that accelerates dashboard loading and reduces data source load by caching query results.

## Key Features:

**High-Performance Caching**: Leverages Nginx's performant proxy cache for fast query response retrieval.


**Reduced Data Source Load**: Grafana Query Cache handles duplicate queries by forwarding only the first to Grafana and serving subsequent identical requests directly from its cache, significantly reducing the load on your data source."

**Configurable Caching**: Tailored to Your Needs

* Lua-powered cache key generation for precise control over caching behavior.
* Define cache lifecycle:
  * Set `MAX_INACTIVE_TIME` to control how long cached items remain valid without access.
  * Set `CACHE_EXPIRE_TIME` to enforce a maximum lifespan for cached items.

**Label-Based Query Caching**: This feature allow you to configure query caching granularity by associating labels with Grafana panels and constructing specific caching rules using grafana panel selectors that target those labels.

## How it works
1. (optional) label grafana data panel using comments in query.
![./images/panel-labels-example-01.png](./docs/images/panel-labels-example-01.png)
2. configure cache rules 
    ```yaml
    # default cache config for query requests that either have no labels or whose labels don't match any of the explicitly defined cache rules
    default:
      enabled: true
      acceptable_time_delta_seconds: 111
      acceptable_time_range_delta_seconds: 11
      acceptable_max_points_delta: 1111
      id: default
    # (optional) Determines the caching behavior for queries that match the panel_selector.
    cache_rules:
      - panel_selector:
          datasource: timescaledb
        cache_config:
          enabled: true
          acceptable_time_delta_seconds: 333
          acceptable_time_range_delta_seconds: 33
          acceptable_max_points_delta: 3333
          id: timescaledb
    ```
3. run the grafana-query-cache
    ```bash
    docker run -it --network host \
      -e GRAFANA_SCHEME=http \
      -e GRAFANA_HOST=localhost:3000 \
      -e LISTEN=8080 \
      -v ./cache_rules.yaml:/etc/grafana-query-cache/cache_rules.yaml \
      rishabhveer/grafana-query-cache:latest
    ```

4. access grafana from the grafana-query-cache proxy http://localhost:8080.

5. enjoy the performace


## Getting Started:


### Using Docker
To test Grafana Query Cache locally without a complex network setup, utilize Docker's host network mode for a streamlined experience.
```bash
docker run -it --network host \
  -e GRAFANA_SCHEME=http \
  -e GRAFANA_HOST=localhost:3000 \
  -e LISTEN=8080 \
  rishabhveer/grafana-query-cache:latest
```
Grafana should be accessible on [http://localhost:8080/](http://localhost:8080/)



### Using Docker Compose
Integrate Grafana Query Cache by adding the following service to your Docker Compose configuration: 
```yaml
services:
  grafana-query-cache:
    image: rishabhveer/grafana-query-cache:latest
    environment: 
      GRAFANA_SCHEME: http
      GRAFANA_HOST: grafana:3000
      LISTEN: 8080
      CACHE_RULES_FILE_PATH: /etc/grafana-query-cache/cache_rules.yaml
    volumes:
      - ./cache_rules.yaml:/etc/grafana-query-cache/cache_rules.yaml
    depends_on:
      grafana:
        condition: service_healthy
```

### Integrating Grafana Query Cache into Your Existing Nginx Setup

**Prerequisites:**
* Nginx with Lua support: Please make sure your Nginx installation includes Lua capabilities.
* Lua md5 package: Install the Lua md5 package, available at https://lunarmodules.github.io/md5/.

**Steps:**
1. Obtain grafana_request.lua:

    Download the grafana_request.lua file from https://github.com/rishabhkailey/Grafana-Query-Cache/blob/main/grafana_request.lua.
2. Place grafana_request.lua:

    Copy the downloaded grafana_request.lua file into a directory within your Nginx's LUA_PATH.
3. Generate Nginx configuration:
    
    Execute the following command to generate the necessary Nginx configuration:
    ```bash
    docker run -it --network host \
      -e GRAFANA_SCHEME=http \
      -e GRAFANA_HOST=localhost:3000 \
      -e LISTEN=8080 \
      rishabhveer/grafana-query-cache:latest \
      /opt/entrypoint.sh test -v
    ```
    > Note: Adjust environment variables in the above command to match your specific deployment needs.

4. Locate generated configuration:

    Find the generated configuration in the output under the comment `# configuration file /etc/nginx/conf.d/grafana.conf`.

    ![Screenshot](docs/images/generate-nginx-config.webp)

5. Incorporate configuration:

    Integrate the generated configuration into your Nginx setup by placing it within your /etc/nginx/conf.d directory.
6. Restart Nginx:

    After adding the configuration, restart Nginx to apply the changes.


## Configuration
check [configuration.md](./docs/configuration.md) for details.

## Key Considerations 
* User Access Verification: To ensure data security, Grafana Query Cache always verifies user access permissions with Grafana for each query request, even when serving from the cache. 
* Time Range Variability:
  * Be mindful of Grafana's potential time range variations of ±1 second.
  * To prevent cache misses due to this behavior, choose values for `acceptable_time_range_delta_seconds` that don't evenly divide common time ranges used in your Grafana dashboards. For instance, consider using 599 instead of 600.
  * This ensures consistent cache keys for queries with slightly differing time ranges, maximizing cache efficiency.

## Ideal Scenarios for Caching:

* **Relatively Static Data**: Maximize cache efficiency by using it for data sources that don't experience frequent updates.
* **High User Volume**: Effectively handle large numbers of concurrent users with the cache, reducing the load on your data source.
* **Resource-Intensive Queries**: Optimize performance for expensive or time-consuming queries by caching their results.

## When to Avoid Caching:

* **Highly Dynamic Data**: For data sources with frequent updates or real-time monitoring needs, caching might lead to outdated information and is generally not recommended.




## Supported Data Sources
Ideally, Grafana Query Cache should support any data source that utilizes [Grafana's Data Source Query API](https://grafana.com/docs/grafana/latest/developers/http_api/data_source/#query-a-data-source).

### Tested and Verified Data Sources:
* Prometheus
* Timescale/Postgres
