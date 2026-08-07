import { invoke } from "@tauri-apps/api/core";
import type {
  Asset,
  ChangeRecord,
  HelpdeskRequest,
  NewAsset,
  NewHelpdeskRequest,
  NewWorkOrder,
  ResolveConflict,
  SyncConflict,
  SyncStatus,
  UpdateWorkOrder,
  WorkOrder,
} from "./types";

// ================================================================
// Work Orders
// ================================================================

export function listWorkOrders(): Promise<WorkOrder[]> {
  return invoke("list_work_orders");
}

export function getWorkOrder(id: string): Promise<WorkOrder | null> {
  return invoke("get_work_order", { id });
}

export function createWorkOrder(input: NewWorkOrder): Promise<WorkOrder> {
  return invoke("create_work_order", { input });
}

export function updateWorkOrder(input: UpdateWorkOrder): Promise<WorkOrder | null> {
  return invoke("update_work_order", { input });
}

export function deleteWorkOrder(id: string): Promise<boolean> {
  return invoke("delete_work_order", { id });
}

// ================================================================
// ASSETS
// ================================================================

export function listAssets(): Promise<Asset[]> {
  return invoke("list_assets");
}

export function createAsset(input: NewAsset): Promise<Asset> {
  return invoke("create_asset", { input });
}

export function deleteAsset(id: string): Promise<boolean> {
  return invoke("delete_asset", { id });
}

// ================================================================
// HELPDESK REQUESTS
// ================================================================

export function listHelpdeskRequests(): Promise<HelpdeskRequest[]> {
  return invoke("list_helpdesk_requests");
}

export function createHelpdeskRequest(input: NewHelpdeskRequest): Promise<HelpdeskRequest> {
  return invoke("create_helpdesk_request", { input });
}

export function deleteHelpdeskRequest(id: string): Promise<boolean> {
  return invoke("delete_helpdesk_request", { id });
}

// ================================================================
// SYNC & CONFLICTS
// ================================================================

export function getSyncStatus(): Promise<SyncStatus> {
  return invoke("get_sync_status");
}

export function setGatewayUrl(url: string): Promise<void> {
  return invoke("set_gateway_url", { url });
}

export function getConflicts(): Promise<SyncConflict[]> {
  return invoke("get_conflicts");
}

export function resolveConflict(input: ResolveConflict): Promise<boolean> {
  return invoke("resolve_conflict", { input });
}

export function getClientId(): Promise<string> {
  return invoke("get_client_id");
}

export function getPendingChanges(limit?: number): Promise<ChangeRecord[]> {
  return invoke("get_pending_changes", { limit });
}

export function syncNow(ids: number[]): Promise<void> {
  return invoke("sync_now", { ids });
}

/// Get the stored auth token (for sync agent).
export function getAuthToken(): Promise<string | null> {
  return invoke("get_auth_token");
}