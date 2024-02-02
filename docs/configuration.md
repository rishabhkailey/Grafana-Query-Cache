## Adding Labels to Grafana Panels

1. Add labels in the first line of your panel's query:
    ```
    <comment sequence> label_key1=label_value1; label_key2=label_value2;
    ```
    * Replace `<comment sequence>` with the appropriate comment syntax for your query language (e.g., `#` for PromQL, `--` for SQL).
    * Define your desired label key-value pairs using the semicolon as a separator

**Prometheus (PromQL):**
```promql
# datasource=prometheus-01; panel=user-requests; dashboard=website-usage;
user_requests_count{website="test-website"}
``` 

**SQL:**
```sql
-- datasource=postgres; panel=user-requests; dashboard=website-usage;
select * from user_requests_count where website='test-website';
```


**Important Note on Label Application**: 
* Labels are applied at the Grafana graph/panel level, not the individual query level. This is because Grafana sends a single request encompassing all queries for a given graph or panel. 
* only one query within the graph/panel needs to have labels for matching purposes. 
* In cases where multiple queries within a single request have labels, the labels from the first query will be used.





## Cache Rule Configuration File

### Structure:

* **default**:
  * Specifies default caching behavior, It applies to query requests that either have no labels or whose labels don't match any of the explicitly defined cache rules.
* **cache_rules**:
  * Contains an array of cache rules, each defining criteria for matching queries and their associated cache configuration.

### Fields:

* **panel_selector**:
  * Defines criteria for matching queries, using user-defined key-value pairs.
  * Only string values are permitted in query selectors.
* **cache_config**:
  Determines the caching behavior for queries that match the panel_selector.
  * **enabled**: Boolean indicating whether caching is enabled for the matching query request.
  * **acceptable_time_delta_seconds**: Determines the size of time-based buckets for caching (queries made within a similar timeframe will have the same key, using the same cached value).
  * **acceptable_time_range_delta_seconds**: Determines the size of time range-based buckets for caching (queries with similar time ranges will have the same key, using the same cached value).
  * **acceptable_max_points_delta**: Determines the size of data points-based buckets for caching (queries with similar data point counts will have the same key, using the same cached value).
  * **id** (optional): Identifier for this cache configuration, primarily used for debugging.

### Key Points:

* **Important Note on Label Application**: Labels are applied at the Grafana graph/panel request level, not the individual query level. This is because Grafana sends a single request encompassing all queries for a given graph or panel. Therefore, only one query within the graph/panel needs to have labels for matching purposes. In cases where multiple queries within a single request have labels, the labels from the first query will be used.
* If debugging is enabled, the `X-Cache-Config-Id:` response header reflects the matching cache configuration's ID for each request.



### Example of cache rule

```yaml
default:
  enabled: true
  acceptable_time_delta_seconds: 111
  acceptable_time_range_delta_seconds: 11
  acceptable_max_points_delta: 1111
  id: default

cache_rules:
  - panel_selector:
      datasource: prometheus
      cacheable: "true"
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
```

## Supported Environment variables
| Environment Variable | Default Value | Description |
| -- | -- | -- |
| GRAFANA_HOST   | `localhost:3000`   |  Specifies the hostname and port of the upstream Grafana instance to connect to.  |
| GRAFANA_SCHEME | `http` | Sets the communication protocol (HTTP or HTTPS) for interacting with Grafana. |
| MAX_CACHE_SIZE | `1g` | Determines the maximum size of the cache storage, limiting the amount of data that can be cached.  |
| KEY_ZONE_SIZE | `10m` | Allocates the amount of shared memory used to store cache keys and metadata, managing cache organization and retrieval efficiency. |
| MAX_INACTIVE_TIME | `10m` | Configures the cache eviction policy, removing cached items that haven't been accessed within the specified time, even if they haven't expired based on their freshness. |
| CACHE_EXPIRE_TIME | `60m` | Sets the time duration after which cached items will automatically be considered expired and refreshed, ensuring data stays up-to-date. |
| CACHE_DIRECTORY | `/var/lib/nginx/cache` | Designates the file system directory where cached data will be stored. |
| CACHE_VERSION | `1` | Serves as a mechanism for cache invalidation. Updating this variable marks previously cached items as obsolete, prompting the retrieval of fresh data upon subsequent requests. However, the physical removal of old cached items occurs based on `MAX_INACTIVE_TIME` or `MAX_CACHE_SIZE` settings, ensuring efficient cache management. |
| SERVER_NAME          |  `_`               | Specifies the hostname or domain name that the server. this will be used in the nginx server directive.                           |
| LISTEN               | `80`                            | Sets the port number on which the server will listen for incoming connections. for ssl set it to `443 ssl`. this will be used by the nginx listen directive.                                        |
| SSL                  | `off`                           | Enables or disables SSL/TLS encryption for secure communication. Valid values are "on" or "off".                      |
| SSL_CERTIFICATE      | ""             | Path to the SSL/TLS certificate file, required when SSL is enabled.                                                   |
| SSL_CERTIFICATE_KEY  | ""             | Path to the SSL/TLS private key file, paired with the certificate for encryption.                                     |
| SSL_PROTOCOLS        | `TLSv1 TLSv1.1 TLSv1.2 TLSv1.3` | list of SSL/TLS protocols to support. Adjust based on security requirements and client compatibility. |
| SSL_CIPHERS          | `HIGH:!aNULL:!MD5`              | Specifies the allowed cipher suites for SSL/TLS connections, prioritizing strong ciphers and excluding weak ones.     |
| SSL_PASSWORD_FILE    | ""             | Path to a file containing the passphrase for an encrypted private key, required if the key is encrypted.              |
| CLIENT_MAX_BODY_SIZE | `5m`              | Sets the maximum allowed size of client request bodies, preventing excessive resource consumption.                    |
| DEBUG_IP_CADR | `127.0.0.1/32`              | Controls IPs receiving debug headers (X-Cache-Status, X-Cache-Key, X-Cache-Access-Denied). Set to 127.0.0.1/32 for local or 0.0.0.0/0 for all IPs. |
| MIN_REQUEST_COUNT | `2` | Defines the minimum request threshold for caching individual requests. Requests must exceed this threshold to become eligible for caching. Controls cache efficiency and prevents premature caching of infrequently accessed content. |
| CACHE_RULES_FILE_PATH | `/etc/grafana-query-cache/cache_rules.yaml` | path of cache rules config file |
| CACHE_INVALIDATE_ENDPOINT_ENABLED | `false` | Enables an additional endpoint for invalidating the cache. When enabled, a POST request to `/cache/invalidate` will trigger cache invalidation. |
| CACHE_INVALIDATE_ENDPOINT_ALLOW_CIDR | `` | Defines the whitelisted IP addresses or CIDR ranges allowed to access the cache invalidation endpoint. For localhost usage, consider setting this to `127.0.0.1/32`. |