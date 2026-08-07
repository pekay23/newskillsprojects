import type { ActiveView, SyncStatus } from "../types";

interface TopBarProps {
  activeView: ActiveView;
  syncStatus: SyncStatus | null;
  onRefreshSync: () => void;
  user: { id: string; email: string; role: string; authenticated: boolean } | null;
  onLogout: () => void;
}

const VIEW_TITLES: Record<ActiveView, string> = {
  workorders: "Work Orders",
  assets: "Assets",
  helpdesk: "Helpdesk",
  conflicts: "Sync Conflicts",
  settings: "Settings",
};

function getStatusClass(syncStatus: SyncStatus | null): string {
  if (!syncStatus) return "";
  if (syncStatus.agent_running) return "online";
  if (syncStatus.pending_changes > 0) return "syncing";
  return "offline";
}

function getStatusLabel(syncStatus: SyncStatus | null): string {
  if (!syncStatus) return "Loading...";
  if (syncStatus.agent_running) return "Connected";
  if (syncStatus.pending_changes > 0) return "Syncing";
  return "Offline";
}

export default function TopBar({ activeView, syncStatus, onRefreshSync, user, onLogout }: TopBarProps) {
  return (
    <header className="topbar">
      <div className="topbar-title">{VIEW_TITLES[activeView]}</div>
      <div className="topbar-right">
        <div className="sync-indicator" title="Sync status">
          <span className={`sync-dot ${getStatusClass(syncStatus)}`} />
          <span>{getStatusLabel(syncStatus)}</span>
          {syncStatus && syncStatus.pending_changes > 0 && (
            <span>({syncStatus.pending_changes} pending)</span>
          )}
        </div>
        {user ? (
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "0 12px", borderLeft: "1px solid var(--rg-border)" }}>
              <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end" }}>
                <span style={{ fontSize: 13, fontWeight: 500, color: "var(--rg-text)" }}>{user.email}</span>
                <span style={{ fontSize: 11, color: "var(--rg-text-muted)", textTransform: "capitalize" }}>{user.role}</span>
              </div>
            </div>
            <button className="btn btn-secondary btn-sm" onClick={onLogout}>
              Logout
            </button>
          </div>
        ) : (
          <button className="btn btn-secondary btn-sm" onClick={() => window.location.href = "/login"}>
            Sign In
          </button>
        )}
        <button className="btn btn-secondary btn-sm" onClick={onRefreshSync}>
          Refresh
        </button>
      </div>
    </header>
  );
}
