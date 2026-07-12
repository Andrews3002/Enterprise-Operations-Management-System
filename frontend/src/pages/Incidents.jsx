import { useState } from "react";
import { logIncident, resolveIncident } from "../api";
import {
    h1,
    inputStyle,
    Card,
    Field,
    Btn,
    Feedback,
} from "../components/shared";

export default function Incidents() {
    const [logForm, setLog] = useState({
        dept_id: "",
        reported_by: "",
        title: "",
        severity: "HIGH",
        description: "",
    });
    const [resolveForm, setResolve] = useState({
        incident_id: "",
        resolved_by: "",
        resolution: "",
    });
    const [msg, setMsg] = useState("");
    const [err, setErr] = useState("");

    const respond = (promise) => {
        setMsg("");
        setErr("");
        promise
            .then((r) => setMsg(JSON.stringify(r.data)))
            .catch((e) => setErr(e.response?.data?.detail || e.message));
    };

    return (
        <div>
            <h1 style={h1}>Incidents</h1>
            <div
                style={{
                    display: "grid",
                    gridTemplateColumns: "1fr 1fr",
                    gap: 20,
                }}
            >
                <Card title="Log Incident">
                    {[
                        ["Department ID", "dept_id", "number"],
                        ["Reported By (emp_id)", "reported_by", "number"],
                        ["Title", "title", "text"],
                    ].map(([label, key, type]) => (
                        <Field key={key} label={label}>
                            <input
                                type={type}
                                value={logForm[key]}
                                onChange={(e) =>
                                    setLog({
                                        ...logForm,
                                        [key]: e.target.value,
                                    })
                                }
                                style={inputStyle}
                            />
                        </Field>
                    ))}
                    <Field label="Severity">
                        <select
                            value={logForm.severity}
                            onChange={(e) =>
                                setLog({ ...logForm, severity: e.target.value })
                            }
                            style={inputStyle}
                        >
                            {["CRITICAL", "HIGH", "MEDIUM", "LOW"].map((s) => (
                                <option key={s}>{s}</option>
                            ))}
                        </select>
                    </Field>
                    <Field label="Description">
                        <textarea
                            value={logForm.description}
                            onChange={(e) =>
                                setLog({
                                    ...logForm,
                                    description: e.target.value,
                                })
                            }
                            rows={2}
                            style={{ ...inputStyle, resize: "vertical" }}
                        />
                    </Field>
                    <Btn
                        onClick={() =>
                            respond(
                                logIncident({
                                    dept_id: +logForm.dept_id,
                                    reported_by: +logForm.reported_by,
                                    title: logForm.title,
                                    severity: logForm.severity,
                                    description: logForm.description || null,
                                }),
                            )
                        }
                    >
                        Log Incident
                    </Btn>
                </Card>

                <Card title="Resolve Incident">
                    <Field label="Incident ID">
                        <input
                            type="number"
                            value={resolveForm.incident_id}
                            onChange={(e) =>
                                setResolve({
                                    ...resolveForm,
                                    incident_id: e.target.value,
                                })
                            }
                            style={inputStyle}
                        />
                    </Field>
                    <Field label="Resolved By (emp_id)">
                        <input
                            type="number"
                            value={resolveForm.resolved_by}
                            onChange={(e) =>
                                setResolve({
                                    ...resolveForm,
                                    resolved_by: e.target.value,
                                })
                            }
                            style={inputStyle}
                        />
                    </Field>
                    <Field label="Resolution Notes">
                        <textarea
                            value={resolveForm.resolution}
                            onChange={(e) =>
                                setResolve({
                                    ...resolveForm,
                                    resolution: e.target.value,
                                })
                            }
                            rows={3}
                            style={{ ...inputStyle, resize: "vertical" }}
                        />
                    </Field>
                    <Btn
                        onClick={() =>
                            respond(
                                resolveIncident(+resolveForm.incident_id, {
                                    resolved_by: +resolveForm.resolved_by,
                                    resolution: resolveForm.resolution,
                                }),
                            )
                        }
                    >
                        Resolve
                    </Btn>
                </Card>
            </div>

            {msg && <Feedback type="success">{msg}</Feedback>}
            {err && <Feedback type="error">{err}</Feedback>}
        </div>
    );
}
