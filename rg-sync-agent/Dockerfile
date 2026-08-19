# Build stage
FROM golang:1.23 AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o rg-sync-agent ./cmd/syncagent

# Runtime stage
FROM alpine:3.24
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /build/rg-sync-agent /app/rg-sync-agent
ENTRYPOINT ["/app/rg-sync-agent"]