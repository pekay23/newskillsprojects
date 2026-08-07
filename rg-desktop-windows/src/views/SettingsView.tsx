import { useCallback, useEffect, useState } from "react";
import { getClientId, getPendingChanges, getSyncStatus, setGatewayUrl } from "../api";
import type { ChangeRecord, SyncStatus } from "../types";

interface SettingsViewProps {
  showToast: (message: string, type?: "success" | "error") => void;
}

export default function SettingsView({ showToast }: SettingsViewProps) {
  const [syncStatus, setSyncStatus] = useState<SyncStatus | null>(null);
  const [clientId, setClientId] = useState("");
  const [gatewayUrl, setGatewayUrlInput] = useState("");
  const [pendingChanges, setPendingChanges] = useState<ChangeRecord[]>([]);

  const loadSettings = useCallback(async () => {
    try {
      const [status, id, changes] = await Promise.all([
        getSyncStatus(),
        getClientId(),
        getPendingChanges(20),
      ]);
      setSyncStatus(status);
      setClientId(id);
      setPendingChanges(changes);
    } catch (err) {
      showToast(`Failed to load settings: ${err}`, "error");
    }
  }, [showToast]);

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  const handleSaveGateway = async () => {
    if (!gatewayUrl.trim()) {
      showToast("Gateway URL is required", "error");
      return;
    }
    try {
      await setGatewayUrl(gatewayUrl.trim());
      showToast("Gateway URL saved");
      loadSettings();
    } catch (err) {
      showToast(`Failed to save gateway URL: ${err}`, "error");
    }
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <div className="page-title">Settings</div>
          <div className="page-subtitle">Configure sync and view device information</div>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <div className="card-header">
          <div className="card-title">Sync Configuration</div>
        </div>
        <div className="card-body">
          <div className="settings-section">
            <div className="settings-title">API Gateway</div>
            <div className="settings-row">
              <div>
                <div className="settings-label">Gateway URL</div>
                <div style={{ fontSize: 12, color: "var(--rg-text-muted)" }}>
                  HTTPS required (or localhost for development)
                </div>
              </div>
              <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                <input
                  className="form-input"
                  style={{ width: 280 }}
                  value={gatewayUrl}
                  onChange={(e) => setGatewayUrlInput(e.target.value)}
                  placeholder="https://api.raymondgray.local"
                />
                <button className="btn btn-primary btn-sm" onClick={handleSaveGateway}>
                  Save
                </button>
              </div>
            </div>
          </div>

          <div className="settings-section">
            <div className="settings-title">Sync Status</div>
            <div className="settings-row">
              <div className="settings-label">Agent Status</div>
              <div className="settings-value">
                {syncStatus?.agent_running ? "Running" : "Not running"}
              </div>
            </div>
            <div className="settings-row">
              <div className="settings-label">Pending Changes</div>
              <div className="settings-value">{syncStatus?.pending_changes ?? 0}</div>
            </div>
            <div className="settings-row">
              <div className="settings-label">Unresolved Conflicts</div>
              <div className="settings-value">{syncStatus?.unresolved_conflicts ?? 0}</div>
            </div>
            <div className="settings-row">
              <div className="settings-label">Last Sync</div>
              <div className="settings-value">
                {syncStatus?.last_sync_at
                  ? new Date(syncStatus.last_sync_at).toLocaleString()
                  : "Never"}
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <div className="card-header">
          <div className="card-title">Device Information</div>
        </div>
        <div className="card-body">
          <div className="settings-row">
            <div className="settings-label">Client ID</div>
            <div className="settings-value">{clientId || "Loading..."}</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <div className="card-title">Pending Changes Queue</div>
        </div>
        <div className="card-body">
          {pendingChanges.length === 0 ? (
            <div style={{ color: "var(--rg-text-muted)", fontSize: 13 }}>
              No pending changes. All local changes have been synced.
            </div>
          ) : (
            <table className="table">
              <thead>
                <tr>
                  <th>Entity</th>
                  <th>Operation</th>
                  <th>Changed At</th>
                </tr>
              </thead>
              <tbody>
                {pendingChanges.map((change) => (
                  <tr key={change.id}>
                    <td>{change.entity}</td>
                    <td>{change.operation}</td>
                    <td>{new Date(change.changed_at).toLocaleString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}