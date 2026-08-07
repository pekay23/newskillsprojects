package db

import (
	"database/sql"
	"fmt"

	_ "github.com/mattn/go-sqlite3"
)

type SQLiteDB struct {
	DB *sql.DB
}

func NewSQLiteDB(dbPath string) (*SQLiteDB, error) {
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open sqlite database: %w", err)
	}

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping sqlite database: %w", err)
	}

	// Create sync tracking tables aligned with SYNC-ENGINE-SPEC Section 2.1.
	// The desktop app (Tauri/Rust) creates these same tables in its local.db.
	// The sync agent reads from them and pushes to the gateway.
	schema := `
	CREATE TABLE IF NOT EXISTS _changes (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		entity TEXT NOT NULL,
		entity_id TEXT NOT NULL,
		operation TEXT NOT NULL CHECK(operation IN ('INSERT', 'UPDATE', 'DELETE')),
		payload TEXT NOT NULL DEFAULT '{}',
		client_id TEXT NOT NULL,
		changed_at TEXT NOT NULL,
		synced_at TEXT
	);

	CREATE TABLE IF NOT EXISTS _conflicts (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		entity TEXT NOT NULL,
		entity_id TEXT NOT NULL,
		local_data TEXT NOT NULL DEFAULT '{}',
		remote_data TEXT NOT NULL DEFAULT '{}',
		resolved INTEGER NOT NULL DEFAULT 0,
		created_at TEXT NOT NULL
	);

	CREATE TABLE IF NOT EXISTS _config (
		key TEXT PRIMARY KEY,
		value TEXT NOT NULL
	);

	CREATE TABLE IF NOT EXISTS _sync_state (
		id INTEGER PRIMARY KEY CHECK(id = 1),
		last_pull_at TEXT,
		last_push_at TEXT,
		gateway_url TEXT NOT NULL DEFAULT ''
	);

	INSERT OR IGNORE INTO _sync_state (id, last_pull_at, last_push_at, gateway_url)
	VALUES (1, NULL, NULL, '');
	`
	_, err = db.Exec(schema)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize schema: %w", err)
	}

	return &SQLiteDB{DB: db}, nil
}