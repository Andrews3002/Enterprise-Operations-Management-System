CREATE TABLE kpi_logs (
    kpi_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_id NUMBER NOT NULL,
    snapshot_date DATE DEFAULT SYSDATE NOT NULL,
    open_incidents NUMBER DEFAULT 0,
    resolved_today NUMBER DEFAULT 0,
    avg_resolution_h NUMBER(8,2),
    open_requests NUMBER DEFAULT 0,
    sla_breaches NUMBER DEFAULT 0,
    budget_pct_used NUMBER(5,2),
    CONSTRAINT fk_kpi_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE CASCADE
);