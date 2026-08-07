package sync

import (
	"encoding/json"
	"log"
	"time"

	"rg-sync-agent/internal/db"
)

// ChangeRecord mirrors the SYNC-ENGINE-SPEC Section 2.1 _changes row.
type ChangeRecord struct {
	ID        int64           `json:"id"`
	Entity    string          `json:"entity"`
	EntityID  string          `json:"entity_id"`
	Operation string          `json:"operation"`
	Payload   json.RawMessage `json:"payload"`
	ClientID  string          `json:"client_id"`
	ChangedAt string          `json:"changed_at"`
	SyncedAt  *string         `json:"synced_at,omitempty"`
}

type SyncManager struct {
	DB     *db.SQLiteDB
	Client *APIClient
}

func NewSyncManager(database *db.SQLiteDB, client *APIClient) *SyncManager {
	return &SyncManager{
		DB:     database,
		Client: client,
	}
}

func (m *SyncManager) Start(interval time.Duration) {
	log.Printf("Starting Sync Manager, polling every %v...", interval)
	ticker := time.NewTicker(interval)
	go func() {
		for range ticker.C {
			m.performPush()
			m.performPull()
		}
	}()
}

// performPush reads unsynced rows from the spec-compliant _changes table
// and pushes them to the gateway's /sync/{service} endpoint.
func (m *SyncManager) performPush() {
	rows, err := m.DB.DB.Query(
		"SELECT id, entity, entity_id, operation, payload, client_id, changed_at, synced_at " +
			"FROM _changes WHERE synced_at IS NULL ORDER BY id ASC LIMIT 50",
	)
	if err != nil {
		log.Printf("Error querying changes: %v", err)
		return
	}
	defer rows.Close()

	var changes []ChangeRecord
	var idsToMark []int64

	for rows.Next() {
		var c ChangeRecord
		var payloadStr string
		var syncedAt *string
		if err := rows.Scan(&c.ID, &c.Entity, &c.EntityID, &c.Operation, &payloadStr, &c.ClientID, &c.ChangedAt, &syncedAt); err == nil {
			c.Payload = json.RawMessage(payloadStr)
			c.SyncedAt = syncedAt
			changes = append(changes, c)
			idsToMark = append(idsToMark, c.ID)
		}
	}

	if len(changes) == 0 {
		return // Nothing to push
	}

	log.Printf("Pushing %d changes to remote...", len(changes))
	err = m.Client.PushChanges(changes)
	if err != nil {
		log.Printf("Failed to push changes: %v", err)
		return
	}

	// Mark as synced
	now := time.Now().UTC().Format(time.RFC3339)
	for _, id := range idsToMark {
		m.DB.DB.Exec("UPDATE _changes SET synced_at = ? WHERE id = ?", now, id)
	}
	m.DB.DB.Exec("UPDATE _sync_state SET last_push_at = ? WHERE id = 1", now)
	log.Printf("Successfully synced %d records.", len(changes))
}

func (m *SyncManager) performPull() {
	// To be implemented: fetch changes from remote since last sync timestamp
	// and update local SQLite database, generating conflicts in _conflicts table
	// if local modifications exist.
}