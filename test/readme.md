## Query Requests


### Prometheus

API
```json
/api/ds/query?ds_type=prometheus&requestId=Q100
{
    "queries": [
        {
            "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
            },
            "editorMode": "code",
            "expr": "irate(prometheus_http_request_duration_seconds_sum[1m]) / prometheus_http_request_duration_seconds_count",
            "instant": false,
            "legendFormat": "{{ handler }}",
            "range": true,
            "refId": "A",
            "exemplar": false,
            "requestId": "2A",
            "utcOffsetSec": 19800,
            "interval": "",
            "datasourceId": 1,
            "intervalMs": 15000,
            "maxDataPoints": 1262
        }
    ],
    "from": "1704594572010",
    "to": "1704616172010"
}

```


cURL
```bash
curl --request POST \
  --url 'http://172.27.0.4:3000/api/ds/query?ds_type=prometheus&requestId=Q100' \
  --header 'Authorization: Basic YWRtaW46YWRtaW4=' \
  --header 'Content-Type: application/json' \
  --header 'User-Agent: insomnia/8.5.1' \
  --data '{
    "queries": [
        {
            "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
            },
            "editorMode": "code",
            "expr": "irate(prometheus_http_request_duration_seconds_sum[1m]) / prometheus_http_request_duration_seconds_count",
            "instant": false,
            "legendFormat": "{{ handler }}",
            "range": true,
            "refId": "A",
            "exemplar": false,
            "requestId": "2A",
            "utcOffsetSec": 19800,
            "interval": "",
            "datasourceId": 1,
            "intervalMs": 15000,
            "maxDataPoints": 1262
        }
    ],
    "from": "1704594572010",
    "to": "1704616172010"
}'
```


### Timescale/Postgres

API 
```json
/api/ds/query?ds_type=grafana-postgresql-datasource&requestId=Q101
{
  "queries": [
    {
      "refId": "A",
      "datasource": {
        "type": "grafana-postgresql-datasource",
        "uid": "timescaledb"
      },
      "rawSql": "select * from information_schema.tables;",
      "format": "table",
      "datasourceId": 2,
      "intervalMs": 60000,
      "maxDataPoints": 1262
    }
  ],
  "from": "1704594572012",
  "to": "1704616172012"
}
```

cURL
```bash
curl --request POST \
  --url 'http://172.27.0.4:3000/api/ds/query?ds_type=prometheus&requestId=Q100' \
  --header 'Authorization: Basic YWRtaW46YWRtaW4=' \
  --header 'Content-Type: application/json' \
  --header 'User-Agent: insomnia/8.5.1' \
  --data '{
  "queries": [
    {
      "refId": "A",
      "datasource": {
        "type": "grafana-postgresql-datasource",
        "uid": "timescaledb"
      },
      "rawSql": "select * from information_schema.tables;",
      "format": "table",
      "datasourceId": 2,
      "intervalMs": 60000,
      "maxDataPoints": 1262
    }
  ],
  "from": "1704594572012",
  "to": "1704616172012"
}'
```


## Test caces
* proxy auth both using cookie and authorization header
* min use check
* check variance in to, from, max data points
* 



## Run tests with debugging
```bash
cd test
docker compose up -d

docker network create grafana-cache-test-network
# d05e669a087e is devcontainer
docker network connect grafana-cache-test-network test-query-cache-1 
docker network connect grafana-cache-test-network d05e669a087e

# now we should be able to connect to query cache container from dev container
curl test-query-cache-1
```

## Run test in ci/cd
```bash
docker compose up -d
sudo docker exec test-integration-test-1 go clean -testcache
sudo docker exec test-integration-test-1 go test ./
```