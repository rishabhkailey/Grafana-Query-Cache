package main_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestMinUses(t *testing.T) {
	promReqBody := newPrometheusRequestBody(time.Now(), 30*time.Minute)
	if !HitMinUses(t, promReqBody) {
		return
	}
	response, err := c.sendPrometheusQueryRequest(c.grafanaCacheUrl, promReqBody, &grafanaBasicAuth{
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
	response, err := c.sendPrometheusQueryRequest(c.grafanaCacheUrl, promReqBody, nil, nil)
	if !assert.NoError(t, err, "TestBasicAuth") {
		assert.Fail(t, "prometheus query request failed", err)
		return
	}
	if !assert.Equal(t, http.StatusUnauthorized, response.StatusCode, "TestBasicAuth") {
		assert.Fail(t, fmt.Sprintf("prometheus request return %d status code but expected %d", response.StatusCode, http.StatusUnauthorized), err)
		return
	}

	// cache should be accessible with basic auth
	response, err = c.sendPrometheusQueryRequest(c.grafanaCacheUrl, promReqBody, &grafanaBasicAuth{
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
	response, err := c.sendPrometheusQueryRequest(c.grafanaCacheUrl, promReqBody, nil, nil)
	if !assert.NoError(t, err, "TestBasicAuth") {
		assert.Fail(t, "prometheus query request failed", err)
		return
	}
	if !assert.Equal(t, http.StatusUnauthorized, response.StatusCode, "TestBasicAuth") {
		assert.Fail(t, fmt.Sprintf("prometheus request return %d status code but expected %d", response.StatusCode, http.StatusUnauthorized), err)
		return
	}

	// cache should be accessible with cookie auth
	response, err = c.sendPrometheusQueryRequest(c.grafanaCacheUrl, promReqBody, nil, &cookieJar)
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

		response, err := c.sendPrometheusQueryRequest(c.grafanaCacheUrl, promReqBody, &grafanaBasicAuth{
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

// scenario based tests
func TestInvalidateCacheEndpointAllowCidr(t *testing.T) {
	switch c.testScenario {
	case invalidateCacheDisabledScenario:
		{
			t.Log("TestInvalidateCacheEndpoint disabled")
			response, err := c.sendInvalidateCacheRequest(c.grafanaCacheUrl)
			if !assert.NoError(t, err, "TestInvalidateCacheEndpoint disabled") {
				assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: unexpected error")
				return
			}

			// redirect to login page by grafana
			if !assert.Equal(t, http.StatusFound, response.StatusCode) {
				assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: TestInvalidateCacheEndpoint disabled, got invalid status codes")
				return
			}
			return
		}
	case invalidateCacheEnabledForLocalhostScenario:
		{
			t.Log("TestInvalidateCacheEndpoint enabled for local network")
			// only local should work
			response, err := c.sendInvalidateCacheRequest(c.grafanaCacheUrl)
			if !assert.NoError(t, err, "TestInvalidateCacheEndpoint disabled") {
				assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: unexpected error")
				return
			}
			if !assert.Equal(t, http.StatusForbidden, response.StatusCode) {
				assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: TestInvalidateCacheEndpoint disabled, got invalid status codes")
				return
			}

			response, err = c.sendInvalidateCacheRequest(c.localGrafanaCacheUrl)
			if !assert.NoError(t, err, "TestInvalidateCacheEndpoint disabled") {
				assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: unexpected error")
				return
			}
			if !assert.Equal(t, http.StatusOK, response.StatusCode) {
				assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: TestInvalidateCacheEndpoint disabled, got invalid status code for local url")
				return
			}
			return
		}
	case invalidateCacheEnabledForDockerNetworkScenario:
		{
			t.Log("TestInvalidateCacheEndpoint enabled for docker network")
			// only docker network should work
			response, err := c.sendInvalidateCacheRequest(c.grafanaCacheUrl)
			if !assert.NoError(t, err, "TestInvalidateCacheEndpoint disabled") {
				assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: unexpected error")
				return
			}
			if !assert.Equal(t, http.StatusOK, response.StatusCode) {
				assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: TestInvalidateCacheEndpoint disabled, got invalid status codes")
				return
			}

			response, err = c.sendInvalidateCacheRequest(c.localGrafanaCacheUrl)
			if !assert.NoError(t, err, "TestInvalidateCacheEndpoint disabled") {
				assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: unexpected error")
				return
			}
			if !assert.Equal(t, http.StatusForbidden, response.StatusCode) {
				assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: TestInvalidateCacheEndpoint disabled, got invalid status code for local url")
				return
			}
			return
		}
	default:
		assert.Fail(t, "[TestInvalidateCacheEndpointAllowCidr]: invalid scenario")
		return
	}
}

func TestInvalidateCacheEndpoint(t *testing.T) {
	var cacheProxyUrl url.URL
	switch c.testScenario {
	case invalidateCacheDisabledScenario:
		return
	case invalidateCacheEnabledForLocalhostScenario:
		cacheProxyUrl = c.localGrafanaCacheUrl
	case invalidateCacheEnabledForDockerNetworkScenario:
		cacheProxyUrl = c.grafanaCacheUrl
	default:
		assert.Fail(t, "invalid scenario")
		return
	}

	// get cache key before invalidate cache
	promReqBody := newPrometheusRequestBody(time.Now(), 30*time.Minute)
	response, err := c.sendPrometheusQueryRequest(cacheProxyUrl, promReqBody, &grafanaBasicAuth{
		User:     c.grafanaUser,
		Password: c.grafanaPassword,
	}, nil)
	if !assert.NoError(t, err, "TestInvalidateCacheEndpoint") {
		assert.Fail(t, "prometheus query request failed", err)
		return
	}
	if !assert.Equal(t, http.StatusOK, response.StatusCode) {
		assert.Fail(t, fmt.Sprintf("prometheus request return %d status code", response.StatusCode), err)
		return
	}
	cacheKeyBefore := response.Header.Get("X-Cache-Key")
	if !assert.NotEqual(t, cacheKeyBefore, "", "cache key before invalidate") {
		assert.Fail(t, "empty cache key in response")
		return
	}
	timeBeforeInvalidateRequest := time.Now()

	// wait for 5 seconds so the time actual changes
	time.Sleep(1 * time.Second)

	// invalidate cache
	response, err = c.sendInvalidateCacheRequest(cacheProxyUrl)
	timeAfterInvalidateRequest := time.Now()
	if !assert.NoError(t, err) {
		assert.Fail(t, "unexpected error")
		return
	}
	if !assert.Equal(t, http.StatusOK, response.StatusCode) {
		assert.Fail(t, "got invalid status codes")
		return
	}

	// get cache key after invalidate cache
	response, err = c.sendPrometheusQueryRequest(cacheProxyUrl, promReqBody, &grafanaBasicAuth{
		User:     c.grafanaUser,
		Password: c.grafanaPassword,
	}, nil)
	if !assert.NoError(t, err, "TestInvalidateCacheEndpoint") {
		assert.Fail(t, "prometheus query request failed", err)
		return
	}
	if !assert.Equal(t, http.StatusOK, response.StatusCode) {
		assert.Fail(t, fmt.Sprintf("prometheus request return %d status code", response.StatusCode), err)
		return
	}
	cacheKeyAfter := response.Header.Get("X-Cache-Key")
	if !assert.NotEqual(t, cacheKeyAfter, "", "cache key after invalidate") {
		assert.Fail(t, "empty cache key in response")
		return
	}

	// test new cache key
	if !assert.NotEqual(t, cacheKeyAfter, "", "cache key after invalidate") {
		assert.Fail(t, "empty cache key in response")
		return
	}
	if !assert.NotEqual(t, cacheKeyBefore, cacheKeyAfter) {
		assert.Fail(t, "cacheKey did not change after invalidate call")
		return
	}
	cacheKeyAfterTimeStamp, err := getTimeStampFromCacheKey(cacheKeyAfter)
	if !assert.NoError(t, err, "getTimeStampFromCacheKey") {
		assert.Fail(t, "unexpected error")
		return
	}
	t.Log("cacheKeyAfterTimeStamp", cacheKeyAfterTimeStamp)
	t.Log("timeBeforeInvalidateRequest", timeBeforeInvalidateRequest)
	if !assert.True(t, cacheKeyAfterTimeStamp.After(timeBeforeInvalidateRequest), "After") {
		assert.Fail(t, "invalid cache key timestamp")
		return
	}
	if !assert.True(t, cacheKeyAfterTimeStamp.Before(timeAfterInvalidateRequest), "Before") {
		assert.Fail(t, "invalid cache key timestamp")
		return
	}
}
