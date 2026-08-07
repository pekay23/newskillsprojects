package proxy

import (
	"net/http"
	"net/http/httputil"
	"net/url"
)

// NewReverseProxy creates a reverse proxy for a target service.
// It strips the mount path before forwarding, if handled by chi's Mount.
func NewReverseProxy(targetURL string) http.Handler {
	if targetURL == "" {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, `{"error": {"code": "SERVICE_UNAVAILABLE", "message": "Downstream service URL not configured"}}`, http.StatusServiceUnavailable)
		})
	}

	target, err := url.Parse(targetURL)
	if err != nil {
		panic("invalid target URL: " + targetURL)
	}

	proxy := httputil.NewSingleHostReverseProxy(target)

	// Preserve the original Host header (often useful for redirects)
	// and ensure the path is correctly appended.
	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)
		req.Header.Set("X-Forwarded-Host", req.Header.Get("Host"))
		req.Host = target.Host
	}

	return proxy
}
