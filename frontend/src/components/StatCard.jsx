export default function StatCard({ label, value, sub, color = "#1e293b" }) {
    return (
        <div
            style={{
                background: "#fff",
                borderRadius: 10,
                padding: "20px 24px",
                boxShadow: "0 1px 3px rgba(0,0,0,0.08)",
                borderTop: `3px solid ${color}`,
            }}
        >
            <div
                style={{
                    fontSize: 12,
                    color: "#64748b",
                    fontWeight: 600,
                    textTransform: "uppercase",
                    letterSpacing: "0.06em",
                    marginBottom: 6,
                }}
            >
                {label}
            </div>
            <div style={{ fontSize: 28, fontWeight: 700, color: "#1e293b" }}>
                {value ?? "—"}
            </div>
            {sub && (
                <div style={{ fontSize: 12, color: "#94a3b8", marginTop: 4 }}>
                    {sub}
                </div>
            )}
        </div>
    );
}
