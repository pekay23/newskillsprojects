package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/redis/go-redis/v9"

	"rg-workorder-service/internal/handlers"
	"rg-workorder-service/internal/repository"
	"rg-workorder-service/internal/sla"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8081" // Backend service runs on 8081
	}

	// 1. Initialize Neon PostgreSQL
	dsn := os.Getenv("NEON_URL")
	if dsn == "" {
		log.Fatal("NEON_URL environment variable is required")
	}

	db, err := repository.NewPostgresDB(dsn)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}

	// 1b. Run migrations / create indexes (SLA composite index for fast queries)
	if err := repository.Migrate(db); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// 2. Initialize Redis (for Pub/Sub and caching)
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "redis://localhost:6379"
	}
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("Failed to parse Redis URL: %v", err)
	}
	redisClient := redis.NewClient(opts)

	// 3. Initialize Repositories and Handlers
	repo := &repository.WorkOrderRepo{DB: db}
	handler := &handlers.WorkOrderHandler{Repo: repo}

	// 4. Start SLA Background Engine
	slaEngine := sla.NewEngine(db, redisClient)
	slaEngine.Start(context.Background())

	// 5. Setup Router
	r := chi.NewRouter()

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"status":"ok", "service":"workorder"}`))
	})

	// Note: The API Gateway mounts this service under `/api/v1/workorders`, 
	// so the root `/` here equates to that path.
	r.Route("/", func(r chi.Router) {
		r.Get("/", handler.List)
		r.Post("/", handler.Create)
		r.Get("/{id}", handler.Get)
	})

	log.Printf("Work Order Service running on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
