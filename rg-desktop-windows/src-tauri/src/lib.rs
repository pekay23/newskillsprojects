pub mod commands;
pub mod db;
pub mod models;
pub mod sync;

use std::sync::Arc;

use db::Database;
use sync::SyncManager;
use tauri::Manager;

/// Tauri entry point.
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .setup(|app| {
            // Locate the app data directory for the SQLite database.
            let app_data_dir = app
                .path()
                .app_data_dir()
                .expect("failed to resolve app data directory");

            // Open (or create) the local database.
            let db_path = app_data_dir.join("local.db");
            let db = Arc::new(
                Database::open(db_path)
                    .expect("failed to open local database"),
            );

            // Start the sync manager (supervises the Go sync agent).
            let sync_manager = Arc::new(SyncManager::new(db.clone()));
            sync_manager.start();

            // Manage shared state for IPC commands.
            app.manage(commands::AppState {
                db,
                sync_manager,
                auth_token: Arc::new(std::sync::Mutex::new(None)),
                user_info: Arc::new(std::sync::Mutex::new(None)),
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::list_work_orders,
            commands::get_work_order,
            commands::create_work_order,
            commands::update_work_order,
            commands::delete_work_order,
            commands::list_assets,
            commands::create_asset,
            commands::delete_asset,
            commands::list_helpdesk_requests,
            commands::create_helpdesk_request,
            commands::delete_helpdesk_request,
            commands::get_sync_status,
            commands::set_gateway_url,
            commands::get_conflicts,
            commands::resolve_conflict,
            commands::get_client_id,
            commands::get_pending_changes,
            commands::sync_now,
            commands::set_auth_token,
            commands::logout,
            commands::get_user_info,
            commands::get_auth_token,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}