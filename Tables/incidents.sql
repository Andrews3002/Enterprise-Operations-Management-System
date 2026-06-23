CREATE TABLE incidents (
    incident_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_id NUMBER NOT NULL,
    reported_by NUMBER NOT NULL,
    assigned_to NUMBER,
    title VARCHAR2(200) NOT NULL,
    description CLOB,
    severity VARCHAR2(10) NOT NULL,
    status VARCHAR2(20) DEFAULT 'OPEN' NOT NULL,
    reported_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    resolution_min NUMBER,
    CONSTRAINT fk_inc_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id),
    CONSTRAINT fk_inc_reporter FOREIGN KEY (reported_by) REFERENCES employees(emp_id),
    CONSTRAINT fk_inc_assignee FOREIGN KEY (assigned_to) REFERENCES employees(emp_id),
    CONSTRAINT check_inc_severity CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    CONSTRAINT check_inc_status CHECK (status IN ('OPEN','IN_PROGRESS','RESOLVED','CLOSED'))
);