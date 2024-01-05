package main

import "net/http"

type responseRecorder struct {
	responseBytes []byte
	status        int
	http.ResponseWriter
}

func newResponseRecorder(w http.ResponseWriter) *responseRecorder {
	return &responseRecorder{
		ResponseWriter: w,
	}
}

func (c *responseRecorder) Header() http.Header {
	return c.ResponseWriter.Header()
}

func (c *responseRecorder) Write(data []byte) (int, error) {
	c.responseBytes = append(c.responseBytes, data...)
	return c.ResponseWriter.Write(data)
}

func (c *responseRecorder) WriteHeader(i int) {
	c.status = i
	c.ResponseWriter.WriteHeader(i)
}
