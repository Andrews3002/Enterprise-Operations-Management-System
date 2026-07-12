import { useState } from "react";
import {
    BarChart,
    Bar,
    XAxis,
    YAxis,
    Tooltip,
    ResponsiveContainer,
    PieChart,
    Pie,
    Cell,
    Legend,
    LineChart,
    Line,
    CartesianGrid,
} from "recharts";
import {
    getEfficiency,
    getWorkload,
    getIncidentTrend,
    getBottleneck,
    getBudget,
    getAging,
    getKpiTrend,
} from "../api";
import {
    h1,
    inputStyle,
    Card,
    Field,
    Btn,
    Feedback,
} from "../components/shared";

const COLORS = ["#2563eb", "#16a34a", "#f59e0b", "#dc2626", "#7c3aed"];

const REPORTS = [
    { key: "efficiency", label: "Dept Efficiency", fn: getEfficiency },
    { key: "budget", label: "Budget Utilisation", fn: getBudget },
    { key: "aging", label: "Request Aging", fn: getAging },
    { key: "bottleneck", label: "Workflow Bottleneck", fn: getBottleneck },
    { key: "trend", label: "Incident Trend", fn: getIncidentTrend },
    { key: "workload", label: "Employee Workload", fn: getWorkload },
    { key: "kpi", label: "KPI Trend", fn: getKpiTrend },
];

