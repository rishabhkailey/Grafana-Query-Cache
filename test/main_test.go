package main_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

const (
	commonPromQuery = "irate(prometheus_http_request_duration_seconds_sum[1m]) / prometheus_http_request_duration_seconds_count"
)

func getUniquePrometheusQuery() string {
	// returning commonPromQuery with random comment
	// return commonPromQuery
	return fmt.Sprintf("%s\n #%s", commonPromQuery, randString(10))
}

type config struct {
	grafanaCacheUrl url.URL
	grafanaUser     string
	grafanaPassword string
	minUses         int
}

func getConfig() config {
	cacheUrl := os.Getenv("GRAFANA_CACHE_URL")
	if len(cacheUrl) == 0 {
		log.Fatal("GRAFANA_CACHE_URL not set")
	}
	parsedUrl, err := url.Parse(cacheUrl)
	if err != nil {
		log.Fatal(err)
	}

	grafanaUser := os.Getenv("GF_SECURITY_ADMIN_USER")
	if len(cacheUrl) == 0 {
		log.Fatal("GF_SECURITY_ADMIN_USER not set")
	}

	grafanaPassword := os.Getenv("GF_SECURITY_ADMIN_PASSWORD")
	if len(cacheUrl) == 0 {
		log.Fatal("GF_SECURITY_ADMIN_PASSWORD not set")
	}

	minUsesString := os.Getenv("MIN_REQUEST_COUNT")
	if len(cacheUrl) == 0 {
		log.Fatal("MIN_REQUEST_COUNT not set")
	}
	minUses, err := strconv.ParseInt(minUsesString, 10, 32)
	if len(cacheUrl) == 0 {
		log.Fatal("invalid MIN_REQUEST_COUNT set", minUsesString)
	}

	return config{
		grafanaCacheUrl: *parsedUrl,
		grafanaUser:     grafanaUser,
		grafanaPassword: grafanaPassword,
		minUses:         int(minUses),
	}
}

type datasource struct {
	Type string `json:"type"`
	UID  string `json:"uid"`
}

type prometheusQuery struct {
	DataSource       datasource `json:"datasource"`
	Expr             string     `json:"expr"`
	Range            bool       `json:"range"`
	UtcOffsetSeconds uint       `json:"utcOffsetSec"`
	Interval         string     `json:"interval"`
	IntervalMs       uint       `json:"intervalMs"`
	MaxDataPoints    uint       `json:"maxDataPoints"`
	// RefId            string     `json:"refId"`
	// EditorMode       string     `json:"editorMode"`
	// Instant          bool       `json:"instant"`
	// LegendFormat     string     `json:"legendFormat"`
}

type prometheusRequestBody struct {
	From    string            `json:"from"`
	To      string            `json:"to"`
	Queries []prometheusQuery `json:"queries"`
}

func (config config) sendPrometheusQueryRequest(requestBody prometheusRequestBody) (r *http.Response, err error) {
	requestUrl, err := url.JoinPath(config.grafanaCacheUrl.String(), "/api/ds/query")
	if err != nil {
		return r, fmt.Errorf("unable to join url path: %w", err)
	}
	queryParams := make(url.Values)
	queryParams.Add("ds_type", "prometheus")
	queryParams.Add("requestId", "Q100")

	requestUrl = fmt.Sprintf("%s?%s", requestUrl, queryParams.Encode())

	requestBodyBytes, err := json.Marshal(requestBody)
	if err != nil {
		return r, fmt.Errorf("unable to marshal request body: %w", err)
	}
	{
		body := string(requestBodyBytes)
		fmt.Println(body)
		_ = body
	}
	req, err := http.NewRequest("POST", requestUrl, bytes.NewReader(requestBodyBytes))
	if err != nil {
		return r, fmt.Errorf("unable to create post request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.SetBasicAuth(config.grafanaUser, config.grafanaPassword)

	return http.DefaultClient.Do(req)
}

func TestCacheKeyConsistence(t *testing.T) {

}

func TestMinUses(t *testing.T) {
	config := getConfig()

	timeRange := 30 * time.Minute
	startTime := time.Now()
	promReqBody := prometheusRequestBody{
		From: strconv.FormatInt(startTime.Add(-1*timeRange).UnixMicro(), 10),
		To:   strconv.FormatInt(startTime.UnixMicro(), 10),
		Queries: []prometheusQuery{
			{
				DataSource: datasource{
					Type: "prometheus",
					UID:  "prometheus",
				},
				Expr:             getUniquePrometheusQuery(),
				Range:            true,
				UtcOffsetSeconds: 0,
				Interval:         "",
				IntervalMs:       15000,
				MaxDataPoints:    1200,
			},
		},
	}

	for i := 0; i < config.minUses; i++ {
		response, err := config.sendPrometheusQueryRequest(promReqBody)
		if !assert.NoError(t, err, "minUses") {
			assert.Fail(t, "prometheus query request failed", err)
			return
		}
		if !assert.Equal(t, http.StatusOK, response.StatusCode) {
			assert.Fail(t, fmt.Sprintf("prometheus request return %d status code", response.StatusCode), err)
			return
		}
		if !assert.Equal(t, "MISS", response.Header.Get("X-Cache-Status"), "minUses") {
			assert.Fail(t, "got HIT before min uses for promtheus query request")
			return
		}
	}
	response, err := config.sendPrometheusQueryRequest(promReqBody)
	if !assert.NoError(t, err, "minUses") {
		assert.Fail(t, "prometheus query request failed", err)
		return
	}
	if !assert.Equal(t, http.StatusOK, response.StatusCode) {
		assert.Fail(t, fmt.Sprintf("prometheus request return %d status code", response.StatusCode), err)
		return
	}
	if !assert.Equal(t, "HIT", response.Header.Get("X-Cache-Status"), "minUses") {
		assert.Fail(t, "did not get cache hit after min uses")
		return
	}
}

func TestPrometheusCache(t *testing.T) {

}
