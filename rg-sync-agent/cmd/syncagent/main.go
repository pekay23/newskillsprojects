package main

import (
	"log"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"rg-sync-agent/internal/db"
	"rg-sync-agent/internal/sync"
)

func main() {
	// Setup Local SQLite Database
	// The desktop app (Tauri/Rust) passes RG_DB_PATH pointing to its local.db
	dbPath := os.Getenv("RG_DB_PATH")
	if dbPath == "" {
		dbPath = os.Getenv("LOCAL_DB_PATH") // fallback to legacy name
	}
	if dbPath == "" {
		dbPath = "./local_sync.db"
	}

	sqliteDB, err := db.NewSQLiteDB(dbPath)
	if err != nil {
		log.Fatalf("Failed to initialize SQLite: %v", err)
	}
	defer sqliteDB.DB.Close()

	// Setup API Client pointing to our API Gateway
	// The desktop app passes RG_GATEWAY_URL (e.g. http://localhost:8080)
	apiBaseURL := os.Getenv("RG_GATEWAY_URL")
	if apiBaseURL == "" {
		apiBaseURL = os.Getenv("API_GATEWAY_URL") // fallback to legacy name
	}
	if apiBaseURL == "" {
		apiBaseURL = "http://localhost:8080"
	}

	// Auth token (JWT) passed by the desktop app's Rust backend
	authToken := os.Getenv("RG_AUTH_TOKEN")
	if authToken == "" {
		authToken = os.Getenv("SYNC_AUTH_TOKEN") // fallback to legacy name
	}

	client := sync.NewAPIClient(apiBaseURL, authToken)

	// Poll interval from the desktop app (default 500ms per SYNC-ENGINE-SPEC)
	pollInterval := 500 * time.Millisecond
	if v := os.Getenv("RG_POLL_INTERVAL_MS"); v != "" {
		if ms, err := strconv.Atoi(v); err == nil && ms > 0 {
			pollInterval = time.Duration(ms) * time.Millisecond
		}
	}

	// Start Sync Manager
	manager := sync.NewSyncManager(sqliteDB, client)
	manager.Start(pollInterval)

	log.Printf("Sync Agent is running (gateway=%s, db=%s, poll=%v). Press Ctrl+C to exit.", apiBaseURL, dbPath, pollInterval)

	// Wait for interrupt
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down Sync Agent...")
}