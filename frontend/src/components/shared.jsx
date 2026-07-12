export const h1 = {
    fontSize: 22,
    fontWeight: 700,
    color: "#1e293b",
    marginBottom: 24,
    marginTop: 0,
};
export const h2 = {
    fontSize: 16,
    fontWeight: 600,
    color: "#1e293b",
    marginBottom: 16,
    marginTop: 0,
};

export const inputStyle = {
    width: "100%",
    padding: "8px 10px",
    border: "1px solid #e2e8f0",
    borderRadius: 6,
    fontSize: 14,
    outline: "none",
    boxSizing: "border-box",
};

export function Card({ title, children }) {
    return (
        <div
            style={{
                background: "#fff",
                borderRadius: 10,
                padding: 24,
                boxShadow: "0 1px 3px rgba(0,0,0,0.08)",
            }}
        >
            <h2 style={{ ...h2, marginBottom: 16 }}>{title}</h2>
            {children}
        </div>
    );
}

export function Field({ label, children }) {
    return (
        <div style={{ marginBottom: 14 }}>
            <label
                style={{
                    display: "block",
                    fontSize: 12,
                    fontWeight: 600,
                    color: "#64748b",
                    marginBottom: 5,
                    textTransform: "uppercase",
                }}
            >
                {label}
            </label>
            {children}
        </div>
    );
}

export function Btn({ children, onClick, color = "#1e293b" }) {
    return (
        <button
            onClick={onClick}
            style={{
                padding: "9px 18px",
                background: color,
                color: "#fff",
                border: "none",
                borderRadius: 6,
                cursor: "pointer",
                fontSize: 14,
                fontWeight: 600,
                marginTop: 4,
            }}
        >
            {children}
        </button>
    );
}

export function Feedback({ type, children }) {
    const colors = {
        success: { background: "#dcfce7", color: "#15803d" },
        error: { background: "#fee2e2", color: "#991b1b" },
    };
    return (
        <div
            style={{
                marginTop: 16,
                padding: "10px 14px",
                borderRadius: 6,
                fontSize: 13,
                ...colors[type],
            }}
        >
            {children}
        </div>
    );
}