export default function Reports() {
    const [active, setActive] = useState(null);
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);

    const run = (report) => {
        setLoading(true);
        setActive(report.key);
        report
            .fn()
            .then((r) => setData(r.data))
            .finally(() => setLoading(false));
    };

    return (
        <div>
            <h1 style={h1}>Analytics & Reports</h1>

            <div
                style={{
                    display: "flex",
                    gap: 10,
                    flexWrap: "wrap",
                    marginBottom: 28,
                }}
            >
                {REPORTS.map((r) => (
                    <button
                        key={r.key}
                        onClick={() => run(r)}
                        style={{
                            padding: "8px 16px",
                            borderRadius: 6,
                            border: "1px solid #e2e8f0",
                            background: active === r.key ? "#1e293b" : "#fff",
                            color: active === r.key ? "#f1f5f9" : "#334155",
                            fontWeight: 600,
                            fontSize: 13,
                            cursor: "pointer",
                        }}
                    >
                        {r.label}
                    </button>
                ))}
            </div>

            {loading && <p style={{ color: "#64748b" }}>Loading…</p>}

            {!loading && data.length > 0 && (
                <div
                    style={{
                        background: "#fff",
                        borderRadius: 10,
                        padding: 24,
                        boxShadow: "0 1px 3px rgba(0,0,0,0.08)",
                    }}
                >
                    {/* Dept Efficiency — horizontal bar */}
                    {active === "efficiency" && (
                        <>
                            <h2 style={h2}>
                                Department Efficiency (avg resolution hours)
                            </h2>
                            <ResponsiveContainer width="100%" height={280}>
                                <BarChart
                                    data={data}
                                    layout="vertical"
                                    margin={{ left: 20 }}
                                >
                                    <XAxis
                                        type="number"
                                        tick={{ fontSize: 12 }}
                                    />
                                    <YAxis
                                        type="category"
                                        dataKey="dept_name"
                                        tick={{ fontSize: 13 }}
                                        width={160}
                                    />
                                    <Tooltip
                                        formatter={(v) => [
                                            `${v} hrs`,
                                            "Avg Resolution",
                                        ]}
                                    />
                                    <Bar
                                        dataKey="avg_resolution_h"
                                        fill="#2563eb"
                                        radius={[0, 4, 4, 0]}
                                    />
                                </BarChart>
                            </ResponsiveContainer>
                            <RawTable
                                data={data}
                                cols={[
                                    "dept_name",
                                    "total_incidents",
                                    "open_incidents",
                                    "avg_resolution_h",
                                    "efficiency_rank",
                                ]}
                            />
                        </>
                    )}

                    {/* Budget — pie + table */}
                    {active === "budget" && (
                        <>
                            <h2 style={h2}>Budget Utilisation</h2>
                            <div
                                style={{
                                    display: "grid",
                                    gridTemplateColumns: "1fr 1fr",
                                    gap: 24,
                                    alignItems: "center",
                                }}
                            >
                                <ResponsiveContainer width="100%" height={260}>
                                    <PieChart>
                                        <Pie
                                            data={data}
                                            dataKey="spent"
                                            nameKey="dept_name"
                                            cx="50%"
                                            cy="50%"
                                            outerRadius={100}
                                            label={({
                                                dept_name,
                                                pct_of_company_spend,
                                            }) =>
                                                `${dept_name} ${pct_of_company_spend}%`
                                            }
                                        >
                                            {data.map((_, i) => (
                                                <Cell
                                                    key={i}
                                                    fill={
                                                        COLORS[
                                                            i % COLORS.length
                                                        ]
                                                    }
                                                />
                                            ))}
                                        </Pie>
                                        <Tooltip
                                            formatter={(v) => [
                                                `$${Number(v).toLocaleString()}`,
                                                "Spent",
                                            ]}
                                        />
                                    </PieChart>
                                </ResponsiveContainer>
                                <RawTable
                                    data={data}
                                    cols={[
                                        "dept_name",
                                        "allocated",
                                        "spent",
                                        "pct_used",
                                        "spend_status",
                                    ]}
                                />
                            </div>
                        </>
                    )}

                    {/* Request Aging — bar by age bucket */}
                    {active === "aging" && (
                        <>
                            <h2 style={h2}>Open Request Aging</h2>
                            <RawTable
                                data={data}
                                cols={[
                                    "request_id",
                                    "workflow_name",
                                    "submitted_by",
                                    "waiting_at_stage",
                                    "hours_open",
                                    "age_bucket",
                                    "sla_status",
                                ]}
                            />
                        </>
                    )}

                    {/* Bottleneck */}
                    {active === "bottleneck" && (
                        <>
                            <h2 style={h2}>Workflow Bottleneck Analysis</h2>
                            <ResponsiveContainer width="100%" height={280}>
                                <BarChart data={data}>
                                    <XAxis
                                        dataKey="stage_name"
                                        tick={{ fontSize: 12 }}
                                    />
                                    <YAxis tick={{ fontSize: 12 }} />
                                    <Tooltip />
                                    <CartesianGrid
                                        strokeDasharray="3 3"
                                        vertical={false}
                                    />
                                    <Bar
                                        dataKey="avg_dwell_hours"
                                        fill="#f59e0b"
                                        radius={[4, 4, 0, 0]}
                                        name="Avg Dwell (hrs)"
                                    />
                                    <Bar
                                        dataKey="max_dwell_hours"
                                        fill="#dc2626"
                                        radius={[4, 4, 0, 0]}
                                        name="Max Dwell (hrs)"
                                    />
                                </BarChart>
                            </ResponsiveContainer>
                        </>
                    )}

                    {/* Incident trend — line per severity */}
                    {active === "trend" && (
                        <>
                            <h2 style={h2}>Incident Trend (last 8 weeks)</h2>
                            <RawTable
                                data={data}
                                cols={[
                                    "week_start",
                                    "severity",
                                    "incident_count",
                                    "running_total",
                                ]}
                            />
                        </>
                    )}

                    {/* Workload — table */}
                    {active === "workload" && (
                        <>
                            <h2 style={h2}>Employee Workload</h2>
                            <RawTable
                                data={data}
                                cols={[
                                    "dept_name",
                                    "employee_name",
                                    "active_tasks",
                                    "dept_workload_rank",
                                    "pct_of_dept_load",
                                ]}
                            />
                        </>
                    )}

                    {/* KPI trend */}
                    {active === "kpi" && (
                        <>
                            <h2 style={h2}>KPI Snapshot Trend</h2>
                            <RawTable
                                data={data}
                                cols={[
                                    "dept_name",
                                    "snapshot_date",
                                    "open_incidents",
                                    "open_requests",
                                    "sla_breaches",
                                    "budget_pct_used",
                                    "incident_delta",
                                ]}
                            />
                        </>
                    )}
                </div>
            )}
        </div>
    );
}

// Shared raw data table
function RawTable({ data, cols }) {
    if (!data.length) return null;
    return (
        <div style={{ overflowX: "auto", marginTop: 20 }}>
            <table
                style={{
                    width: "100%",
                    borderCollapse: "collapse",
                    fontSize: 13,
                }}
            >
                <thead>
                    <tr style={{ background: "#f8fafc" }}>
                        {cols.map((c) => (
                            <th
                                key={c}
                                style={{
                                    padding: "10px 12px",
                                    textAlign: "left",
                                    fontWeight: 600,
                                    color: "#475569",
                                    fontSize: 11,
                                    textTransform: "uppercase",
                                    borderBottom: "1px solid #e2e8f0",
                                }}
                            >
                                {c.replace(/_/g, " ")}
                            </th>
                        ))}
                    </tr>
                </thead>
                <tbody>
                    {data.map((row, i) => (
                        <tr
                            key={i}
                            style={{ borderBottom: "1px solid #f1f5f9" }}
                        >
                            {cols.map((c) => (
                                <td
                                    key={c}
                                    style={{
                                        padding: "10px 12px",
                                        color: "#334155",
                                    }}
                                >
                                    {row[c] ?? "—"}
                                </td>
                            ))}
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
}
