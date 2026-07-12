import {
    LayoutDashboard,
    FileText,
    AlertTriangle,
    CheckSquare,
    BarChart2,
} from "lucide-react";

const NAV = [
    { key: "dashboard", label: "Dashboard", icon: LayoutDashboard },
    { key: "requests", label: "Requests", icon: FileText },
    { key: "incidents", label: "Incidents", icon: AlertTriangle },
    { key: "tasks", label: "Tasks", icon: CheckSquare },
    { key: "reports", label: "Reports", icon: BarChart2 },
];

export default function Sidebar({ current, onNavigate }) {
    return (
        <aside
            style={{
                width: 220,
                background: "#1e293b",
                color: "#cbd5e1",
                display: "flex",
                flexDirection: "column",
                padding: "24px 0",
            }}
        >
            <div
                style={{
                    padding: "0 20px 28px",
                    borderBottom: "1px solid #334155",
                }}
            >
                <div
                    style={{
                        fontSize: 13,
                        fontWeight: 700,
                        color: "#94a3b8",
                        letterSpacing: "0.08em",
                        textTransform: "uppercase",
                    }}
                >
                    Enterprise Ops
                </div>
            </div>

            <nav style={{ padding: "16px 12px", flex: 1 }}>
                {NAV.map(({ key, label, icon: Icon }) => {
                    const active = current === key;
                    return (
                        <button
                            key={key}
                            onClick={() => onNavigate(key)}
                            style={{
                                display: "flex",
                                alignItems: "center",
                                gap: 10,
                                width: "100%",
                                padding: "10px 12px",
                                marginBottom: 2,
                                borderRadius: 8,
                                border: "none",
                                cursor: "pointer",
                                background: active ? "#0f172a" : "transparent",
                                color: active ? "#f1f5f9" : "#94a3b8",
                                fontWeight: active ? 600 : 400,
                                fontSize: 14,
                                textAlign: "left",
                            }}
                        >
                            <Icon size={16} />
                            {label}
                        </button>
                    );
                })}
            </nav>
        </aside>
    );
}
