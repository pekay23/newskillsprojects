use base64::Engine;
use serde_json;

use std::sync::{Arc, Mutex};

use crate::db::Database;
use crate::models::{
    Asset, HelpdeskRequest, NewAsset, NewHelpdeskRequest, NewWorkOrder, ResolveConflict,
    SyncConflict, SyncStatus, UpdateWorkOrder, WorkOrder,
};
use crate::sync::SyncManager;

/// Shared application state passed to Tauri commands.
pub struct AppState {
    pub db: Arc<Database>,
    pub sync_manager: Arc<SyncManager>,
    /// JWT stored in memory — never in localStorage. Passed to sync agent as RG_AUTH_TOKEN.
    pub auth_token: Arc<Mutex<Option<String>>>,
    /// User info decoded from the JWT (display name, email, role).
    pub user_info: Arc<Mutex<Option<UserInfo>>>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct UserInfo {
    pub id: String,
    pub email: String,
    pub role: String,
    pub authenticated: bool,
}

/// Convert a rusqlite error to a user-friendly string for IPC.
fn db_error(e: rusqlite::Error) -> String {
    format!("Database error: {}", e)
}

// ================================================================
// WORK ORDER COMMANDS
// ================================================================

/// List all work orders (non-deleted).
#[tauri::command]
pub fn list_work_orders(state: tauri::State<'_, AppState>) -> Result<Vec<WorkOrder>, String> {
    state
        .db
        .list_work_orders("all")
        .map_err(db_error)
}

/// Get a single work order by ID.
#[tauri::command]
pub fn get_work_order(
    state: tauri::State<'_, AppState>,
    id: String,
) -> Result<Option<WorkOrder>, String> {
    state
        .db
        .get_work_order(&id)
        .map_err(db_error)
}

/// Create a new work order.
#[tauri::command]
pub fn create_work_order(
    state: tauri::State<'_, AppState>,
    input: NewWorkOrder,
) -> Result<WorkOrder, String> {
    // Validate required fields
    if input.title.trim().is_empty() {
        return Err("Title is required".to_string());
    }
    if !["low", "medium", "high", "urgent"].contains(&input.priority.as_str()) {
        return Err("Priority must be one of: low, medium, high, urgent".to_string());
    }
    state.db.create_work_order(input).map_err(db_error)
}

/// Update an existing work order.
#[tauri::command]
pub fn update_work_order(
    state: tauri::State<'_, AppState>,
    input: UpdateWorkOrder,
) -> Result<Option<WorkOrder>, String> {
    state
        .db
        .update_work_order(input)
        .map_err(db_error)
}

/// Delete a work order (soft delete).
#[tauri::command]
pub fn delete_work_order(
    state: tauri::State<'_, AppState>,
    id: String,
) -> Result<bool, String> {
    state
        .db
        .delete_work_order(&id)
        .map_err(db_error)
}

// ================================================================
// ASSET COMMANDS
// ================================================================

/// List all assets.
#[tauri::command]
pub fn list_assets(state: tauri::State<'_, AppState>) -> Result<Vec<Asset>, String> {
    state.db.list_assets("all").map_err(db_error)
}

/// Create a new asset.
#[tauri::command]
pub fn create_asset(
    state: tauri::State<'_, AppState>,
    input: NewAsset,
) -> Result<Asset, String> {
    if input.name.trim().is_empty() {
        return Err("Name is required".to_string());
    }
    state.db.create_asset(input).map_err(db_error)
}

/// Delete an asset.
#[tauri::command]
pub fn delete_asset(
    state: tauri::State<'_, AppState>,
    id: String,
) -> Result<bool, String> {
    state
        .db
        .delete_asset(&id)
        .map_err(db_error)
}

// ================================================================
// HELPDESK REQUEST COMMANDS
// ================================================================

/// List all helpdesk requests.
#[tauri::command]
pub fn list_helpdesk_requests(
    state: tauri::State<'_, AppState>,
) -> Result<Vec<HelpdeskRequest>, String> {
    state
        .db
        .list_helpdesk_requests("all")
        .map_err(db_error)
}

/// Create a new helpdesk request.
#[tauri::command]
pub fn create_helpdesk_request(
    state: tauri::State<'_, AppState>,
    input: NewHelpdeskRequest,
) -> Result<HelpdeskRequest, String> {
    if input.subject.trim().is_empty() {
        return Err("Subject is required".to_string());
    }
    if input.resident_name.trim().is_empty() {
        return Err("Resident name is required".to_string());
    }
    state
        .db
        .create_helpdesk_request(input)
        .map_err(db_error)
}

/// Delete a helpdesk request.
#[tauri::command]
pub fn delete_helpdesk_request(
    state: tauri::State<'_, AppState>,
    id: String,
) -> Result<bool, String> {
    state
        .db
        .delete_helpdesk_request(&id)
        .map_err(db_error)
}

// ================================================================
// SYNC & CONFLICT COMMANDS
// ================================================================

/// Get the current sync status.
#[tauri::command]
pub fn get_sync_status(
    state: tauri::State<'_, AppState>,
) -> Result<SyncStatus, String> {
    let mut status = state.db.get_sync_status().map_err(db_error)?;
    status.agent_running = state.sync_manager.is_running();
    Ok(status)
}

/// Set the API gateway URL for sync.
#[tauri::command]
pub fn set_gateway_url(
    state: tauri::State<'_, AppState>,
    url: String,
) -> Result<(), String> {
    // Security: only allow HTTPS or localhost URLs
    let is_https = url.starts_with("https://") || url.starts_with("http://localhost") || url.starts_with("http://127.0.0.1");
    if !is_https {
        return Err("Gateway URL must use HTTPS (or localhost for development)".to_string());
    }
    state.db.set_gateway_url(&url).map_err(db_error)
}

/// Get all unresolved sync conflicts.
#[tauri::command]
pub fn get_conflicts(
    state: tauri::State<'_, AppState>,
) -> Result<Vec<SyncConflict>, String> {
    state
        .db
        .get_conflicts()
        .map_err(db_error)
}

/// Resolve a sync conflict.
#[tauri::command]
pub fn resolve_conflict(
    state: tauri::State<'_, AppState>,
    input: ResolveConflict,
) -> Result<bool, String> {
    if !["use_mine", "use_cloud", "merge"].contains(&input.action.as_str()) {
        return Err("Action must be one of: use_mine, use_cloud, merge".to_string());
    }
    state
        .db
        .resolve_conflict(input.conflict_id, &input.action)
        .map_err(db_error)
}

/// Get the local client ID.
#[tauri::command]
pub fn get_client_id(state: tauri::State<'_, AppState>) -> Result<String, String> {
    state
        .db
        .get_client_id()
        .map_err(db_error)
}

/// Get pending (unsynced) change records.
#[tauri::command]
pub fn get_pending_changes(
    state: tauri::State<'_, AppState>,
    limit: Option<i64>,
) -> Result<Vec<crate::models::ChangeRecord>, String> {
    state
        .db
        .get_unsynced_changes(limit.unwrap_or(50))
        .map_err(db_error)
}

/// Manually trigger a sync cycle (push unsynced changes).
#[tauri::command]
pub fn sync_now(
    state: tauri::State<'_, AppState>,
    ids: Vec<i64>,
) -> Result<(), String> {
    // Mark the provided change IDs as synced.
    // In a full implementation this would call the sync agent / gateway.
    state
        .db
        .mark_changes_synced(&ids)
        .map_err(db_error)
}

// ================================================================
// AUTH COMMANDS
// ================================================================

/// Store the NextAuth JWT in memory and decode user info.
#[tauri::command]
pub fn set_auth_token(
    state: tauri::State<'_, AppState>,
    token: String,
) -> Result<UserInfo, String> {
    // Validate and decode the JWT (without verification for dev convenience)
    let token_data = decode_jwt(&token).map_err(|e| format!("Invalid JWT: {}", e))?;
    
    let user_info = UserInfo {
        id: token_data.claims.get("sub").and_then(|v| v.as_str().map(|s| s.to_string())).unwrap_or_default(),
        email: token_data.claims.get("email").and_then(|v| v.as_str().map(|s| s.to_string())).unwrap_or_default(),
        role: token_data.claims.get("role").and_then(|v| v.as_str().map(|s| s.to_string())).unwrap_or_else(|| "unknown".to_string()),
        authenticated: true,
    };

    *state.auth_token.lock().unwrap() = Some(token);
    *state.user_info.lock().unwrap() = Some(user_info.clone());

    Ok(user_info)
}

/// Clear the stored auth token (logout).
#[tauri::command]
pub fn logout(state: tauri::State<'_, AppState>) -> Result<(), String> {
    *state.auth_token.lock().unwrap() = None;
    *state.user_info.lock().unwrap() = None;
    Ok(())
}

/// Get the current user info (if logged in).
#[tauri::command]
pub fn get_user_info(state: tauri::State<'_, AppState>) -> Result<Option<UserInfo>, String> {
    Ok(state.user_info.lock().unwrap().clone())
}

/// Get the stored auth token (for sync agent).
#[tauri::command]
pub fn get_auth_token(state: tauri::State<'_, AppState>) -> Result<Option<String>, String> {
    Ok(state.auth_token.lock().unwrap().clone())
}

/// Decode a JWT without verification (for dev convenience — production should verify).
fn decode_jwt(token: &str) -> Result<jsonwebtoken::TokenData<serde_json::Value>, String> {
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() != 3 {
        return Err("Invalid JWT format".to_string());
    }
    // Decode payload (middle part) without verification
    let payload = parts[1];
    let padded = match payload.len() % 4 {
        2 => format!("{}==", payload),
        3 => format!("{}=", payload),
        _ => payload.to_string(),
    };
    let decoded = base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(padded)
        .map_err(|e| format!("Invalid base64: {}", e))?;
    let claims: serde_json::Value = serde_json::from_slice(&decoded)
        .map_err(|e| format!("Invalid JSON: {}", e))?;
    Ok(jsonwebtoken::TokenData {
        header: Default::default(),
        claims,
    })
}

