> Note: an extra request will be sent to grafana origin server for verifying user access. this is required for 


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
| SERVER_NAME          |  `_`               | Specifies the hostname or domain name that the server. this will be used in nginx server directive.                           |
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
| ACCEPTABLE_TIME_DELTA_SECONDS | `1799` | Determines the size of time-based buckets for caching. Requests within the same bucket (up to 1799 seconds apart) will share a cache key and value. |
| ACCEPTABLE_TIME_RANGE_DELTA_SECONDS | `599` | Determines the size of time range-based buckets for caching. Requests with overlapping time ranges within the bucket (up to 599 seconds apart) will share a cache key and value. | 
| ACCEPTABLE_MAX_POINTS_DELTA | `259` | Determines the size of data points-based buckets for caching. Requests with data point differences within the bucket (up to 259 points apart) will share a cache key and value. |


<!-- todo why we have weird number value  for time delta variables -->