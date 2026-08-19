FROM golang:1.27-alpine AS builder
WORKDIR /app
COPY go.mod ./
# Ignore missing go.sum for Docker builds if missing
RUN go mod download || true
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o bin/service ./cmd/workorders

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/bin/service .
EXPOSE 8081
CMD ["./service"]
