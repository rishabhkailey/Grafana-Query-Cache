package main_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/http/cookiejar"
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

var (
	c *config = nil
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

func init() {
	config := getConfig()
	c = &config
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
	if err != nil {
		log.Fatal(err)
	}
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

func newPrometheusRequestBody(to time.Time, timeRange time.Duration) prometheusRequestBody {
	return prometheusRequestBody{
		From: strconv.FormatInt(to.Add(-1*timeRange).UnixMicro(), 10),
		To:   strconv.FormatInt(to.UnixMicro(), 10),
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
}

type grafanaBasicAuth struct {
	User     string `json:"user"`
	Password string `json:"password"`
}

func (config config) sendPrometheusQueryRequest(
	requestBody prometheusRequestBody,
	basicAuth *grafanaBasicAuth,
	cookieJar *http.CookieJar,
) (r *http.Response, err error) {
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
		// fmt.Println(body)
		_ = body
	}
	req, err := http.NewRequest("POST", requestUrl, bytes.NewReader(requestBodyBytes))
	if err != nil {
		return r, fmt.Errorf("unable to create post request: %w", err)
	}
	if basicAuth != nil {
		req.SetBasicAuth(basicAuth.User, basicAuth.Password)
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	if cookieJar != nil {
		client.Jar = *cookieJar
	}

	return client.Do(req)
}

// HitMinUses will send the request minUses number of time so that the cache is created for the input request body
func HitMinUses(t *testing.T, body prometheusRequestBody) bool {
	for i := 0; i < c.minUses; i++ {
		response, err := c.sendPrometheusQueryRequest(body, &grafanaBasicAuth{
			User:     c.grafanaUser,
			Password: c.grafanaPassword,
		}, nil)
		if !assert.NoError(t, err, "minUses") {
			assert.Fail(t, "prometheus query request failed", err)
			return false
		}
		if !assert.Equal(t, http.StatusOK, response.StatusCode) {
			assert.Fail(t, fmt.Sprintf("prometheus request return %d status code", response.StatusCode), err)
			return false
		}
		if !assert.Equal(t, "MISS", response.Header.Get("X-Cache-Status"), "minUses") {
			assert.Fail(t, "got HIT before min uses for promtheus query request")
			return false
		}
	}
	return true
}

func TestMinUses(t *testing.T) {

	promReqBody := newPrometheusRequestBody(time.Now(), 30*time.Minute)
	if !HitMinUses(t, promReqBody) {
		return
	}
	response, err := c.sendPrometheusQueryRequest(promReqBody, &grafanaBasicAuth{
		User:     c.grafanaUser,
		Password: c.grafanaPassword,
	}, nil)
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

func TestBasicAuth(t *testing.T) {
	// create cache
	promReqBody := newPrometheusRequestBody(time.Now(), 30*time.Minute)
	if !HitMinUses(t, promReqBody) {
		return
	}

	// cache should not be accessible without basic auth
	response, err := c.sendPrometheusQueryRequest(promReqBody, nil, nil)
	if !assert.NoError(t, err, "TestBasicAuth") {
		assert.Fail(t, "prometheus query request failed", err)
		return
	}
	if !assert.Equal(t, http.StatusUnauthorized, response.StatusCode, "TestBasicAuth") {
		assert.Fail(t, fmt.Sprintf("prometheus request return %d status code but expected %d", response.StatusCode, http.StatusUnauthorized), err)
		return
	}

	// cache should be accessible with basic auth
	response, err = c.sendPrometheusQueryRequest(promReqBody, &grafanaBasicAuth{
		User:     c.grafanaUser,
		Password: c.grafanaPassword,
	}, nil)
	if !assert.NoError(t, err, "TestBasicAuth") {
		assert.Fail(t, "prometheus query request failed", err)
		return
	}
	if !assert.Equal(t, http.StatusOK, response.StatusCode, "TestBasicAuth") {
		assert.Fail(t, fmt.Sprintf("prometheus request return %d status code but expected %d", response.StatusCode, http.StatusUnauthorized), err)
		return
	}
	if !assert.Equal(t, "HIT", response.Header.Get("X-Cache-Status"), "TestBasicAuth") {
		assert.Fail(t, "did not get cache hit after min uses")
		return
	}
}

func (c *config) generateGrafanaCookie() (cookieJar http.CookieJar, err error) {
	cookieJar, err = cookiejar.New(nil)
	if err != nil {
		return
	}

	client := &http.Client{
		Jar: cookieJar,
	}

	requestUrl, err := url.JoinPath(c.grafanaCacheUrl.String(), "/login")
	if err != nil {
		return cookieJar, fmt.Errorf("[generateGrafanaCookie] unable to join url path: %w", err)
	}

	loginBodyRequestBytes, err := json.Marshal(&grafanaBasicAuth{
		User:     c.grafanaUser,
		Password: c.grafanaPassword,
	})
	if err != nil {
		return cookieJar, fmt.Errorf("[generateGrafanaCookie] json marshal login body failed: %w", err)
	}

	response, err := client.Post(requestUrl, "application/json", bytes.NewReader(loginBodyRequestBytes))
	if err != nil {
		return
	}
	if response.StatusCode != http.StatusOK {
		return cookieJar, fmt.Errorf("[generateGrafanaCookie]: %d status code", response.StatusCode)
	}
	if len(cookieJar.Cookies(&c.grafanaCacheUrl)) == 0 {
		return cookieJar, fmt.Errorf("[generateGrafanaCookie]: cookie header not present in response")
	}
	return
}

func TestCookieAuth(t *testing.T) {
	cookieJar, err := c.generateGrafanaCookie()
	if !assert.NoError(t, err, "TestCookieAuth") {
		assert.Fail(t, "generateGrafanaCookie failed", err)
		return
	}

	// create cache
	promReqBody := newPrometheusRequestBody(time.Now(), 30*time.Minute)
	if !HitMinUses(t, promReqBody) {
		return
	}

	// cache should not be accessible without basic auth
	response, err := c.sendPrometheusQueryRequest(promReqBody, nil, nil)
	if !assert.NoError(t, err, "TestBasicAuth") {
		assert.Fail(t, "prometheus query request failed", err)
		return
	}
	if !assert.Equal(t, http.StatusUnauthorized, response.StatusCode, "TestBasicAuth") {
		assert.Fail(t, fmt.Sprintf("prometheus request return %d status code but expected %d", response.StatusCode, http.StatusUnauthorized), err)
		return
	}

	// cache should be accessible with cookie auth
	response, err = c.sendPrometheusQueryRequest(promReqBody, nil, &cookieJar)
	if !assert.NoError(t, err, "TestBasicAuth") {
		assert.Fail(t, "prometheus query request failed", err)
		return
	}
	if !assert.Equal(t, http.StatusOK, response.StatusCode, "TestBasicAuth") {
		assert.Fail(t, fmt.Sprintf("prometheus request return %d status code but expected %d", response.StatusCode, http.StatusUnauthorized), err)
		return
	}
	if !assert.Equal(t, "HIT", response.Header.Get("X-Cache-Status"), "TestBasicAuth") {
		assert.Fail(t, "did not get cache hit after min uses")
		return
	}
}

func TestQueryLabels(t *testing.T) {
	tests := []struct {
		name                  string
		queryPrefix           string
		expectedCacheConfigId string
	}{
		{
			name:                  "no-lables",
			queryPrefix:           "",
			expectedCacheConfigId: "default",
		},
		{
			name:                  "valid-labels-01",
			queryPrefix:           "# datasource=timescaledb;\n",
			expectedCacheConfigId: "timescaledb",
		},
		{
			name:                  "valid-labels-02",
			queryPrefix:           "# datasource=prometheus; cacheable=true;\n",
			expectedCacheConfigId: "prometheus",
		},
	}
	for _, test := range tests {
		promReqBody := newPrometheusRequestBody(time.Now(), 30*time.Minute)
		promReqBody.Queries[0].Expr = test.queryPrefix + promReqBody.Queries[0].Expr

		response, err := c.sendPrometheusQueryRequest(promReqBody, &grafanaBasicAuth{
			User:     c.grafanaUser,
			Password: c.grafanaPassword,
		}, nil)
		if !assert.NoError(t, err, "TestBasicAuth") {
			assert.Fail(t, "prometheus query request failed", err)
			return
		}
		if !assert.Equal(t, http.StatusOK, response.StatusCode, "TestBasicAuth") {
			assert.Fail(t, fmt.Sprintf("prometheus request return %d status code but expected %d", response.StatusCode, http.StatusUnauthorized), err)
			return
		}
		if !assert.Equal(t, test.expectedCacheConfigId, response.Header.Get("X-Cache-Config-ID"), "TestBasicAuth") {
			assert.Fail(t, "did not get cache hit after min uses")
			return
		}

	}
}
