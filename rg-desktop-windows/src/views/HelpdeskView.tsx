import { useCallback, useEffect, useState } from "react";
import type { HelpdeskRequest, NewHelpdeskRequest } from "../types";
import { createHelpdeskRequest, deleteHelpdeskRequest, listHelpdeskRequests } from "../api";
import Badge from "../components/Badge";
import ConfirmModal from "../components/ConfirmModal";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";

interface HelpdeskViewProps {
  showToast: (message: string, type?: "success" | "error") => void;
}

const DEFAULT_PROPERTY_ID = "forster-park";

export default function HelpdeskView({ showToast }: HelpdeskViewProps) {
  const [requests, setRequests] = useState<HelpdeskRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState<HelpdeskRequest | null>(null);

  // Form state
  const [subject, setSubject] = useState("");
  const [description, setDescription] = useState("");
  const [priority, setPriority] = useState("medium");
  const [residentName, setResidentName] = useState("");
  const [unit, setUnit] = useState("");

  const loadRequests = useCallback(async () => {
    try {
      const data = await listHelpdeskRequests();
      setRequests(data);
    } catch (err) {
      showToast(`Failed to load helpdesk requests: ${err}`, "error");
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    loadRequests();
  }, [loadRequests]);

  const resetForm = () => {
    setSubject("");
    setDescription("");
    setPriority("medium");
    setResidentName("");
    setUnit("");
  };

  const handleCreate = async () => {
    if (!subject.trim()) {
      showToast("Subject is required", "error");
      return;
    }
    if (!residentName.trim()) {
      showToast("Resident name is required", "error");
      return;
    }
    try {
      const input: NewHelpdeskRequest = {
        subject: subject.trim(),
        description: description.trim(),
        priority,
        resident_name: residentName.trim(),
        unit: unit.trim(),
        property_id: DEFAULT_PROPERTY_ID,
      };
      await createHelpdeskRequest(input);
      showToast("Helpdesk request created");
      setShowCreate(false);
      resetForm();
      loadRequests();
    } catch (err) {
      showToast(`Failed to create request: ${err}`, "error");
    }
  };

  const handleDelete = async (request: HelpdeskRequest) => {
    setConfirmDelete(request);
  };

  const handleConfirmDelete = async () => {
    if (!confirmDelete) return;
    try {
      await deleteHelpdeskRequest(confirmDelete.id);
      showToast("Request deleted");
      setConfirmDelete(null);
      loadRequests();
    } catch (err) {
      showToast(`Failed to delete request: ${err}`, "error");
      setConfirmDelete(null);
    }
  };

  const stats = {
    total: requests.length,
    open: requests.filter((r) => r.status === "open").length,
    inProgress: requests.filter((r) => r.status === "in_progress").length,
    closed: requests.filter((r) => r.status === "closed").length,
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <div className="page-title">Helpdesk</div>
          <div className="page-subtitle">Track resident requests and amenity bookings</div>
        </div>
        <button className="btn btn-primary" onClick={() => { resetForm(); setShowCreate(true); }}>
          New Request
        </button>
      </div>

      <div className="stat-strip">
        <div className="stat-card">
          <div className="stat-label">Total</div>
          <div className="stat-value">{stats.total}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Open</div>
          <div className="stat-value">{stats.open}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">In Progress</div>
          <div className="stat-value">{stats.inProgress}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Closed</div>
          <div className="stat-value">{stats.closed}</div>
        </div>
      </div>

      <div className="card">
        {loading ? (
          <div className="card-body">Loading helpdesk requests...</div>
        ) : requests.length === 0 ? (
          <EmptyState title="No helpdesk requests" subtitle="Resident requests will appear here" />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Subject</th>
                <th>Resident</th>
                <th>Unit</th>
                <th>Status</th>
                <th>Priority</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {requests.map((request) => (
                <tr key={request.id}>
                  <td>
                    <strong>{request.subject}</strong>
                    {request.description && (
                      <div style={{ color: "var(--rg-text-muted)", fontSize: 12.5, marginTop: 2 }}>
                        {request.description.length > 60 ? request.description.slice(0, 60) + "…" : request.description}
                      </div>
                    )}
                  </td>
                  <td>{request.resident_name}</td>
                  <td>{request.unit || "—"}</td>
                  <td><Badge value={request.status} /></td>
                  <td><Badge value={request.priority} /></td>
                  <td>
                    <button className="btn btn-ghost btn-sm" style={{ color: "var(--rg-danger)" }} onClick={() => handleDelete(request)}>
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {confirmDelete && (
        <ConfirmModal
          title="Delete Helpdesk Request"
          message={`This will delete "${confirmDelete.subject}" and apply the change to the PRODUCTION database via the sync agent. This cannot be undone.`}
          confirmLabel="Delete"
          danger
          onConfirm={handleConfirmDelete}
          onCancel={() => setConfirmDelete(null)}
        />
      )}

      {showCreate && (
        <Modal
          title="New Helpdesk Request"
          onClose={() => setShowCreate(false)}
          footer={
            <>
              <button className="btn btn-secondary" onClick={() => setShowCreate(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleCreate}>Create</button>
            </>
          }
        >
          <div className="form-grid">
            <div className="form-field form-field-full">
              <label className="form-label">Subject *</label>
              <input
                className="form-input"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                placeholder="e.g. Request for maintenance"
                autoFocus
              />
            </div>
            <div className="form-field form-field-full">
              <label className="form-label">Description</label>
              <textarea
                className="form-textarea"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Describe the request"
              />
            </div>
            <div className="form-field">
              <label className="form-label">Resident Name *</label>
              <input
                className="form-input"
                value={residentName}
                onChange={(e) => setResidentName(e.target.value)}
                placeholder="Resident name"
              />
            </div>
            <div className="form-field">
              <label className="form-label">Unit</label>
              <input
                className="form-input"
                value={unit}
                onChange={(e) => setUnit(e.target.value)}
                placeholder="e.g. Unit 3"
              />
            </div>
            <div className="form-field">
              <label className="form-label">Priority</label>
              <select className="form-select" value={priority} onChange={(e) => setPriority(e.target.value)}>
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
                <option value="urgent">Urgent</option>
              </select>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}