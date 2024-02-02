package main_test

// this file only contains config
import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"slices"
	"strconv"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

const (
	commonPromQuery                                = "irate(prometheus_http_request_duration_seconds_sum[1m]) / prometheus_http_request_duration_seconds_count"
	invalidateCacheDisabledScenario                = "invalidate_cache_disabled"
	invalidateCacheEnabledForLocalhostScenario     = "invalidate_cache_enabled_for_localhost"
	invalidateCacheEnabledForDockerNetworkScenario = "invalidate_cache_enabled_for_docker_network"
)

var SUPPORTED_SCENARIOS = []string{
	invalidateCacheDisabledScenario,
	invalidateCacheEnabledForLocalhostScenario,
	invalidateCacheEnabledForDockerNetworkScenario,
}

var (
	c *config = nil
)

func getUniquePrometheusQuery() string {
	// returning commonPromQuery with random comment
	// return commonPromQuery
	return fmt.Sprintf("%s\n #%s", commonPromQuery, randString(10))
}

type config struct {
	grafanaCacheUrl          url.URL
	localGrafanaCacheUrl     url.URL
	grafanaUser              string
	grafanaPassword          string
	minUses                  int
	invalidateCacheEnabled   bool
	invalidateCacheAllowCidr string
	testScenario             string
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
	testScenario := os.Getenv("TEST_SCENARIO")
	if !slices.Contains(SUPPORTED_SCENARIOS, testScenario) {
		log.Fatalf("unsupported \"%s\" test scenario", testScenario)
	}
	localCacheUrl := os.Getenv("LOCAL_GRAFANA_CACHE_URL")
	if len(cacheUrl) == 0 {
		log.Fatal("LOCAL_GRAFANA_CACHE_URL not set")
	}
	localParsedUrl, err := url.Parse(localCacheUrl)
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

	var invalidateCacheEnabled = false
	invalidateCacheEnabledString := os.Getenv("CACHE_INVALIDATE_ENDPOINT_ENABLED")
	if len(invalidateCacheEnabledString) != 0 {
		value, err := strconv.ParseBool(invalidateCacheEnabledString)
		if err != nil {
			fmt.Fprint(os.Stderr, "CACHE_INVALIDATE_ENDPOINT_ENABLED invalid value")
			log.Fatal(err)
		}
		invalidateCacheEnabled = value
	}

	var invalidateCacheAllowCidr = ""
	if invalidateCacheEnabled {
		invalidateCacheAllowCidr = os.Getenv("CACHE_INVALIDATE_ENDPOINT_ALLOW_CIDR")
		if len(invalidateCacheAllowCidr) == 0 {
			log.Fatal("CACHE_INVALIDATE_ENDPOINT_ENABLED not set")
		}
	}

	return config{
		grafanaCacheUrl:          *parsedUrl,
		localGrafanaCacheUrl:     *localParsedUrl,
		grafanaUser:              grafanaUser,
		grafanaPassword:          grafanaPassword,
		minUses:                  int(minUses),
		invalidateCacheEnabled:   invalidateCacheEnabled,
		invalidateCacheAllowCidr: invalidateCacheAllowCidr,
		testScenario:             testScenario,
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
	baseUrl url.URL,
	requestBody prometheusRequestBody,
	basicAuth *grafanaBasicAuth,
	cookieJar *http.CookieJar,
) (r *http.Response, err error) {
	requestUrl, err := url.JoinPath(baseUrl.String(), "/api/ds/query")
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
		response, err := c.sendPrometheusQueryRequest(c.grafanaCacheUrl, body, &grafanaBasicAuth{
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

func (config config) sendInvalidateCacheRequest(baseUrl url.URL) (r *http.Response, err error) {
	client := &http.Client{
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	requestUrl, err := url.JoinPath(baseUrl.String(), "/cache/invalidate")
	if err != nil {
		return nil, fmt.Errorf("unable to join url path: %w", err)
	}
	req, err := http.NewRequest("POST", requestUrl, nil)
	if err != nil {
		return nil, fmt.Errorf("unable to create post request: %w", err)
	}
	return client.Do(req)
}

// copied from - https://stackoverflow.com/questions/22892120/how-to-generate-a-random-string-of-a-fixed-length-in-go/22892986#22892986
var letters = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

func randString(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}

func getTimeStampFromCacheKey(cacheKey string) (t time.Time, err error) {
	r := regexp.MustCompile(`^(?P<version>v[^_])\_(?P<timestamp>\d{10,})\_(?P<properties>(.*))$`)
	match := r.FindStringSubmatch(cacheKey)
	for i, name := range r.SubexpNames() {
		if name == "timestamp" && len(match) > i {
			unixTime, err := strconv.ParseInt(match[i], 10, 64)
			if err != nil {
				return t, fmt.Errorf("conversion to int64 failed: %w", err)
			}
			return time.Unix(unixTime, 0), nil
		}
	}
	return t, fmt.Errorf("not found")
}
