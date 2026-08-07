import { useCallback, useEffect, useState } from "react";
import type { NewWorkOrder, UpdateWorkOrder, WorkOrder } from "../types";
import { createWorkOrder, deleteWorkOrder, listWorkOrders, updateWorkOrder } from "../api";
import Badge from "../components/Badge";
import ConfirmModal from "../components/ConfirmModal";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";

interface WorkOrdersViewProps {
  showToast: (message: string, type?: "success" | "error") => void;
}

const DEFAULT_PROPERTY_ID = "forster-park";
const DEFAULT_CREATED_BY = "desktop-user";

export default function WorkOrdersView({ showToast }: WorkOrdersViewProps) {
  const [orders, setOrders] = useState<WorkOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [editing, setEditing] = useState<WorkOrder | null>(null);
  const [confirmAction, setConfirmAction] = useState<{
    type: "create" | "update" | "delete";
    order?: WorkOrder;
    newStatus?: string;
  } | null>(null);

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [priority, setPriority] = useState("medium");
  const [assignedTo, setAssignedTo] = useState("");

  const loadOrders = useCallback(async () => {
    try {
      const data = await listWorkOrders();
      setOrders(data);
    } catch (err) {
      showToast(`Failed to load work orders: ${err}`, "error");
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    loadOrders();
  }, [loadOrders]);

  const resetForm = () => {
    setTitle("");
    setDescription("");
    setPriority("medium");
    setAssignedTo("");
  };

  const handleCreate = async () => {
    if (!title.trim()) {
      showToast("Title is required", "error");
      return;
    }
    try {
      const input: NewWorkOrder = {
        title: title.trim(),
        description: description.trim(),
        priority,
        assigned_to: assignedTo.trim() || null,
        property_id: DEFAULT_PROPERTY_ID,
        created_by: DEFAULT_CREATED_BY,
      };
      await createWorkOrder(input);
      showToast("Work order created");
      setShowCreate(false);
      setConfirmAction(null);
      resetForm();
      loadOrders();
    } catch (err) {
      showToast(`Failed to create work order: ${err}`, "error");
    }
  };

  const handleStatusChange = async (order: WorkOrder, status: string) => {
    setConfirmAction({ type: "update", order, newStatus: status });
  };

  const handleDelete = async (order: WorkOrder) => {
    setConfirmAction({ type: "delete", order });
  };

  const openEdit = (order: WorkOrder) => {
    setEditing(order);
    setTitle(order.title);
    setDescription(order.description);
    setPriority(order.priority);
    setAssignedTo(order.assigned_to || "");
  };

  const handleEditSave = async () => {
    if (!editing) return;
    if (!title.trim()) {
      showToast("Title is required", "error");
      return;
    }
    try {
      const input: UpdateWorkOrder = {
        id: editing.id,
        title: title.trim(),
        description: description.trim(),
        priority,
        assigned_to: assignedTo.trim() || undefined,
      };
      await updateWorkOrder(input);
      showToast("Work order updated");
      setEditing(null);
      setConfirmAction(null);
      resetForm();
      loadOrders();
    } catch (err) {
      showToast(`Failed to update work order: ${err}`, "error");
    }
  };

  const handleConfirm = async () => {
    if (!confirmAction) return;
    const { type, order } = confirmAction;
    try {
      if (type === "create") {
        await handleCreate();
      } else if (type === "update" && order) {
        const newStatus = confirmAction.newStatus || order.status;
        const input: UpdateWorkOrder = { id: order.id, status: newStatus };
        await updateWorkOrder(input);
        showToast(`Work order marked ${newStatus.replace(/_/g, " ")}`);
        setConfirmAction(null);
        loadOrders();
      } else if (type === "delete" && order) {
        await deleteWorkOrder(order.id);
        showToast("Work order deleted");
        setConfirmAction(null);
        loadOrders();
      }
    } catch (err) {
      showToast(`Failed: ${err}`, "error");
      setConfirmAction(null);
    }
  };

  const stats = {
    total: orders.length,
    pending: orders.filter((o) => o.status === "pending").length,
    inProgress: orders.filter((o) => o.status === "in_progress").length,
    completed: orders.filter((o) => o.status === "completed").length,
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <div className="page-title">Work Orders</div>
          <div className="page-subtitle">Manage maintenance and repair tasks</div>
        </div>
        <button className="btn btn-primary" onClick={() => { resetForm(); setShowCreate(true); }}>
          New Work Order
        </button>
      </div>

      <div className="stat-strip">
        <div className="stat-card">
          <div className="stat-label">Total</div>
          <div className="stat-value">{stats.total}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Pending</div>
          <div className="stat-value">{stats.pending}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">In Progress</div>
          <div className="stat-value">{stats.inProgress}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Completed</div>
          <div className="stat-value">{stats.completed}</div>
        </div>
      </div>

      <div className="card">
        {loading ? (
          <div className="card-body">Loading work orders...</div>
        ) : orders.length === 0 ? (
          <EmptyState title="No work orders yet" subtitle="Create your first work order to get started" />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Title</th>
                <th>Status</th>
                <th>Priority</th>
                <th>Assigned To</th>
                <th>Updated</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {orders.map((order) => (
                <tr key={order.id}>
                  <td>
                    <strong>{order.title}</strong>
                    {order.description && (
                      <div style={{ color: "var(--rg-text-muted)", fontSize: 12.5, marginTop: 2 }}>
                        {order.description.length > 60 ? order.description.slice(0, 60) + "…" : order.description}
                      </div>
                    )}
                  </td>
                  <td><Badge value={order.status} /></td>
                  <td><Badge value={order.priority} /></td>
                  <td>{order.assigned_to || "—"}</td>
                  <td>{new Date(order.updated_at).toLocaleDateString()}</td>
                  <td>
                    <div style={{ display: "flex", gap: 6 }}>
                      <select
                        className="form-select"
                        style={{ width: "auto", padding: "4px 8px", fontSize: 12.5 }}
                        value={order.status}
                        onChange={(e) => handleStatusChange(order, e.target.value)}
                      >
                        <option value="pending">Pending</option>
                        <option value="in_progress">In Progress</option>
                        <option value="completed">Completed</option>
                        <option value="cancelled">Cancelled</option>
                      </select>
                      <button className="btn btn-ghost btn-sm" onClick={() => openEdit(order)}>Edit</button>
                      <button className="btn btn-ghost btn-sm" style={{ color: "var(--rg-danger)" }} onClick={() => handleDelete(order)}>Delete</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {showCreate && (
        <Modal
          title="New Work Order"
          onClose={() => setShowCreate(false)}
          footer={
            <>
              <button className="btn btn-secondary" onClick={() => setShowCreate(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={() => setConfirmAction({ type: "create" })}>Create</button>
            </>
          }
        >
          <WorkOrderForm
            title={title}
            setTitle={setTitle}
            description={description}
            setDescription={setDescription}
            priority={priority}
            setPriority={setPriority}
            assignedTo={assignedTo}
            setAssignedTo={setAssignedTo}
          />
        </Modal>
      )}

      {confirmAction && (
        <ConfirmModal
          title={
            confirmAction.type === "delete"
              ? "Delete Work Order"
              : confirmAction.type === "update"
                ? "Update Work Order"
                : "Create Work Order"
          }
          message={
            confirmAction.type === "delete"
              ? `This will delete "${confirmAction.order?.title}" and apply the change to the PRODUCTION database via the sync agent. This cannot be undone.`
              : confirmAction.type === "update"
                ? `This will update "${confirmAction.order?.title}" and apply the change to the PRODUCTION database via the sync agent.`
                : "This will create a new work order and apply it to the PRODUCTION database via the sync agent."
          }
          confirmLabel={confirmAction.type === "delete" ? "Delete" : "Confirm"}
          danger={confirmAction.type === "delete"}
          onConfirm={handleConfirm}
          onCancel={() => setConfirmAction(null)}
        />
      )}

      {editing && (
        <Modal
          title="Edit Work Order"
          onClose={() => setEditing(null)}
          footer={
            <>
              <button className="btn btn-secondary" onClick={() => setEditing(null)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleEditSave}>Save</button>
            </>
          }
        >
          <WorkOrderForm
            title={title}
            setTitle={setTitle}
            description={description}
            setDescription={setDescription}
            priority={priority}
            setPriority={setPriority}
            assignedTo={assignedTo}
            setAssignedTo={setAssignedTo}
          />
        </Modal>
      )}
    </div>
  );
}

interface WorkOrderFormProps {
  title: string;
  setTitle: (v: string) => void;
  description: string;
  setDescription: (v: string) => void;
  priority: string;
  setPriority: (v: string) => void;
  assignedTo: string;
  setAssignedTo: (v: string) => void;
}

function WorkOrderForm({
  title,
  setTitle,
  description,
  setDescription,
  priority,
  setPriority,
  assignedTo,
  setAssignedTo,
}: WorkOrderFormProps) {
  return (
    <div className="form-grid">
      <div className="form-field form-field-full">
        <label className="form-label">Title *</label>
        <input
          className="form-input"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="e.g. Fix leaking tap in Unit 3"
          autoFocus
        />
      </div>
      <div className="form-field form-field-full">
        <label className="form-label">Description</label>
        <textarea
          className="form-textarea"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Describe the work required"
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
      <div className="form-field">
        <label className="form-label">Assigned To</label>
        <input
          className="form-input"
          value={assignedTo}
          onChange={(e) => setAssignedTo(e.target.value)}
          placeholder="Technician name"
        />
      </div>
    </div>
  );
}