FROM golang:1.23-alpine AS builder

WORKDIR /app

# Download dependencies first (caching layer)
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
# CGO_ENABLED=0 for statically linked binary
RUN CGO_ENABLED=0 GOOS=linux go build -o bin/gateway ./cmd/gateway

# Final minimal image
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/bin/gateway .

# Add CA certificates for JWKS HTTPS requests
RUN apk --no-cache add ca-certificates

EXPOSE 8080
CMD ["./gateway"]
