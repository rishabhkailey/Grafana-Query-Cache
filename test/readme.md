# Running Tests with Debugging in VS Code

1. Start Grafana, Prometheus, and TimescaleDB:
    ```bash
    cd test
    docker compose up -d
    ```
* Create a network for VS Code devcontainer (if applicable):
    ```bash  
    docker network create grafana-cache-test-network || true
    # if the following command fails, then use `docker ps` to get id of vscode devcontainer
    dev_container=$(docker ps | grep vsc-grafana-query-cache | egrep -o "^[^\ ]+")
    docker network connect grafana-cache-test-network test-grafana-query-cache-1 --alias grafana-query-cache
    docker network connect grafana-cache-test-network $dev_container
    
    # test connection with the grafana cache proxy from devcontainer
    curl -v test-grafana-query-cache-1:8080
    ```
3. Run the tests:
    1. Go to Run and Debug in VS Code.
    2. select `launch integration tests`
    3. click run ▶️

# Run test in ci/cd
```bash
docker compose up -d
sudo docker exec test-integration-test-1 go clean -testcache
sudo docker exec test-integration-test-1 go test ./
```


# Query Requests


## Prometheus

### API
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


### cURL
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


## Timescale/Postgres

### sAPI 
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

### cURL
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
