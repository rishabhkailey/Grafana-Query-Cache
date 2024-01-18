
# Recommended Query changes
* use of _time_filter function
* use of now() for current time
* pre defined time ranges

## Todo
* proxy datasources
* use of requestID for cache key instead of request body? (no this cannnot be used, query id doesn't seems to be unique for multiple dashboards)
* support other data sources
* some query requests are get requests e.g. getting lables of prometheus metrics - [check here](https://play.grafana.org/d/bf26a4fb-4c49-44b7-a9f2-8f6f57b4c847/kube-state-metrics-home?orgId=1&refresh=30s)
* handle max data points and interval


## current method support following data sources
* timescale/prometheus
* big query
* prometheus
* elasticsearch
* infinity
* influxdb
* mongodb
* mysql
* redis
* grafana-github-datasource

## Doesn't support
* [graphite](https://play.grafana.org/d/000000011/graphite-carbon-metrics?orgId=1)
* some data source query request doesn't have to and from? [e.g.](https://play.grafana.org/d/de9c9d9a-17f1-4287-9301-d38002be76bf/chained-variable-manipulation-infinity?orgId=1)
* [opentsdb](https://play.grafana.org/d/play-opentsdb-cpu/opentsdb?orgId=1&refresh=1m)