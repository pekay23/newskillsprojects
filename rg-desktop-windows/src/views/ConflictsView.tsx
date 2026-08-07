import { useCallback, useEffect, useState } from "react";
import type { SyncConflict } from "../types";
import { getConflicts, resolveConflict } from "../api";
import EmptyState from "../components/EmptyState";

interface ConflictsViewProps {
  showToast: (message: string, type?: "success" | "error") => void;
}

export default function ConflictsView({ showToast }: ConflictsViewProps) {
  const [conflicts, setConflicts] = useState<SyncConflict[]>([]);
  const [loading, setLoading] = useState(true);

  const loadConflicts = useCallback(async () => {
    try {
      const data = await getConflicts();
      setConflicts(data);
    } catch (err) {
      showToast(`Failed to load conflicts: ${err}`, "error");
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    loadConflicts();
  }, [loadConflicts]);

  const handleResolve = async (conflict: SyncConflict, action: "use_mine" | "use_cloud" | "merge") => {
    try {
      await resolveConflict({ conflict_id: conflict.id, action });
      showToast("Conflict resolved");
      loadConflicts();
    } catch (err) {
      showToast(`Failed to resolve conflict: ${err}`, "error");
    }
  };

  const renderField = (data: Record<string, unknown>, key: string) => {
    const value = data[key];
    if (value === undefined || value === null) return "—";
    if (typeof value === "object") return JSON.stringify(value);
    return String(value);
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <div className="page-title">Sync Conflicts</div>
          <div className="page-subtitle">
            {conflicts.length > 0
              ? `${conflicts.length} conflict${conflicts.length > 1 ? "s" : ""} need resolution`
              : "No conflicts to resolve"}
          </div>
        </div>
      </div>

      {loading ? (
        <div className="card"><div className="card-body">Loading conflicts...</div></div>
      ) : conflicts.length === 0 ? (
        <div className="card">
          <EmptyState title="All synced" subtitle="No sync conflicts need your attention" />
        </div>
      ) : (
        conflicts.map((conflict) => {
          const localKeys = Object.keys(conflict.local_data);
          const remoteKeys = Object.keys(conflict.remote_data);
          const allKeys = Array.from(new Set([...localKeys, ...remoteKeys]));

          return (
            <div className="conflict-card" key={conflict.id}>
              <div className="conflict-header">
                <svg
                  className="conflict-header-warning"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth={2}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                  <path d="M12 9v4" />
                  <path d="M12 17h.01" />
                </svg>
                <div className="conflict-title">
                  {conflict.entity.replace(/_/g, " ")} — {conflict.entity_id.slice(0, 8)}
                </div>
              </div>

              <div className="conflict-body">
                <div className="conflict-column">
                  <div className="conflict-column-label local">Your Version (offline)</div>
                  {allKeys.map((key) => (
                    <div className="conflict-field" key={`local-${key}`}>
                      <span className="conflict-field-label">{key}: </span>
                      {renderField(conflict.local_data, key)}
                    </div>
                  ))}
                </div>
                <div className="conflict-column">
                  <div className="conflict-column-label remote">Cloud Version</div>
                  {allKeys.map((key) => (
                    <div className="conflict-field" key={`remote-${key}`}>
                      <span className="conflict-field-label">{key}: </span>
                      {renderField(conflict.remote_data, key)}
                    </div>
                  ))}
                </div>
              </div>

              <div className="conflict-actions">
                <button className="btn btn-primary btn-sm" onClick={() => handleResolve(conflict, "use_mine")}>
                  Use Mine
                </button>
                <button className="btn btn-secondary btn-sm" onClick={() => handleResolve(conflict, "use_cloud")}>
                  Use Cloud
                </button>
                <button className="btn btn-merge btn-sm" onClick={() => handleResolve(conflict, "merge")}>
                  Open Record to Merge
                </button>
              </div>
            </div>
          );
        })
      )}
    </div>
  );
}