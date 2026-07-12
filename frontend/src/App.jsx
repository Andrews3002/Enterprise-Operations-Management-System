import { useState } from "react";
import Sidebar from "./components/Sidebar";
import Dashboard from "./pages/Dashboard";
import Requests from "./pages/Requests";
import Incidents from "./pages/Incidents";
import Tasks from "./pages/Tasks";
import Reports from "./pages/Reports";

const PAGES = {
    dashboard: Dashboard,
    requests: Requests,
    incidents: Incidents,
    tasks: Tasks,
    reports: Reports,
};

export default function App() {
    const [page, setPage] = useState("dashboard");
    const Page = PAGES[page];

    return (
        <div
            style={{
                display: "flex",
                height: "100vh",
                fontFamily: "system-ui, sans-serif",
                background: "#f4f5f7",
            }}
        >
            <Sidebar current={page} onNavigate={setPage} />
            <main style={{ flex: 1, overflowY: "auto", padding: "32px" }}>
                <Page />
            </main>
        </div>
    );
}
