package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"slices"
	"strconv"
	"strings"
	"time"
)

type cacheReverseProxy struct {
	grafanaUrl   url.URL
	reverseProxy httputil.ReverseProxy
	cache        *inMemoryCache
	options      cacheReverseProxyOptions
}

// todo filter using request body?
// clear cache endpoint? with grafana auth :p
// regex?
type cacheReverseProxyOptions struct {
	ignoreResponseHeaders []string
	OriginUrl             url.URL
	cacheOptions          inMemoryCacheOptions
}

func newCacheReverseProxy(options cacheReverseProxyOptions) *cacheReverseProxy {
	reverseProxy := httputil.NewSingleHostReverseProxy(&options.OriginUrl)
	return &cacheReverseProxy{
		grafanaUrl:   options.OriginUrl,
		reverseProxy: *reverseProxy,
		cache:        newInMemoryCache(options.cacheOptions),
		options:      options,
	}
}

func (c *cacheReverseProxy) GrafanaQueryHandler(w http.ResponseWriter, r *http.Request) {
	served, cacheKey := c.serveRequestFromCache(w, r)
	if served {
		return
	}
	c.serveRequestFromUpstreamAndCacheResponse(w, r, cacheKey)
}

func (c *cacheReverseProxy) serveRequestFromCache(w http.ResponseWriter, r *http.Request) (served bool, cacheKey string) {
	served = false
	cacheKey, dataSourceUids, err := parsegrafanaQueryRequestBody(r)
	if err != nil {
		fmt.Println("[cacheReverseProxy.serveRequestFromCache] failed to get cache key", err)
		return
	}
	if len(cacheKey) == 0 && len(dataSourceUids) == 0 {
		fmt.Println("[cacheReverseProxy.serveRequestFromCache] empty cache key or data source uids")
		return
	}
	cacheData, found, err := c.cache.GetWithWait(r.Context(), cacheKey, 5*time.Minute)
	if err != nil {
		fmt.Println("[cacheReverseProxy.serveRequestFromCache] failed to get the cache: %w", err)
		return
	}
	if !found {
		fmt.Println("[cacheReverseProxy.serveRequestFromCache] cache not found")
		return
	}
	err = c.checkUserAccess(dataSourceUids, r)
	if err != nil {
		fmt.Println("[cacheReverseProxy.serveRequestFromCache] user access check failed: %w", err)
		return
	}
	var cachedResponseHeaders http.Header
	err = json.Unmarshal(cacheData.responseHeaders, &cachedResponseHeaders)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[cacheReverseProxy.serveRequestFromCache] failed to unmarshal cached headers: %v", err)
		return
	}

	// serve_cached_content
	{
		for key, values := range cachedResponseHeaders {
			for _, value := range values {
				w.Header().Add(key, value)
			}
		}
		// todo remove this
		w.Header().Add("X-Cache-Status", "HIT")
		_, err = w.Write(cacheData.responseBody)

		if err != nil {
			fmt.Fprintf(os.Stderr, "[cacheReverseProxy.serveRequestFromCache] failed to write response from cache: %v", err)
			w.WriteHeader(http.StatusBadGateway)
			return true, cacheKey
		}
	}
	return true, cacheKey
}

func (c *cacheReverseProxy) serveRequestFromUpstreamAndCacheResponse(w http.ResponseWriter, r *http.Request, cacheKey string) {
	c.cache.InitCache(cacheKey)
	responseRecoreder := newResponseRecorder(w)
	c.reverseProxy.ServeHTTP(responseRecoreder, r)

	if responseRecoreder.status == http.StatusOK {
		responseHeaders := w.Header().Clone()
		{
			for key := range responseHeaders {
				if slices.Contains(c.options.ignoreResponseHeaders, strings.ToLower(key)) {
					responseHeaders.Del(key)
				}
			}
		}

		responseHeadersBytes, err := json.Marshal(responseHeaders)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[cacheReverseProxy.serveRequestFromUpstreamAndCacheResponse] failed to marshal response headers: %v", err)
			return
		}

		err = c.cache.Set(cacheKey, cacheValue{
			responseBody:    responseRecoreder.responseBytes,
			responseHeaders: responseHeadersBytes,
		})
		fmt.Fprintf(os.Stderr, "[cacheReverseProxy.serveRequestFromUpstreamAndCacheResponse] failed to save response in cache: %v", err)
	}
}

