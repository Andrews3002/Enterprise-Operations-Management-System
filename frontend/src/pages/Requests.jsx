import { useState } from "react";
import {
    submitRequest,
    decideStage,
    getSlaStatus,
    escalateOverdue,
} from "../api";
import {
    h1,
    inputStyle,
    Card,
    Field,
    Btn,
    Feedback,
} from "../components/shared";

export default function Requests() {
    const [form, setForm] = useState({
        emp_id: "",
        workflow_id: "",
        notes: "",
    });
    const [decide, setDecide] = useState({
        request_id: "",
        decider_id: "",
        decision: "APPROVED",
        comments: "",
    });
    const [sla, setSla] = useState({ request_id: "", result: null });
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
            <h1 style={h1}>Requests</h1>

            <div
                style={{
                    display: "grid",
                    gridTemplateColumns: "1fr 1fr",
                    gap: 20,
                }}
            >
                {/* Submit request */}
                <Card title="Submit Request">
                    {[
                        ["Employee ID", "emp_id", "number"],
                        ["Workflow ID", "workflow_id", "number"],
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
                    <Field label="Notes">
                        <textarea
                            value={form.notes}
                            onChange={(e) =>
                                setForm({ ...form, notes: e.target.value })
                            }
                            rows={2}
                            style={{ ...inputStyle, resize: "vertical" }}
                        />
                    </Field>
                    <Btn
                        onClick={() =>
                            respond(
                                submitRequest({
                                    emp_id: +form.emp_id,
                                    workflow_id: +form.workflow_id,
                                    notes: form.notes || null,
                                }),
                            )
                        }
                    >
                        Submit
                    </Btn>
                </Card>

                {/* Decide stage */}
                <Card title="Decide Stage">
                    {[
                        ["Request ID", "request_id", "number"],
                        ["Decider ID", "decider_id", "number"],
                    ].map(([label, key, type]) => (
                        <Field key={key} label={label}>
                            <input
                                type={type}
                                value={decide[key]}
                                onChange={(e) =>
                                    setDecide({
                                        ...decide,
                                        [key]: e.target.value,
                                    })
                                }
                                style={inputStyle}
                            />
                        </Field>
                    ))}
                    <Field label="Decision">
                        <select
                            value={decide.decision}
                            onChange={(e) =>
                                setDecide({
                                    ...decide,
                                    decision: e.target.value,
                                })
                            }
                            style={inputStyle}
                        >
                            <option>APPROVED</option>
                            <option>REJECTED</option>
                        </select>
                    </Field>
                    <Field label="Comments">
                        <input
                            value={decide.comments}
                            onChange={(e) =>
                                setDecide({
                                    ...decide,
                                    comments: e.target.value,
                                })
                            }
                            style={inputStyle}
                        />
                    </Field>
                    <Btn
                        onClick={() =>
                            respond(
                                decideStage(+decide.request_id, {
                                    decider_id: +decide.decider_id,
                                    decision: decide.decision,
                                    comments: decide.comments || null,
                                }),
                            )
                        }
                    >
                        Record Decision
                    </Btn>
                </Card>

                {/* SLA status */}
                <Card title="Check SLA Status">
                    <Field label="Request ID">
                        <input
                            type="number"
                            value={sla.request_id}
                            onChange={(e) =>
                                setSla({ ...sla, request_id: e.target.value })
                            }
                            style={inputStyle}
                        />
                    </Field>
                    <Btn
                        onClick={() =>
                            getSlaStatus(+sla.request_id)
                                .then((r) => setSla({ ...sla, result: r.data }))
                                .catch((e) =>
                                    setErr(
                                        e.response?.data?.detail || e.message,
                                    ),
                                )
                        }
                    >
                        Check
                    </Btn>
                    {sla.result && (
                        <div
                            style={{
                                marginTop: 12,
                                padding: "10px 14px",
                                borderRadius: 6,
                                background:
                                    sla.result.sla_status === "ON_TRACK"
                                        ? "#dcfce7"
                                        : sla.result.sla_status === "AT_RISK"
                                          ? "#fef9c3"
                                          : "#fee2e2",
                                fontWeight: 600,
                                fontSize: 14,
                            }}
                        >
                            Request {sla.result.request_id}:{" "}
                            {sla.result.sla_status}
                        </div>
                    )}
                </Card>

                {/* Escalate overdue */}
                <Card title="Escalate Overdue">
                    <p
                        style={{
                            fontSize: 13,
                            color: "#64748b",
                            marginBottom: 12,
                        }}
                    >
                        Finds all requests past their SLA window and marks them
                        ESCALATED.
                    </p>
                    <Btn onClick={() => respond(escalateOverdue())}>
                        Run Escalation
                    </Btn>
                </Card>
            </div>

            {msg && (
                <div
                    style={{
                        marginTop: 16,
                        padding: "10px 14px",
                        background: "#dcfce7",
                        borderRadius: 6,
                        fontSize: 13,
                        color: "#15803d",
                    }}
                >
                    {msg}
                </div>
            )}
            {err && (
                <div
                    style={{
                        marginTop: 16,
                        padding: "10px 14px",
                        background: "#fee2e2",
                        borderRadius: 6,
                        fontSize: 13,
                        color: "#991b1b",
                    }}
                >
                    {err}
                </div>
            )}
        </div>
    );
}
