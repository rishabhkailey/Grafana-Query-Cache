package main

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/hashicorp/golang-lru/v2/expirable"
)

// todo create interface for cache
// and impl for inMemory and redis
type inMemoryCache struct {
	usageTracker *usageTracker
	cache        *expirable.LRU[string, cacheValue]
	options      inMemoryCacheOptions
	sizeMutex    sync.RWMutex
	size         int64
}

type inMemoryCacheOptions struct {
	ttl                time.Duration
	maxMemoryBytes     uint64
	maxQueryCacheBytes uint64
	minUses            uint
	maxQueries         uint
}

func newInMemoryCache(options inMemoryCacheOptions) *inMemoryCache {
	inMemoryCache := &inMemoryCache{
		usageTracker: newUsageTracker(12*time.Hour, 10*time.Minute),
		options:      options,
		size:         0,
		sizeMutex:    sync.RWMutex{},
	}

	lruCache := expirable.NewLRU[string, cacheValue](
		int(options.maxQueries),
		func(key string, value cacheValue) {
			for _, schan := range value.stateChangeSubscribers {
				close(schan)
			}
			inMemoryCache.UpdateSize(-1 * value.Size())
		},
		options.ttl,
	)

	// setting later so we can use inMemoryCache object in eviction function
	inMemoryCache.cache = lruCache
	return inMemoryCache
}

func (c *inMemoryCache) InitCache(key string) {

	if c.usageTracker.RecordUsage(key) >= c.options.minUses {
		value := cacheValue{
			status:                 UPDATING,
			stateChangeSubscribers: make(map[uint]chan cacheStatus),
			subscriberMutex:        &sync.RWMutex{},
			lastSubscriberId:       0,
		}
		c.cache.Add(key, value)
	}
}

func (c *inMemoryCache) UpdateSize(change int64) {
	c.sizeMutex.Lock()
	defer c.sizeMutex.Unlock()
	c.size = c.size + change
}

func (c *inMemoryCache) Set(key string, newValue cacheValue) error {
	if c.usageTracker.RecordUsage(key) >= c.options.minUses {
		oldValue, found := c.cache.Get(key)
		if found {
			var sizeDiff int64
			oldValue.subscriberMutex.Lock()
			sizeDiff = newValue.Size() - oldValue.Size()

			_, err := c.evictIfMemoryExceed(sizeDiff)
			if err != nil {
				return fmt.Errorf("[inMemoryCache.set]: failed to save cache in memory: %v", err)
			}

			oldValue.responseBody = newValue.responseBody
			oldValue.responseHeaders = newValue.responseHeaders
			oldValue.status = EXIST
			c.cache.Add(key, oldValue)
			oldValue.subscriberMutex.Unlock()

			c.UpdateSize(sizeDiff)
			oldValue.NotifySubscriber(EXIST)
			return nil
		}
		_, err := c.evictIfMemoryExceed(newValue.Size())
		if err != nil {
			return fmt.Errorf("[inMemoryCache.set]: failed to save cache in memory: %v", err)
		}

		// new cache
		c.InitCache(key)
		newValue.subscriberMutex.Lock()
		newValue.status = EXIST
		c.cache.Add(key, newValue)
		newValue.subscriberMutex.Unlock()

		c.UpdateSize(newValue.Size())
		newValue.NotifySubscriber(EXIST)
	}
	return nil
}

func (c *inMemoryCache) evictIfMemoryExceed(requiredFreeMemory int64) (int64, error) {
	if requiredFreeMemory <= 0 || c.size+requiredFreeMemory <= int64(c.options.maxMemoryBytes) {
		return 0, nil
	}
	if requiredFreeMemory > int64(c.options.maxMemoryBytes) {
		return 0, fmt.Errorf("[inMemoryCache.evictIfMemoryExceed] size of new value is greater than the max memory bytes set")
	}
	var freedMemory int64
	for {
		if c.size+requiredFreeMemory <= int64(c.options.maxMemoryBytes) {
			return freedMemory, nil
		}
		if c.cache.Len() == 0 {
			return freedMemory, fmt.Errorf("[inMemoryCache.evictIfMemoryExceed] all elements evicted still not enough memory available")
		}

		_, removedValue, ok := c.cache.RemoveOldest()
		if !ok {
			return freedMemory, fmt.Errorf("[inMemoryCache.evictIfMemoryExceed] lru.RemoveOldest failed")
		}
		freedMemory += removedValue.Size()
	}
}

func (cache *inMemoryCache) Get(key string) (cacheValue, bool) {
	return cache.cache.Get(key)
}

// if multiple same requests come this will wait for the first request to complete so the rest of requests can be served from cache
func (cache *inMemoryCache) GetWithWait(ctx context.Context, key string, timeout time.Duration) (value cacheValue, found bool, err error) {
	value, found = cache.Get(key)
	if !found {
		return value, found, nil
	}
	if value.status == UPDATING {
		fmt.Printf("[inMemoryCache.GetWithWait] cache with key \"%s\" is updating. waiting...\n", key)
		var newState cacheStatus
		newState, err = value.WaitForStateChange(ctx, timeout)
		if err != nil {
			err = fmt.Errorf("[inMemoryCache.GetWithWait] wait for state change failed: %v", err)
			return
		}

		if newState != EXIST {
			err = fmt.Errorf("[inMemoryCache.GetWithWait] non exist cache state \"%v\"", newState)
			return
		}

		// againg get the cache after state update
		value, found = cache.Get(key)
	}

	return
}

type usageData struct {
	uses     uint
	lastUsed time.Time
}

// todo usage of time buckets for tracking time?
// similar to expirable.lru
// or sorted array of keys and we can do binary search on time?
type usageTracker struct {
	dataMap        map[string]usageData
	maxTimeForKeys time.Duration
	mutex          sync.RWMutex
}

func newUsageTracker(maxTimeForKeys time.Duration, exiperdKeyEvaluationInterval time.Duration) (ut *usageTracker) {
	ut = &usageTracker{
		dataMap:        map[string]usageData{},
		maxTimeForKeys: maxTimeForKeys,
		mutex:          sync.RWMutex{},
	}
	go func() {
		for t := range time.Tick(exiperdKeyEvaluationInterval) {
			fmt.Printf("%v: running old keys cleanup\n", t)
			ut.mutex.Lock()
			for key, value := range ut.dataMap {
				if (t.Unix() - value.lastUsed.Unix()) > int64(ut.maxTimeForKeys.Seconds()) {
					delete(ut.dataMap, key)
				}
			}
			ut.mutex.Unlock()
		}
	}()
	return ut
}

func (ut *usageTracker) RecordUsage(key string) uint {
	ut.mutex.Lock()
	defer ut.mutex.Unlock()
	ud, found := ut.dataMap[key]
	if !found {
		ut.dataMap[key] = usageData{
			uses:     1,
			lastUsed: time.Now(),
		}
		return 1
	}
	ud.lastUsed = time.Now()
	ud.uses++
	ut.dataMap[key] = ud
	return ud.uses
}

// it does not record usage
func (ut *usageTracker) GetUses(key string) uint {
	ut.mutex.RLock()
	defer ut.mutex.RUnlock()
	if ud, found := ut.dataMap[key]; found {
		return ud.uses
	}
	return 0
}
