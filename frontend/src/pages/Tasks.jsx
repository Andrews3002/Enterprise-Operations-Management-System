import { useState } from "react";
import { assignTask, completeTask, cancelTask, reopenTask } from "../api";
import {
    h1,
    h2,
    inputStyle,
    Card,
    Field,
    Btn,
    Feedback,
} from "../components/shared";

export default function Tasks() {
    const [form, setForm] = useState({
        created_by: "",
        assigned_to: "",
        title: "",
        priority: "MEDIUM",
        due_date: "",
    });
    const [action, setAction] = useState({ task_id: "", actor_id: "" });
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
            <h1 style={h1}>Tasks</h1>
            <div
                style={{
                    display: "grid",
                    gridTemplateColumns: "1fr 1fr",
                    gap: 20,
                }}
            >
                <Card title="Assign Task">
                    {[
                        ["Created By (emp_id)", "created_by", "number"],
                        ["Assigned To (emp_id)", "assigned_to", "number"],
                        ["Title", "title", "text"],
                    ].map(([label, key, type]) => (
                        <Field key={key} label={label}>
                            <input
                                type={type}
                                value={form[key]}
                                onChange={(e) =>
                                    setForm({ ...form, [key]: e.target.value })
                                }
                                style={inputStyle}
                            />
                        </Field>
                    ))}
                    <Field label="Priority">
                        <select
                            value={form.priority}
                            onChange={(e) =>
                                setForm({ ...form, priority: e.target.value })
                            }
                            style={inputStyle}
                        >
                            {["HIGH", "MEDIUM", "LOW"].map((p) => (
                                <option key={p}>{p}</option>
                            ))}
                        </select>
                    </Field>
                    <Field label="Due Date">
                        <input
                            type="date"
                            value={form.due_date}
                            onChange={(e) =>
                                setForm({ ...form, due_date: e.target.value })
                            }
                            style={inputStyle}
                        />
                    </Field>
                    <Btn
                        onClick={() =>
                            respond(
                                assignTask({
                                    created_by: +form.created_by,
                                    assigned_to: +form.assigned_to,
                                    title: form.title,
                                    priority: form.priority,
                                    due_date: form.due_date || null,
                                }),
                            )
                        }
                    >
                        Assign
                    </Btn>
                </Card>

                <Card title="Task Actions">
                    <Field label="Task ID">
                        <input
                            type="number"
                            value={action.task_id}
                            onChange={(e) =>
                                setAction({
                                    ...action,
                                    task_id: e.target.value,
                                })
                            }
                            style={inputStyle}
                        />
                    </Field>
                    <Field label="Actor ID (emp_id)">
                        <input
                            type="number"
                            value={action.actor_id}
                            onChange={(e) =>
                                setAction({
                                    ...action,
                                    actor_id: e.target.value,
                                })
                            }
                            style={inputStyle}
                        />
                    </Field>
                    <div
                        style={{
                            display: "grid",
                            gridTemplateColumns: "1fr 1fr 1fr",
                            gap: 8,
                            marginTop: 8,
                        }}
                    >
                        <Btn
                            onClick={() =>
                                respond(
                                    completeTask(
                                        +action.task_id,
                                        +action.actor_id,
                                    ),
                                )
                            }
                            color="#16a34a"
                        >
                            Complete
                        </Btn>
                        <Btn
                            onClick={() =>
                                respond(
                                    reopenTask(
                                        +action.task_id,
                                        +action.actor_id,
                                    ),
                                )
                            }
                            color="#2563eb"
                        >
                            Reopen
                        </Btn>
                        <Btn
                            onClick={() =>
                                respond(
                                    cancelTask(
                                        +action.task_id,
                                        +action.actor_id,
                                    ),
                                )
                            }
                            color="#dc2626"
                        >
                            Cancel
                        </Btn>
                    </div>
                </Card>
            </div>

            {msg && <Feedback type="success">{msg}</Feedback>}
            {err && <Feedback type="error">{err}</Feedback>}
        </div>
    );
}
