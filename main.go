package main

import (
	"log"
	"net/http"
	"net/url"
	"time"
)

const (
	// MAX_MEMORY_BYTES         = 2 * 1024 * 1024 * 1024
	MAX_MEMORY_BYTES         = 1000000
	MAX_QUERIES              = 1000
	TTL                      = 60 * time.Minute
	MIN_USES                 = 0
	MAX_PER_QUERY_CACHE_SIZE = MAX_MEMORY_BYTES / 10
	UPSTREAM_GRAFANA_URL     = "http://host.docker.internal:3000"
)

var (
	// should be in lowercase.
	// content-length will be automatically added.
	IGNORE_RESPONSE_HEADERS = []string{"date", "cache-control", "content-length"}
)

func main() {
	grafanaUrl, err := url.Parse(UPSTREAM_GRAFANA_URL)
	if err != nil {
		log.Fatal(err)
	}

	cacheProxy := newCacheReverseProxy(cacheReverseProxyOptions{
		ignoreResponseHeaders: IGNORE_RESPONSE_HEADERS,
		OriginUrl:             *grafanaUrl,
		cacheOptions: inMemoryCacheOptions{
			ttl:                TTL,
			maxMemoryBytes:     MAX_MEMORY_BYTES,
			minUses:            MIN_USES,
			maxQueryCacheBytes: MAX_PER_QUERY_CACHE_SIZE,
			maxQueries:         MAX_QUERIES,
		},
	})
	http.HandleFunc("/", cacheProxy.reverseProxy.ServeHTTP)
	http.HandleFunc("/api/ds/query", cacheProxy.GrafanaQueryHandler)

	log.Fatal(http.ListenAndServe(":3333", nil))

}
