// TypeScript types mirroring the Rust backend models (src-tauri/src/models.rs)

export interface WorkOrder {
  id: string;
  title: string;
  description: string;
  status: "pending" | "in_progress" | "completed" | "cancelled";
  priority: "low" | "medium" | "high" | "urgent";
  assigned_to: string | null;
  created_by: string;
  property_id: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface Asset {
  id: string;
  name: string;
  asset_type: string;
  location: string;
  status: string;
  property_id: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface HelpdeskRequest {
  id: string;
  subject: string;
  description: string;
  status: "open" | "in_progress" | "closed";
  priority: "low" | "medium" | "high" | "urgent";
  resident_name: string;
  unit: string;
  property_id: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface SyncConflict {
  id: number;
  entity: string;
  entity_id: string;
  local_data: Record<string, unknown>;
  remote_data: Record<string, unknown>;
  resolved: boolean;
  created_at: string;
}

export interface SyncStatus {
  agent_running: boolean;
  pending_changes: number;
  unresolved_conflicts: number;
  last_sync_at: string | null;
  online: boolean;
}

export interface ChangeRecord {
  id: number;
  entity: string;
  entity_id: string;
  operation: "INSERT" | "UPDATE" | "DELETE";
  payload: Record<string, unknown>;
  client_id: string;
  changed_at: string;
  synced_at: string | null;
}

// DTOs for creating records
export interface NewWorkOrder {
  title: string;
  description: string;
  priority: string;
  assigned_to: string | null;
  property_id: string;
  created_by: string;
}

export interface UpdateWorkOrder {
  id: string;
  title?: string;
  description?: string;
  status?: string;
  priority?: string;
  assigned_to?: string;
}

export interface NewAsset {
  name: string;
  asset_type: string;
  location: string;
  status: string;
  property_id: string;
}

export interface NewHelpdeskRequest {
  subject: string;
  description: string;
  priority: string;
  resident_name: string;
  unit: string;
  property_id: string;
}

export interface ResolveConflict {
  conflict_id: number;
  action: "use_mine" | "use_cloud" | "merge";
  merged_record?: Record<string, unknown>;
}

// UI types
export interface UserInfo {
  id: string;
  email: string;
  role: string;
  authenticated: boolean;
}

export type ActiveView = "workorders" | "assets" | "helpdesk" | "conflicts" | "settings";
