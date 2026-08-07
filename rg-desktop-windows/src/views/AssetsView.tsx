import { useCallback, useEffect, useState } from "react";
import type { Asset, NewAsset } from "../types";
import { createAsset, deleteAsset, listAssets } from "../api";
import Badge from "../components/Badge";
import ConfirmModal from "../components/ConfirmModal";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";

interface AssetsViewProps {
  showToast: (message: string, type?: "success" | "error") => void;
}

const DEFAULT_PROPERTY_ID = "forster-park";

export default function AssetsView({ showToast }: AssetsViewProps) {
  const [assets, setAssets] = useState<Asset[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState<Asset | null>(null);

  // Form state
  const [name, setName] = useState("");
  const [assetType, setAssetType] = useState("");
  const [location, setLocation] = useState("");
  const [status, setStatus] = useState("operational");

  const loadAssets = useCallback(async () => {
    try {
      const data = await listAssets();
      setAssets(data);
    } catch (err) {
      showToast(`Failed to load assets: ${err}`, "error");
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    loadAssets();
  }, [loadAssets]);

  const resetForm = () => {
    setName("");
    setAssetType("");
    setLocation("");
    setStatus("operational");
  };

  const handleCreate = async () => {
    if (!name.trim()) {
      showToast("Name is required", "error");
      return;
    }
    if (!assetType.trim()) {
      showToast("Asset type is required", "error");
      return;
    }
    try {
      const input: NewAsset = {
        name: name.trim(),
        asset_type: assetType.trim(),
        location: location.trim(),
        status,
        property_id: DEFAULT_PROPERTY_ID,
      };
      await createAsset(input);
      showToast("Asset created");
      setShowCreate(false);
      resetForm();
      loadAssets();
    } catch (err) {
      showToast(`Failed to create asset: ${err}`, "error");
    }
  };

  const handleDelete = async (asset: Asset) => {
    setConfirmDelete(asset);
  };

  const handleConfirmDelete = async () => {
    if (!confirmDelete) return;
    try {
      await deleteAsset(confirmDelete.id);
      showToast("Asset deleted");
      setConfirmDelete(null);
      loadAssets();
    } catch (err) {
      showToast(`Failed to delete asset: ${err}`, "error");
      setConfirmDelete(null);
    }
  };

  const stats = {
    total: assets.length,
    operational: assets.filter((a) => a.status === "operational").length,
    maintenance: assets.filter((a) => a.status === "maintenance").length,
    outOfService: assets.filter((a) => a.status === "out_of_service").length,
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <div className="page-title">Assets</div>
          <div className="page-subtitle">Track equipment and building assets</div>
        </div>
        <button className="btn btn-primary" onClick={() => { resetForm(); setShowCreate(true); }}>
          New Asset
        </button>
      </div>

      <div className="stat-strip">
        <div className="stat-card">
          <div className="stat-label">Total</div>
          <div className="stat-value">{stats.total}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Operational</div>
          <div className="stat-value">{stats.operational}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Maintenance</div>
          <div className="stat-value">{stats.maintenance}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Out of Service</div>
          <div className="stat-value">{stats.outOfService}</div>
        </div>
      </div>

      <div className="card">
        {loading ? (
          <div className="card-body">Loading assets...</div>
        ) : assets.length === 0 ? (
          <EmptyState title="No assets yet" subtitle="Add your first asset to start tracking" />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Location</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {assets.map((asset) => (
                <tr key={asset.id}>
                  <td><strong>{asset.name}</strong></td>
                  <td>{asset.asset_type}</td>
                  <td>{asset.location || "—"}</td>
                  <td><Badge value={asset.status} /></td>
                  <td>
                    <button className="btn btn-ghost btn-sm" style={{ color: "var(--rg-danger)" }} onClick={() => handleDelete(asset)}>
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
          title="Delete Asset"
          message={`This will delete "${confirmDelete.name}" and apply the change to the PRODUCTION database via the sync agent. This cannot be undone.`}
          confirmLabel="Delete"
          danger
          onConfirm={handleConfirmDelete}
          onCancel={() => setConfirmDelete(null)}
        />
      )}

      {showCreate && (
        <Modal
          title="New Asset"
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
              <label className="form-label">Name *</label>
              <input
                className="form-input"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. HVAC Unit A-101"
                autoFocus
              />
            </div>
            <div className="form-field">
              <label className="form-label">Asset Type *</label>
              <input
                className="form-input"
                value={assetType}
                onChange={(e) => setAssetType(e.target.value)}
                placeholder="e.g. HVAC, Elevator, Pump"
              />
            </div>
            <div className="form-field">
              <label className="form-label">Location</label>
              <input
                className="form-input"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                placeholder="e.g. Roof, Basement, Unit 3"
              />
            </div>
            <div className="form-field">
              <label className="form-label">Status</label>
              <select className="form-select" value={status} onChange={(e) => setStatus(e.target.value)}>
                <option value="operational">Operational</option>
                <option value="maintenance">Maintenance</option>
                <option value="out_of_service">Out of Service</option>
              </select>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}