use rusqlite::{params, Connection, Result as SqliteResult};
use std::path::PathBuf;
use std::sync::Mutex;
use uuid::Uuid;
use chrono::Utc;

use crate::models::{
    Asset, ChangeRecord, HelpdeskRequest, NewAsset, NewHelpdeskRequest, NewWorkOrder,
    SyncConflict, SyncStatus, UpdateWorkOrder, WorkOrder,
};

/// Thread-safe database handle.
pub struct Database {
    pub conn: Mutex<Connection>,
}

impl Database {
    /// Open or create the SQLite database at the given path.
    /// Initializes schema if this is a fresh database.
    pub fn open(db_path: PathBuf) -> SqliteResult<Self> {
        // Ensure the parent directory exists
        if let Some(parent) = db_path.parent() {
            std::fs::create_dir_all(parent).ok();
        }

        let conn = Connection::open(&db_path)?;

        // Enable WAL mode for better concurrent access
        conn.execute_batch("PRAGMA journal_mode=WAL;")?;
        conn.execute_batch("PRAGMA foreign_keys=ON;")?;

        let db = Database {
            conn: Mutex::new(conn),
        };
        db.initialize_schema()?;
        db.ensure_client_id()?;
        Ok(db)
    }

    /// Initialize all application tables and sync tracking tables.
    fn initialize_schema(&self) -> SqliteResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(
            "
            -- Application tables
            CREATE TABLE IF NOT EXISTS work_orders (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'pending',
                priority TEXT NOT NULL DEFAULT 'medium',
                assigned_to TEXT,
                created_by TEXT NOT NULL,
                property_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted_at TEXT
            );

            CREATE TABLE IF NOT EXISTS assets (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                asset_type TEXT NOT NULL,
                location TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'operational',
                property_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted_at TEXT
            );

            CREATE TABLE IF NOT EXISTS helpdesk_requests (
                id TEXT PRIMARY KEY,
                subject TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'open',
                priority TEXT NOT NULL DEFAULT 'medium',
                resident_name TEXT NOT NULL,
                unit TEXT NOT NULL,
                property_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted_at TEXT
            );

            -- Sync engine tracking tables (per SYNC-ENGINE-SPEC Section 2.1)
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
            ",
        )?;
        Ok(())
    }

    /// Ensure a client_id exists in _config (per SYNC-ENGINE-SPEC Section 2.2).
    fn ensure_client_id(&self) -> SqliteResult<()> {
        let conn = self.conn.lock().unwrap();
        let exists: bool = conn
            .query_row(
                "SELECT COUNT(*) FROM _config WHERE key = 'client_id'",
                [],
                |row| row.get::<_, i64>(0),
            )
            .unwrap_or(0)
            > 0;

        if !exists {
            let client_id = Uuid::new_v4().to_string();
            conn.execute(
                "INSERT INTO _config (key, value) VALUES ('client_id', ?1)",
                params![client_id],
            )?;
        }
        Ok(())
    }

    /// Get the client ID from _config.
    pub fn get_client_id(&self) -> SqliteResult<String> {
        let conn = self.conn.lock().unwrap();
        conn.query_row(
            "SELECT value FROM _config WHERE key = 'client_id'",
            [],
            |row| row.get(0),
        )
    }

    /// Record a change in the _changes table for sync tracking.
    fn record_change(
        &self,
        entity: &str,
        entity_id: &str,
        operation: &str,
        payload: serde_json::Value,
    ) -> SqliteResult<()> {
        let conn = self.conn.lock().unwrap();
        let client_id = self.get_client_id()?;
        let changed_at = Utc::now().to_rfc3339();
        let payload_str = payload.to_string();
        conn.execute(
            "INSERT INTO _changes (entity, entity_id, operation, payload, client_id, changed_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![entity, entity_id, operation, payload_str, client_id, changed_at],
        )?;
        Ok(())
    }

    // ================================================================
    // WORK ORDER CRUD
    // ================================================================

    /// List all work orders (non-deleted) for a given property.
    pub fn list_work_orders(&self, _property_id: &str) -> SqliteResult<Vec<WorkOrder>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, title, description, status, priority, assigned_to,
                    created_by, property_id, created_at, updated_at, deleted_at
             FROM work_orders
             WHERE deleted_at IS NULL
             ORDER BY created_at DESC",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(WorkOrder {
                id: row.get(0)?,
                title: row.get(1)?,
                description: row.get(2)?,
                status: row.get(3)?,
                priority: row.get(4)?,
                assigned_to: row.get(5)?,
                created_by: row.get(6)?,
                property_id: row.get(7)?,
                created_at: row.get(8)?,
                updated_at: row.get(9)?,
                deleted_at: row.get(10)?,
            })
        })?;
        let mut orders = Vec::new();
        for row in rows {
            orders.push(row?);
        }
        Ok(orders)
    }

    /// Get a single work order by ID.
    pub fn get_work_order(&self, id: &str) -> SqliteResult<Option<WorkOrder>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, title, description, status, priority, assigned_to,
                    created_by, property_id, created_at, updated_at, deleted_at
             FROM work_orders WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map(params![id], |row| {
            Ok(WorkOrder {
                id: row.get(0)?,
                title: row.get(1)?,
                description: row.get(2)?,
                status: row.get(3)?,
                priority: row.get(4)?,
                assigned_to: row.get(5)?,
                created_by: row.get(6)?,
                property_id: row.get(7)?,
                created_at: row.get(8)?,
                updated_at: row.get(9)?,
                deleted_at: row.get(10)?,
            })
        })?;
        match rows.next() {
            Some(Ok(order)) => Ok(Some(order)),
            _ => Ok(None),
        }
    }

    /// Create a new work order.
    pub fn create_work_order(&self, input: NewWorkOrder) -> SqliteResult<WorkOrder> {
        let conn = self.conn.lock().unwrap();
        let id = Uuid::new_v4().to_string();
        let now = Utc::now().to_rfc3339();

        conn.execute(
            "INSERT INTO work_orders (id, title, description, status, priority,
             assigned_to, created_by, property_id, created_at, updated_at)
             VALUES (?1, ?2, ?3, 'pending', ?4, ?5, ?6, ?7, ?8, ?9)",
            params![
                id,
                input.title,
                input.description,
                input.priority,
                input.assigned_to,
                input.created_by,
                input.property_id,
                now,
                now,
            ],
        )?;

        drop(conn);

        // Record the change for sync
        let payload = serde_json::json!({
            "id": id,
            "title": input.title,
            "description": input.description,
            "status": "pending",
            "priority": input.priority,
            "assigned_to": input.assigned_to,
            "created_by": input.created_by,
            "property_id": input.property_id,
            "created_at": now,
            "updated_at": now,
        });
        self.record_change("work_order", &id, "INSERT", payload)?;

        self.get_work_order(&id).map(|o| o.unwrap())
    }

    /// Update an existing work order.
    pub fn update_work_order(&self, input: UpdateWorkOrder) -> SqliteResult<Option<WorkOrder>> {
        let existing = self.get_work_order(&input.id)?;
        let existing = match existing {
            Some(o) => o,
            None => return Ok(None),
        };

        let conn = self.conn.lock().unwrap();
        let now = Utc::now().to_rfc3339();

        let title = input.title.unwrap_or(existing.title);
        let description = input.description.unwrap_or(existing.description);
        let status = input.status.unwrap_or(existing.status);
        let priority = input.priority.unwrap_or(existing.priority);
        let assigned_to = input.assigned_to.or(existing.assigned_to);

        conn.execute(
            "UPDATE work_orders SET title = ?1, description = ?2, status = ?3,
             priority = ?4, assigned_to = ?5, updated_at = ?6
             WHERE id = ?7",
            params![title, description, status, priority, assigned_to, now, input.id],
        )?;

        drop(conn);

        // Record the change for sync
        let payload = serde_json::json!({
            "title": title,
            "description": description,
            "status": status,
            "priority": priority,
            "assigned_to": assigned_to,
            "updated_at": now,
        });
        self.record_change("work_order", &input.id, "UPDATE", payload)?;

        self.get_work_order(&input.id)
    }

    /// Soft-delete a work order.
    pub fn delete_work_order(&self, id: &str) -> SqliteResult<bool> {
        let conn = self.conn.lock().unwrap();
        let now = Utc::now().to_rfc3339();
        let affected = conn.execute(
            "UPDATE work_orders SET deleted_at = ?1, updated_at = ?2 WHERE id = ?3 AND deleted_at IS NULL",
            params![now, now, id],
        )?;
        drop(conn);

        if affected > 0 {
            self.record_change("work_order", id, "DELETE", serde_json::json!({}))?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    // ================================================================
    // ASSET CRUD
    // ================================================================

    /// List all assets (non-deleted) for a given property.
    pub fn list_assets(&self, _property_id: &str) -> SqliteResult<Vec<Asset>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, name, asset_type, location, status, property_id, created_at, updated_at, deleted_at
             FROM assets WHERE deleted_at IS NULL ORDER BY name ASC",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(Asset {
                id: row.get(0)?,
                name: row.get(1)?,
                asset_type: row.get(2)?,
                location: row.get(3)?,
                status: row.get(4)?,
                property_id: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
                deleted_at: row.get(8)?,
            })
        })?;
        let mut assets = Vec::new();
        for row in rows {
            assets.push(row?);
        }
        Ok(assets)
    }

    /// Create a new asset.
    pub fn create_asset(&self, input: NewAsset) -> SqliteResult<Asset> {
        let conn = self.conn.lock().unwrap();
        let id = Uuid::new_v4().to_string();
        let now = Utc::now().to_rfc3339();

        conn.execute(
            "INSERT INTO assets (id, name, asset_type, location, status, property_id, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![id, input.name, input.asset_type, input.location, input.status, input.property_id, now, now],
        )?;

        let asset = Asset {
            id,
            name: input.name,
            asset_type: input.asset_type,
            location: input.location,
            status: input.status,
            property_id: input.property_id,
            created_at: now.clone(),
            updated_at: now,
            deleted_at: None,
        };

        let payload = serde_json::to_value(&asset).unwrap_or_default();
        drop(conn);
        self.record_change("asset", &asset.id, "INSERT", payload)?;

        Ok(asset)
    }

    /// Delete an asset.
    pub fn delete_asset(&self, id: &str) -> SqliteResult<bool> {
        let conn = self.conn.lock().unwrap();
        let now = Utc::now().to_rfc3339();
        let affected = conn.execute(
            "UPDATE assets SET deleted_at = ?1, updated_at = ?2 WHERE id = ?3 AND deleted_at IS NULL",
            params![now, now, id],
        )?;
        drop(conn);

        if affected > 0 {
            self.record_change("asset", id, "DELETE", serde_json::json!({}))?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    // ================================================================
    // HELPDESK REQUEST CRUD
    // ================================================================

    /// List all helpdesk requests (non-deleted) for a given property.
    pub fn list_helpdesk_requests(&self, _property_id: &str) -> SqliteResult<Vec<HelpdeskRequest>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, subject, description, status, priority, resident_name,
                    unit, property_id, created_at, updated_at, deleted_at
             FROM helpdesk_requests WHERE deleted_at IS NULL
             ORDER BY created_at DESC",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(HelpdeskRequest {
                id: row.get(0)?,
                subject: row.get(1)?,
                description: row.get(2)?,
                status: row.get(3)?,
                priority: row.get(4)?,
                resident_name: row.get(5)?,
                unit: row.get(6)?,
                property_id: row.get(7)?,
                created_at: row.get(8)?,
                updated_at: row.get(9)?,
                deleted_at: row.get(10)?,
            })
        })?;
        let mut requests = Vec::new();
        for row in rows {
            requests.push(row?);
        }
        Ok(requests)
    }

    /// Create a new helpdesk request.
    pub fn create_helpdesk_request(&self, input: NewHelpdeskRequest) -> SqliteResult<HelpdeskRequest> {
        let conn = self.conn.lock().unwrap();
        let id = Uuid::new_v4().to_string();
        let now = Utc::now().to_rfc3339();

        conn.execute(
            "INSERT INTO helpdesk_requests (id, subject, description, status, priority,
             resident_name, unit, property_id, created_at, updated_at)
             VALUES (?1, ?2, ?3, 'open', ?4, ?5, ?6, ?7, ?8, ?9)",
            params![
                id, input.subject, input.description, input.priority,
                input.resident_name, input.unit, input.property_id, now, now,
            ],
        )?;

        let request = HelpdeskRequest {
            id,
            subject: input.subject,
            description: input.description,
            status: "open".to_string(),
            priority: input.priority,
            resident_name: input.resident_name,
            unit: input.unit,
            property_id: input.property_id,
            created_at: now.clone(),
            updated_at: now,
            deleted_at: None,
        };

        let payload = serde_json::to_value(&request).unwrap_or_default();
        drop(conn);
        self.record_change("helpdesk_request", &request.id, "INSERT", payload)?;

        Ok(request)
    }

    /// Delete a helpdesk request.
    pub fn delete_helpdesk_request(&self, id: &str) -> SqliteResult<bool> {
        let conn = self.conn.lock().unwrap();
        let now = Utc::now().to_rfc3339();
        let affected = conn.execute(
            "UPDATE helpdesk_requests SET deleted_at = ?1, updated_at = ?2 WHERE id = ?3 AND deleted_at IS NULL",
            params![now, now, id],
        )?;
        drop(conn);

        if affected > 0 {
            self.record_change("helpdesk_request", id, "DELETE", serde_json::json!({}))?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    // ================================================================
    // SYNC STATUS & CONFLICTS
    // ================================================================

    /// Get the current sync status.
    pub fn get_sync_status(&self) -> SqliteResult<SyncStatus> {
        let conn = self.conn.lock().unwrap();

        let pending_changes: i64 = conn
            .query_row("SELECT COUNT(*) FROM _changes WHERE synced_at IS NULL", [], |row| {
                row.get(0)
            })
            .unwrap_or(0);

        let unresolved_conflicts: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM _conflicts WHERE resolved = 0",
                [],
                |row| row.get(0),
            )
            .unwrap_or(0);

        let last_sync_at: Option<String> = conn
            .query_row(
                "SELECT last_push_at FROM _sync_state WHERE id = 1",
                [],
                |row| row.get(0),
            )
            .ok()
            .flatten();

        let gateway_url: String = conn
            .query_row(
                "SELECT gateway_url FROM _sync_state WHERE id = 1",
                [],
                |row| row.get(0),
            )
            .unwrap_or_default();

        drop(conn);

        Ok(SyncStatus {
            agent_running: false, // Will be updated by the sync manager
            pending_changes,
            unresolved_conflicts,
            last_sync_at,
            online: !gateway_url.is_empty(),
        })
    }

    /// Update the gateway URL in _sync_state.
    pub fn set_gateway_url(&self, url: &str) -> SqliteResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE _sync_state SET gateway_url = ?1 WHERE id = 1",
            params![url],
        )?;
        Ok(())
    }

    /// Get the gateway URL from _sync_state.
    pub fn get_gateway_url(&self) -> SqliteResult<String> {
        let conn = self.conn.lock().unwrap();
        conn.query_row(
            "SELECT gateway_url FROM _sync_state WHERE id = 1",
            [],
            |row| row.get(0),
        )
    }

    /// Get all unresolved conflicts.
    pub fn get_conflicts(&self) -> SqliteResult<Vec<SyncConflict>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, entity, entity_id, local_data, remote_data, resolved, created_at
             FROM _conflicts WHERE resolved = 0 ORDER BY created_at DESC",
        )?;
        let rows = stmt.query_map([], |row| {
            let local_str: String = row.get(3)?;
            let remote_str: String = row.get(4)?;
            Ok(SyncConflict {
                id: row.get(0)?,
                entity: row.get(1)?,
                entity_id: row.get(2)?,
                local_data: serde_json::from_str(&local_str).unwrap_or_default(),
                remote_data: serde_json::from_str(&remote_str).unwrap_or_default(),
                resolved: row.get::<_, i64>(5)? != 0,
                created_at: row.get(6)?,
            })
        })?;
        let mut conflicts = Vec::new();
        for row in rows {
            conflicts.push(row?);
        }
        Ok(conflicts)
    }

    /// Resolve a conflict.
    pub fn resolve_conflict(&self, conflict_id: i64, _action: &str) -> SqliteResult<bool> {
        let conn = self.conn.lock().unwrap();
        let affected = conn.execute(
            "UPDATE _conflicts SET resolved = 1 WHERE id = ?1 AND resolved = 0",
            params![conflict_id],
        )?;
        Ok(affected > 0)
    }

    /// Get unsynced changes for the sync agent to push.
    pub fn get_unsynced_changes(&self, limit: i64) -> SqliteResult<Vec<ChangeRecord>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, entity, entity_id, operation, payload, client_id, changed_at, synced_at
             FROM _changes WHERE synced_at IS NULL
             ORDER BY id ASC LIMIT ?1",
        )?;
        let rows = stmt.query_map(params![limit], |row| {
            let payload_str: String = row.get(4)?;
            Ok(ChangeRecord {
                id: row.get(0)?,
                entity: row.get(1)?,
                entity_id: row.get(2)?,
                operation: row.get(3)?,
                payload: serde_json::from_str(&payload_str).unwrap_or_default(),
                client_id: row.get(5)?,
                changed_at: row.get(6)?,
                synced_at: row.get(7)?,
            })
        })?;
        let mut changes = Vec::new();
        for row in rows {
            changes.push(row?);
        }
        Ok(changes)
    }

    /// Mark changes as synced.
    pub fn mark_changes_synced(&self, ids: &[i64]) -> SqliteResult<()> {
        if ids.is_empty() {
            return Ok(());
        }
        let conn = self.conn.lock().unwrap();
        let now = Utc::now().to_rfc3339();
        for id in ids {
            conn.execute(
                "UPDATE _changes SET synced_at = ?1 WHERE id = ?2",
                params![now, id],
            )?;
        }
        conn.execute(
            "UPDATE _sync_state SET last_push_at = ?1 WHERE id = 1",
            params![now],
        )?;
        Ok(())
    }

    /// Insert a conflict from sync agent feedback.
    #[allow(unused)]
    pub fn insert_conflict(
        &self,
        entity: &str,
        entity_id: &str,
        local_data: serde_json::Value,
        remote_data: serde_json::Value,
    ) -> SqliteResult<()> {
        let conn = self.conn.lock().unwrap();
        let now = Utc::now().to_rfc3339();
        conn.execute(
            "INSERT INTO _conflicts (entity, entity_id, local_data, remote_data, resolved, created_at)
             VALUES (?1, ?2, ?3, ?4, 0, ?5)",
            params![
                entity,
                entity_id,
                local_data.to_string(),
                remote_data.to_string(),
                now,
            ],
        )?;
        Ok(())
    }

    /// Update the last_pull_at timestamp.
    #[allow(unused)]
    pub fn update_last_pull_at(&self, timestamp: &str) -> SqliteResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE _sync_state SET last_pull_at = ?1 WHERE id = 1",
            params![timestamp],
        )?;
        Ok(())
    }

    /// Get the last_pull_at timestamp.
    #[allow(unused)]
    pub fn get_last_pull_at(&self) -> SqliteResult<Option<String>> {
        let conn = self.conn.lock().unwrap();
        conn.query_row(
            "SELECT last_pull_at FROM _sync_state WHERE id = 1",
            [],
            |row| row.get(0),
        )
    }
}