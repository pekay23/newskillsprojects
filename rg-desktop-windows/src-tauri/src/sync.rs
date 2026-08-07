use std::process::{Child, Command};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use crate::db::Database;

/// Manages the lifecycle of the Go sync agent child process.
/// Spawns it on start, restarts with exponential backoff on crash,
/// and stops it cleanly on app exit.
///
/// Note: On Windows, `Child::try_clone()` is unavailable, so the
/// supervisor thread polls `try_wait()` via the shared mutex
/// instead of blocking on `wait()`.
pub struct SyncManager {
    db: Arc<Database>,
    running: Arc<AtomicBool>,
    child: Arc<Mutex<Option<Child>>>,
}

impl SyncManager {
    pub fn new(db: Arc<Database>) -> Self {
        SyncManager {
            db,
            running: Arc::new(AtomicBool::new(false)),
            child: Arc::new(Mutex::new(None)),
        }
    }

    /// Start the supervisor loop. Spawns/restarts the sync agent.
    pub fn start(&self) {
        self.running.store(true, Ordering::SeqCst);
        let running = self.running.clone();
        let db = self.db.clone();
        let child_holder = self.child.clone();

        thread::spawn(move || {
            let mut backoff: u64 = 1;

            while running.load(Ordering::SeqCst) {
                // Determine whether the child needs to be (re)started.
                let needs_restart = {
                    let mut guard = match child_holder.lock() {
                        Ok(g) => g,
                        Err(poisoned) => poisoned.into_inner(),
                    };

                    match guard.as_mut() {
                        Some(child) => match child.try_wait() {
                            Ok(Some(_)) => {
                                log("Sync agent process exited");
                                *guard = None;
                                true
                            }
                            Ok(None) => false, // still running
                            Err(e) => {
                                log(&format!("Error checking sync agent: {}", e));
                                *guard = None;
                                true
                            }
                        },
                        None => true, // no child yet
                    }
                };

                if needs_restart {
                    match spawn_sync_agent(&db, &child_holder) {
                        Ok(()) => {
                            log("Sync agent spawned");
                            backoff = 1;
                        }
                        Err(e) => {
                            log(&format!("Failed to spawn sync agent: {}", e));
                        }
                    }
                }

                if !running.load(Ordering::SeqCst) {
                    break;
                }

                thread::sleep(Duration::from_secs(backoff));

                // Only grow backoff when a spawn failed.
                if needs_restart {
                    backoff = (backoff * 2).min(30);
                }
            }

            log("Sync manager stopped");
        });
    }

    /// Stop the supervisor and terminate the child process.
    pub fn stop(&self) {
        self.running.store(false, Ordering::SeqCst);
        if let Ok(mut guard) = self.child.lock() {
            if let Some(child) = guard.as_mut() {
                let _ = child.kill();
                let _ = child.wait();
            }
            *guard = None;
        }
    }

    /// Whether the sync agent is currently running.
    pub fn is_running(&self) -> bool {
        if let Ok(mut guard) = self.child.lock() {
            if let Some(child) = guard.as_mut() {
                return child.try_wait().map(|s| s.is_none()).unwrap_or(false);
            }
        }
        false
    }
}

/// Spawn the Go sync agent as a child process and store its handle.
fn spawn_sync_agent(
    db: &Database,
    child_holder: &Arc<Mutex<Option<Child>>>,
) -> std::io::Result<()> {
    // Look for the sync agent binary in likely locations.
    let candidates = [
        "../rg-sync-agent/rg-sync-agent.exe",
        "../../rg-sync-agent/rg-sync-agent.exe",
        "rg-sync-agent.exe",
        "./rg-sync-agent.exe",
    ];

    let mut chosen: Option<std::path::PathBuf> = None;
    for candidate in candidates.iter() {
        let path = std::path::Path::new(candidate);
        if path.exists() {
            chosen = Some(path.to_path_buf());
            break;
        }
    }

    let binary = match chosen {
        Some(p) => p,
        None => {
            log("Sync agent binary not found; running in offline-only mode");
            return Err(std::io::Error::new(
                std::io::ErrorKind::NotFound,
                "sync agent binary not found",
            ));
        }
    };

    let db_path = get_db_path();
    let gateway_url = match db.get_gateway_url() {
        Ok(url) => url,
        Err(_) => String::new(),
    };

    log(&format!(
        "Spawning sync agent: {} (gateway={})",
        binary.display(),
        gateway_url
    ));

    // Pass the auth token (JWT) if one is configured. The Rust backend holds
    // it in memory (never localStorage) and passes it to the sync agent via env.
    let auth_token = std::env::var("RG_AUTH_TOKEN").unwrap_or_default();

    let child = Command::new(&binary)
        .env("RG_GATEWAY_URL", &gateway_url)
        .env("RG_DB_PATH", &db_path)
        .env("RG_POLL_INTERVAL_MS", "500")
        .env("RG_AUTH_TOKEN", &auth_token)
        .spawn()?;

    let mut guard = match child_holder.lock() {
        Ok(g) => g,
        Err(poisoned) => poisoned.into_inner(),
    };
    *guard = Some(child);

    Ok(())
}

/// Get the SQLite database path from the app data directory.
fn get_db_path() -> String {
    let dir = std::env::var("APPDATA")
        .or_else(|_| std::env::var("HOME"))
        .unwrap_or_else(|_| ".".to_string());
    std::path::Path::new(&dir)
        .join("RaymondGray")
        .join("local.db")
        .to_string_lossy()
        .to_string()
}

/// Simple logger to stderr.
fn log(msg: &str) {
    eprintln!("[sync-manager] {}", msg);
}