import { useEffect, useState } from "react";
import { getDashboard, refreshDashboard, takeSnapshot } from "../api";
import StatCard from "../components/StatCard";

export default function Dashboard() {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(true);
    const [msg, setMsg] = useState("");

    const load = () => {
        setLoading(true);
        getDashboard()
            .then((r) => setData(r.data))
            .finally(() => setLoading(false));
    };

    useEffect(() => {
        load();
    }, []);

    const handleRefresh = () =>
        refreshDashboard().then(() => {
            setMsg("Dashboard refreshed");
            load();
        });

    const handleSnapshot = () =>
        takeSnapshot().then(() => {
            setMsg("KPI snapshot taken");
            load();
        });

    if (loading) return <p style={{ color: "#64748b" }}>Loading…</p>;

    // Company-wide totals
    const totals = data.reduce(
        (acc, d) => ({
            open_incidents: acc.open_incidents + (d.open_incidents || 0),
            open_requests: acc.open_requests + (d.open_requests || 0),
            escalated_requests:
                acc.escalated_requests + (d.escalated_requests || 0),
            budget_spent: acc.budget_spent + (d.budget_spent || 0),
            budget_allocated: acc.budget_allocated + (d.budget_allocated || 0),
        }),
        {
            open_incidents: 0,
            open_requests: 0,
            escalated_requests: 0,
            budget_spent: 0,
            budget_allocated: 0,
        },
    );

    const budgetPct = totals.budget_allocated
        ? ((totals.budget_spent / totals.budget_allocated) * 100).toFixed(1)
        : 0;

    return (
        <div>
            <div
                style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    marginBottom: 28,
                }}
            >
                <h1
                    style={{
                        fontSize: 22,
                        fontWeight: 700,
                        color: "#1e293b",
                        margin: 0,
                    }}
                >
                    Operations Dashboard
                </h1>
                <div style={{ display: "flex", gap: 10 }}>
                    {msg && (
                        <span
                            style={{
                                fontSize: 13,
                                color: "#16a34a",
                                alignSelf: "center",
                            }}
                        >
                            {msg}
                        </span>
                    )}
                    <button
                        onClick={handleSnapshot}
                        style={btnStyle("#0f172a")}
                    >
                        Take Snapshot
                    </button>
                    <button onClick={handleRefresh} style={btnStyle("#2563eb")}>
                        Refresh View
                    </button>
                </div>
            </div>

            {/* Company-wide KPI strip */}
            <div
                style={{
                    display: "grid",
                    gridTemplateColumns: "repeat(4, 1fr)",
                    gap: 16,
                    marginBottom: 32,
                }}
            >
                <StatCard
                    label="Open Incidents"
                    value={totals.open_incidents}
                    color="#dc2626"
                />
                <StatCard
                    label="Open Requests"
                    value={totals.open_requests}
                    color="#2563eb"
                />
                <StatCard
                    label="Escalated Requests"
                    value={totals.escalated_requests}
                    color="#f59e0b"
                />
                <StatCard
                    label="Budget Used"
                    value={`${budgetPct}%`}
                    sub={`$${totals.budget_spent.toLocaleString()} of $${totals.budget_allocated.toLocaleString()}`}
                    color="#7c3aed"
                />
            </div>

            {/* Per-department table */}
            <div
                style={{
                    background: "#fff",
                    borderRadius: 10,
                    boxShadow: "0 1px 3px rgba(0,0,0,0.08)",
                    overflow: "hidden",
                }}
            >
                <table
                    style={{
                        width: "100%",
                        borderCollapse: "collapse",
                        fontSize: 14,
                    }}
                >
                    <thead>
                        <tr
                            style={{
                                background: "#f8fafc",
                                borderBottom: "1px solid #e2e8f0",
                            }}
                        >
                            {[
                                "Department",
                                "Open Incidents",
                                "Open Requests",
                                "Escalated",
                                "Avg Resolution (h)",
                                "Budget Used",
                                "Rank",
                            ].map((h) => (
                                <th
                                    key={h}
                                    style={{
                                        padding: "12px 16px",
                                        textAlign: "left",
                                        fontWeight: 600,
                                        color: "#475569",
                                        fontSize: 12,
                                        textTransform: "uppercase",
                                    }}
                                >
                                    {h}
                                </th>
                            ))}
                        </tr>
                    </thead>
                    <tbody>
                        {[...data]
                            .sort(
                                (a, b) => a.efficiency_rank - b.efficiency_rank,
                            )
                            .map((d) => (
                                <tr
                                    key={d.dept_id}
                                    style={{
                                        borderBottom: "1px solid #f1f5f9",
                                    }}
                                >
                                    <td style={tdStyle}>
                                        <strong>{d.dept_name}</strong>
                                    </td>
                                    <td style={tdStyle}>
                                        <span
                                            style={{
                                                color:
                                                    d.open_incidents > 0
                                                        ? "#dc2626"
                                                        : "#16a34a",
                                                fontWeight: 600,
                                            }}
                                        >
                                            {d.open_incidents}
                                        </span>
                                    </td>
                                    <td style={tdStyle}>{d.open_requests}</td>
                                    <td style={tdStyle}>
                                        {d.escalated_requests > 0 ? (
                                            <span
                                                style={{
                                                    color: "#f59e0b",
                                                    fontWeight: 600,
                                                }}
                                            >
                                                {d.escalated_requests}
                                            </span>
                                        ) : (
                                            "0"
                                        )}
                                    </td>
                                    <td style={tdStyle}>
                                        {d.avg_resolution_h ?? "—"}
                                    </td>
                                    <td style={tdStyle}>
                                        <div
                                            style={{
                                                display: "flex",
                                                alignItems: "center",
                                                gap: 8,
                                            }}
                                        >
                                            <div
                                                style={{
                                                    flex: 1,
                                                    background: "#e2e8f0",
                                                    borderRadius: 4,
                                                    height: 6,
                                                }}
                                            >
                                                <div
                                                    style={{
                                                        width: `${Math.min(d.budget_pct_used || 0, 100)}%`,
                                                        background:
                                                            d.budget_pct_used >
                                                            85
                                                                ? "#dc2626"
                                                                : "#2563eb",
                                                        height: "100%",
                                                        borderRadius: 4,
                                                    }}
                                                />
                                            </div>
                                            <span
                                                style={{
                                                    fontSize: 12,
                                                    color: "#64748b",
                                                    minWidth: 36,
                                                }}
                                            >
                                                {d.budget_pct_used ?? 0}%
                                            </span>
                                        </div>
                                    </td>
                                    <td style={tdStyle}>
                                        <span
                                            style={{
                                                background: "#f1f5f9",
                                                borderRadius: 12,
                                                padding: "2px 10px",
                                                fontSize: 12,
                                                fontWeight: 600,
                                                color: "#475569",
                                            }}
                                        >
                                            #{d.efficiency_rank}
                                        </span>
                                    </td>
                                </tr>
                            ))}
                    </tbody>
                </table>
                <div
                    style={{
                        padding: "10px 16px",
                        fontSize: 11,
                        color: "#94a3b8",
                        borderTop: "1px solid #f1f5f9",
                    }}
                >
                    Last refreshed: {data[0]?.last_refreshed ?? "—"}
                </div>
            </div>
        </div>
    );
}

const tdStyle = {
    padding: "12px 16px",
    color: "#334155",
    verticalAlign: "middle",
};
const btnStyle = (bg) => ({
    padding: "8px 16px",
    background: bg,
    color: "#fff",
    border: "none",
    borderRadius: 6,
    cursor: "pointer",
    fontSize: 13,
    fontWeight: 600,
});
