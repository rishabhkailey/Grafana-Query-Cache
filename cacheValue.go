package main

import (
	"context"
	"fmt"
	"sync"
	"time"
)

type cacheStatus uint8

const (
	INITIALIZING cacheStatus = 0
	EXIST        cacheStatus = 1
	UPDATING     cacheStatus = 2
	EXPIRED      cacheStatus = 3
	FAILED       cacheStatus = 4
)

type cacheValue struct {
	responseBody           []byte
	responseHeaders        []byte
	status                 cacheStatus
	subscriberMutex        *sync.RWMutex
	stateChangeSubscribers map[uint]chan cacheStatus
	lastSubscriberId       uint
}

func (c *cacheValue) WaitForStateChange(ctx context.Context, timeout time.Duration) (state cacheStatus, err error) {
	sid, schan := c.newStateChangeSubscriber()
	defer c.removeStateChangeSubscriber(sid)

	select {
	case state = <-schan:
		return
	case <-ctx.Done():
		return state, fmt.Errorf("context completed")
	case <-time.NewTimer(timeout).C:
		return state, fmt.Errorf("timedout")
	}
}

func (c *cacheValue) newStateChangeSubscriber() (sid uint, channel <-chan cacheStatus) {
	c.subscriberMutex.Lock()
	defer c.subscriberMutex.Unlock()

	c.lastSubscriberId++
	sid = c.lastSubscriberId
	newChannel := make(chan cacheStatus)
	c.stateChangeSubscribers[sid] = newChannel
	return sid, newChannel
}

func (c *cacheValue) removeStateChangeSubscriber(sid uint) {
	c.subscriberMutex.Lock()
	defer c.subscriberMutex.Unlock()

	if channel, found := c.stateChangeSubscribers[sid]; found {
		close(channel)
		delete(c.stateChangeSubscribers, sid)
	}
}

func (c *cacheValue) NotifySubscriber(state cacheStatus) {
	for _, schan := range c.stateChangeSubscribers {
		schan <- state
	}
}

func (c *cacheValue) Size() int64 {
	return int64(len(c.responseBody) + len(c.responseHeaders))
}
