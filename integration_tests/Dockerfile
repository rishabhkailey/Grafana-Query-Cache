FROM golang:1.21.5-bookworm
WORKDIR /grafana-query-cache/test
COPY go.mod go.sum ./
RUN go mod download
COPY . ./
