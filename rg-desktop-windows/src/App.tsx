import { useCallback, useEffect, useState } from "react";
import { check } from "@tauri-apps/plugin-updater";
import { relaunch } from "@tauri-apps/plugin-process";
import type { ActiveView, SyncStatus, UserInfo } from "./types";
import { getSyncStatus, getAuthToken } from "./api";
import Sidebar from "./components/Sidebar";
import TopBar from "./components/TopBar";
import WorkOrdersView from "./views/WorkOrdersView";
import AssetsView from "./views/AssetsView";
import HelpdeskView from "./views/HelpdeskView";
import ConflictsView from "./views/ConflictsView";
import SettingsView from "./views/SettingsView";
import LoginView from "./views/LoginView";

export default function App() {
  const [activeView, setActiveView] = useState<ActiveView>("workorders");
  const [syncStatus, setSyncStatus] = useState<SyncStatus | null>(null);
  const [toast, setToast] = useState<{ message: string; type: "success" | "error" } | null>(null);
  const [user, setUser] = useState<UserInfo | null>(null);
  const [showLogin, setShowLogin] = useState(false);

  const refreshSyncStatus = useCallback(async () => {
    try {
      const status = await getSyncStatus();
      setSyncStatus(status);
    } catch (err) {
      console.error("Failed to load sync status:", err);
    }
  }, []);

  const checkAuth = useCallback(async () => {
    try {
      const token = await getAuthToken();
      if (token) {
        // Decode token to get user info
        const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/').padEnd(4, '=')));
        setUser({
          id: payload.sub || '',
          email: payload.email || '',
          role: payload.role || 'unknown',
          authenticated: true,
        });
        setShowLogin(false);
      } else {
        setUser(null);
        setShowLogin(true);
      }
    } catch (err) {
      console.error("Failed to check auth:", err);
      setUser(null);
      setShowLogin(true);
    }
  }, []);

  // Load sync status on mount and poll every 5 seconds
  useEffect(() => {
    refreshSyncStatus();
    checkAuth();
    const interval = setInterval(refreshSyncStatus, 5000);
    return () => clearInterval(interval);
  }, [refreshSyncStatus]);

  // Check for updates on startup
  useEffect(() => {
    const checkForUpdates = async () => {
      try {
        const update = await check();
        if (update) {
          const confirmed = window.confirm(
            `A new version (${update.version}) is available. Download and install now?`
          );
          if (confirmed) {
            await update.downloadAndInstall();
            await relaunch();
          }
        }
      } catch (err) {
        console.error("Failed to check for updates:", err);
      }
    };
    checkForUpdates();
  }, []);

  const showToast = (message: string, type: "success" | "error" = "success") => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3000);
  };

  if (showLogin) {
    return (
      <div className="app-shell">
        <LoginView />
      </div>
    );
  }

  return (
    <div className="app-shell">
      <Sidebar activeView={activeView} onNavigate={setActiveView} conflictCount={syncStatus?.unresolved_conflicts ?? 0} />
      <div className="app-main">
        <TopBar
          activeView={activeView}
          syncStatus={syncStatus}
          onRefreshSync={refreshSyncStatus}
          user={user}
          onLogout={() => setShowLogin(true)}
        />
        <main className="app-content">
          {activeView === "workorders" && <WorkOrdersView showToast={showToast} />}
          {activeView === "assets" && <AssetsView showToast={showToast} />}
          {activeView === "helpdesk" && <HelpdeskView showToast={showToast} />}
          {activeView === "conflicts" && <ConflictsView showToast={showToast} />}
          {activeView === "settings" && <SettingsView showToast={showToast} />}
        </main>
      </div>
      {toast && (
        <div className={`toast toast-${toast.type}`}>
          {toast.message}
        </div>
      )}
    </div>
  );
}