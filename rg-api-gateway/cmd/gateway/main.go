package main

import (
	"log"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"rg-api-gateway/internal/auth"
	"rg-api-gateway/internal/proxy"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	r := chi.NewRouter()

	// Base middleware
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	// Health checks
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status": "ok", "service": "api-gateway", "version": "1.0.0"}`))
	})
	r.Get("/ready", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		// In a real scenario, check connections to Redis/Downstream
		w.Write([]byte(`{"status": "ok"}`))
	})

	// Auth Middleware Setup — validates NextAuth v5 JWTs (HS256 + NEXTAUTH_SECRET).
	// The original platform migrated from Supabase auth to NextAuth v5 (JWT strategy),
	// backed by Neon PostgreSQL via Prisma.
	authMiddleware, err := auth.NewJWTMiddleware()
	if err != nil {
		log.Printf("Failed to initialize JWT middleware (NEXTAUTH_SECRET not set): %v", err)
	}

	// Public login endpoint - validates credentials against the Neon DB and issues a JWT.
	// The desktop app posts to /api/auth/callback/credentials.
	r.Post("/api/auth/callback/credentials", auth.LoginHandler())

	// Protected Routes
	r.Group(func(r chi.Router) {
		if authMiddleware != nil {
			r.Use(authMiddleware.RequireAuth)
		}

		// Mount downstream services via reverse proxy
		r.Mount("/api/v1/workorders", proxy.NewReverseProxy(os.Getenv("WORKORDER_URL")))
		r.Mount("/api/v1/assets", proxy.NewReverseProxy(os.Getenv("CMMS_URL")))
		r.Mount("/api/v1/helpdesk", proxy.NewReverseProxy(os.Getenv("HELPDESK_URL")))
		r.Mount("/api/v1/reports", proxy.NewReverseProxy(os.Getenv("REPORTS_URL")))

		// Sync endpoints per SYNC-ENGINE-SPEC Section 4.
		// The desktop sync agent POSTs to /sync/{service} where service is
		// one of: workorders, cmms, helpdesk. Route to the matching backend.
		r.Mount("/sync/workorders", proxy.NewReverseProxy(os.Getenv("WORKORDER_URL")))
		r.Mount("/sync/cmms", proxy.NewReverseProxy(os.Getenv("CMMS_URL")))
		r.Mount("/sync/helpdesk", proxy.NewReverseProxy(os.Getenv("HELPDESK_URL")))
	})

	log.Printf("API Gateway starting on port %s", port)
	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Fatal(err)
	}
}
