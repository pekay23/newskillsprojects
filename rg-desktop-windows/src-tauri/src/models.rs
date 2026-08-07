use serde::{Deserialize, Serialize};

/// Work order entity matching the Go workorder-service model.
/// Status: pending, in_progress, completed, cancelled
/// Priority: low, medium, high, urgent
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkOrder {
    pub id: String,
    pub title: String,
    pub description: String,
    pub status: String,
    pub priority: String,
    pub assigned_to: Option<String>,
    pub created_by: String,
    pub property_id: String,
    pub created_at: String,
    pub updated_at: String,
    pub deleted_at: Option<String>,
}

/// Asset entity matching the .NET CMMS service asset model.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Asset {
    pub id: String,
    pub name: String,
    pub asset_type: String,
    pub location: String,
    pub status: String,
    pub property_id: String,
    pub created_at: String,
    pub updated_at: String,
    pub deleted_at: Option<String>,
}

/// Resident helpdesk request matching the Python helpdesk service.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HelpdeskRequest {
    pub id: String,
    pub subject: String,
    pub description: String,
    pub status: String,
    pub priority: String,
    pub resident_name: String,
    pub unit: String,
    pub property_id: String,
    pub created_at: String,
    pub updated_at: String,
    pub deleted_at: Option<String>,
}

/// A change record as defined by the Sync Engine Spec (Section 2.1).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChangeRecord {
    pub id: i64,
    pub entity: String,
    pub entity_id: String,
    pub operation: String,
    pub payload: serde_json::Value,
    pub client_id: String,
    pub changed_at: String,
    pub synced_at: Option<String>,
}

/// A sync conflict as defined by the Sync Engine Spec (Section 5).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncConflict {
    pub id: i64,
    pub entity: String,
    pub entity_id: String,
    pub local_data: serde_json::Value,
    pub remote_data: serde_json::Value,
    pub resolved: bool,
    pub created_at: String,
}

/// Sync status reported to the UI.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncStatus {
    pub agent_running: bool,
    pub pending_changes: i64,
    pub unresolved_conflicts: i64,
    pub last_sync_at: Option<String>,
    pub online: bool,
}

/// DTO for creating a work order from the UI.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewWorkOrder {
    pub title: String,
    pub description: String,
    pub priority: String,
    pub assigned_to: Option<String>,
    pub property_id: String,
    pub created_by: String,
}

/// DTO for updating a work order from the UI.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateWorkOrder {
    pub id: String,
    pub title: Option<String>,
    pub description: Option<String>,
    pub status: Option<String>,
    pub priority: Option<String>,
    pub assigned_to: Option<String>,
}

/// DTO for creating an asset from the UI.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewAsset {
    pub name: String,
    pub asset_type: String,
    pub location: String,
    pub status: String,
    pub property_id: String,
}

/// DTO for creating a helpdesk request from the UI.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewHelpdeskRequest {
    pub subject: String,
    pub description: String,
    pub priority: String,
    pub resident_name: String,
    pub unit: String,
    pub property_id: String,
}

/// DTO for resolving a conflict.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResolveConflict {
    pub conflict_id: i64,
    pub action: String, // "use_mine" | "use_cloud" | "merge"
    pub merged_record: Option<serde_json::Value>,
}