func (c *cacheReverseProxy) checkUserAccess(dataSourceUids []string, r *http.Request) (err error) {
	headers := make(http.Header)
	for _, cookieHeaderValue := range r.Header.Values("Cookie") {
		headers.Add("Cookie", cookieHeaderValue)
	}
	for _, cookieHeaderValue := range r.Header.Values("Authorization") {
		headers.Add("Authorization", cookieHeaderValue)
	}

	for _, dataSourceUid := range dataSourceUids {
		request, _ := http.NewRequestWithContext(
			r.Context(),
			"GET",
			c.grafanaUrl.JoinPath(
				fmt.Sprintf("/api/datasources/uid/%s/health", dataSourceUid),
			).String(),
			nil,
		)

		request.Header = headers
		response, err := http.DefaultClient.Do(request)
		if err != nil {
			return fmt.Errorf("[cacheReverseProxy.checkUserAccess] user access request failed: %w", err)
		}
		if response.StatusCode != http.StatusOK {
			return fmt.Errorf("[cacheReverseProxy.checkUserAccess] non 200 status code received: status code = %d", response.StatusCode)
		}
	}
	return
}

// to and from will be in milliseconds
type grafanaQueryRequest struct {
	To      string        `json:"to" form:"to"`
	From    string        `json:"from" form:"from"`
	Queries []interface{} `json:"queries" form:"queries"`
}

const (
	// 30 MINUTES
	TIME_BUCKET_LENGTH_MS = 30 * 60 * 1000
	// 10 MINUTES
	TIME_RANGE_BUCKET_LENGTH_MS = 10 * 60 * 1000
)

func parsegrafanaQueryRequestBody(r *http.Request) (cacheKey string, dataSourceUids []string, err error) {
	bodyReader := r.Body
	if bodyReader == nil {
		err = fmt.Errorf("[parsegrafanaQueryRequestBody]: got nil request body reader. request might not be a post request")
		return
	}
	bodyBytes, err := io.ReadAll(bodyReader)
	if err != nil {
		err = fmt.Errorf("[parsegrafanaQueryRequestBody]: failed to read request body: %w", err)
		return
	}
	r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
	var requestBody grafanaQueryRequest
	if err = json.Unmarshal(bodyBytes, &requestBody); err != nil {
		err = fmt.Errorf("[parsegrafanaQueryRequestBody]: failed to unmarshal json request body: %w", err)
		return
	}

	if len(requestBody.To) == 0 || len(requestBody.From) == 0 || len(requestBody.Queries) == 0 {
		err = fmt.Errorf(
			"[parsegrafanaQueryRequestBody]: invalid request body, len(to) = \"%d\", len(from) = \"%d\" and queries == nil = %v",
			len(requestBody.To),
			len(requestBody.From),
			len(requestBody.Queries) == 0,
		)
		return
	}
	dataSourceUids, err = getDataSourceFromRequestBody(requestBody)
	if err != nil {
		err = fmt.Errorf("[parsegrafanaQueryRequestBody] failed to get data source uids: %w", err)
		return
	}
	cacheKey, err = getCacheKeyFromRequestBody(requestBody)
	if err != nil {
		err = fmt.Errorf("[parsegrafanaQueryRequestBody] failed to get cache key: %w", err)
		return
	}
	return
}

func getCacheKeyFromRequestBody(requestBody grafanaQueryRequest) (cacheKey string, err error) {
	var to, from int64
	{
		if to, err = strconv.ParseInt(requestBody.To, 10, 64); err != nil {
			return "", fmt.Errorf("[getCacheKeyFromRequestBody] invalid request to value \"%s\" in request body: %w", requestBody.To, err)
		}
		if from, err = strconv.ParseInt(requestBody.From, 10, 64); err != nil {
			return "", fmt.Errorf("[getCacheKeyFromRequestBody] invalid request from value \"%s\" in request body: %w", requestBody.From, err)
		}
	}

	var queries string
	{
		queriesBytes, err := json.Marshal(requestBody.Queries)
		if err != nil {
			return "", fmt.Errorf("[getCacheKeyFromRequestBody] failed to marshal request queries: %w", err)
		}
		queries = string(queriesBytes)
	}

	timeBucketNumber := int(math.Floor(
		float64(to) / TIME_BUCKET_LENGTH_MS,
	))

	timeRangeBucketNumber := int(math.Floor(
		float64(to-from) / TIME_RANGE_BUCKET_LENGTH_MS,
	))

	queriesHash := getMd5(queries)

	return fmt.Sprintf("time_bucket_number=%d;time_range_bucket_number=%d;queries_hash=%s", timeBucketNumber, timeRangeBucketNumber, queriesHash), nil
}

type grafanaQuery struct {
	DataSource struct {
		Type string `json:"type"`
		Uid  string `json:"uid"`
	} `json:"datasource"`
}

func getDataSourceFromRequestBody(body grafanaQueryRequest) ([]string, error) {
	var dataSourceUids []string
	{
		for _, query := range body.Queries {
			parsedQuery, err := convertToType[grafanaQuery](query)
			if err != nil || len(parsedQuery.DataSource.Uid) == 0 {
				return dataSourceUids, fmt.Errorf("[getDataSourceFromRequestBody] query type conversion failed: %w", err)
			}

			dataSourceUids = append(dataSourceUids, parsedQuery.DataSource.Uid)
		}
	}
	return dataSourceUids, nil
}
