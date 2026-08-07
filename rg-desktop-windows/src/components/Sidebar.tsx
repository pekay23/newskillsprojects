import type { ActiveView } from "../types";

interface SidebarProps {
  activeView: ActiveView;
  onNavigate: (view: ActiveView) => void;
  conflictCount: number;
}

const NAV_ITEMS: { view: ActiveView; label: string; icon: string }[] = [
  { view: "workorders", label: "Work Orders", icon: "wrench" },
  { view: "assets", label: "Assets", icon: "box" },
  { view: "helpdesk", label: "Helpdesk", icon: "headset" },
  { view: "conflicts", label: "Sync Conflicts", icon: "alert" },
  { view: "settings", label: "Settings", icon: "gear" },
];

function Icon({ name, className }: { name: string; className?: string }) {
  const common = {
    className: className || "sidebar-nav-icon",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.8,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    viewBox: "0 0 24 24",
  };

  switch (name) {
    case "wrench":
      return (
        <svg {...common}>
          <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
        </svg>
      );
    case "box":
      return (
        <svg {...common}>
          <path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z" />
          <path d="m3.3 7 8.7 5 8.7-5" />
          <path d="M12 22V12" />
        </svg>
      );
    case "headset":
      return (
        <svg {...common}>
          <path d="M3 11h3a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-6Z" />
          <path d="M21 11h-3a1 1 0 0 0-1 1v5a1 1 0 0 0 1 1h2a1 1 0 0 0 1-1v-6Z" />
          <path d="M3 11a9 9 0 0 1 18 0" />
          <path d="M21 17v1a3 3 0 0 1-3 3h-4" />
        </svg>
      );
    case "alert":
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="10" />
          <path d="M12 8v4" />
          <path d="M12 16h.01" />
        </svg>
      );
    case "gear":
      return (
        <svg {...common}>
          <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" />
          <circle cx="12" cy="12" r="3" />
        </svg>
      );
    default:
      return null;
  }
}

export default function Sidebar({ activeView, onNavigate, conflictCount }: SidebarProps) {
  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <div className="sidebar-logo">RG</div>
        <div className="sidebar-brand-text">
          <span className="sidebar-brand-title">Raymond Gray</span>
          <span className="sidebar-brand-sub">IFM Platform</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        {NAV_ITEMS.map((item) => (
          <button
            key={item.view}
            className={`sidebar-nav-item ${activeView === item.view ? "active" : ""}`}
            onClick={() => onNavigate(item.view)}
          >
            <Icon name={item.icon} />
            <span>{item.label}</span>
            {item.view === "conflicts" && conflictCount > 0 && (
              <span className="sidebar-badge">{conflictCount}</span>
            )}
          </button>
        ))}
      </nav>

      <div className="sidebar-footer">
        <div>Offline-first facility management</div>
        <div>v1.0.0</div>
      </div>
    </aside>
  );
}