CREATE TABLE departments (
    dept_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name   VARCHAR2(100) NOT NULL,
    manager_id  NUMBER,
    created_at  TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE roles (
    role_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name   VARCHAR2(50)  NOT NULL UNIQUE,
    role_level  NUMBER(1)     NOT NULL,
    CONSTRAINT check_role_level CHECK (role_level BETWEEN 1 AND 5)
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE workflows (
    workflow_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workflow_name VARCHAR2(100) NOT NULL UNIQUE,
    description   VARCHAR2(500),
    sla_hours     NUMBER(5)    NOT NULL,
    is_active     NUMBER(1)    DEFAULT 1 NOT NULL,
    CONSTRAINT check_workflow_active CHECK (is_active IN (0,1))
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE employees (
    emp_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name   VARCHAR2(50)  NOT NULL,
    last_name    VARCHAR2(50)  NOT NULL,
    email        VARCHAR2(150) NOT NULL UNIQUE,
    dept_id      NUMBER        NOT NULL,
    role_id      NUMBER        NOT NULL,
    hire_date    DATE          DEFAULT SYSDATE NOT NULL,
    is_active    NUMBER(1)     DEFAULT 1 NOT NULL,
    CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id),
    CONSTRAINT fk_emp_role FOREIGN KEY (role_id) REFERENCES roles(role_id),
    CONSTRAINT check_employee_active CHECK (is_active IN (0,1))
);
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE departments
    ADD CONSTRAINT fk_dept_manager FOREIGN KEY (manager_id) REFERENCES employees(emp_id);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE workflow_stages (
    stage_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workflow_id    NUMBER       NOT NULL,
    stage_name     VARCHAR2(100) NOT NULL,
    stage_seq      NUMBER(3)    NOT NULL,
    required_level NUMBER(1)    NOT NULL,
    CONSTRAINT fk_wfstage_workflow FOREIGN KEY (workflow_id) REFERENCES workflows(workflow_id),
    CONSTRAINT uq_wf_seq UNIQUE (workflow_id, stage_seq)
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE budgets (
    budget_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_id      NUMBER         NOT NULL,
    fiscal_year  NUMBER(4)      NOT NULL,
    allocated    NUMBER(12,2)   NOT NULL,
    spent        NUMBER(12,2)   DEFAULT 0 NOT NULL,
    CONSTRAINT fk_budget_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id),
    CONSTRAINT uq_budget_dept_year UNIQUE (dept_id, fiscal_year),
    CONSTRAINT check_budget_spent CHECK (spent >= 0)
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE requests (
    request_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workflow_id     NUMBER        NOT NULL,
    submitted_by    NUMBER        NOT NULL,
    current_stage   NUMBER,
    status          VARCHAR2(20)  DEFAULT 'PENDING' NOT NULL,
    notes           VARCHAR2(1000),
    submitted_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at     TIMESTAMP,
    CONSTRAINT fk_req_workflow  FOREIGN KEY (workflow_id)   REFERENCES workflows(workflow_id),
    CONSTRAINT fk_req_submitter FOREIGN KEY (submitted_by)  REFERENCES employees(emp_id),
    CONSTRAINT fk_req_stage     FOREIGN KEY (current_stage) REFERENCES workflow_stages(stage_id),
    CONSTRAINT check_req_status   CHECK (status IN ('PENDING','IN_REVIEW','APPROVED','REJECTED','ESCALATED','CLOSED'))
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE decisions (
    decision_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    request_id    NUMBER        NOT NULL,
    stage_id      NUMBER        NOT NULL,
    decider_id   NUMBER        NOT NULL,
    decision      VARCHAR2(10)  NOT NULL,
    decision_at   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    comments      VARCHAR2(500),
    CONSTRAINT fk_decision_request  FOREIGN KEY (request_id)  REFERENCES requests(request_id),
    CONSTRAINT fk_decision_stage    FOREIGN KEY (stage_id)    REFERENCES workflow_stages(stage_id),
    CONSTRAINT fk_decision_decider FOREIGN KEY (decider_id) REFERENCES employees(emp_id),
    CONSTRAINT check_decision CHECK (decision IN ('APPROVED','REJECTED'))
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE incidents (
    incident_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_id        NUMBER        NOT NULL,
    reported_by    NUMBER        NOT NULL,
    assigned_to    NUMBER,
    title          VARCHAR2(200) NOT NULL,
    description    CLOB,
    severity       VARCHAR2(10)  NOT NULL,
    status         VARCHAR2(20)  DEFAULT 'OPEN' NOT NULL,
    reported_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at    TIMESTAMP,
    resolution_min NUMBER,                 -- computed by trigger on resolution
    CONSTRAINT fk_inc_dept     FOREIGN KEY (dept_id)     REFERENCES departments(dept_id),
    CONSTRAINT fk_inc_reporter FOREIGN KEY (reported_by) REFERENCES employees(emp_id),
    CONSTRAINT fk_inc_assignee FOREIGN KEY (assigned_to) REFERENCES employees(emp_id),
    CONSTRAINT check_inc_severity CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    CONSTRAINT check_inc_status   CHECK (status IN ('OPEN','IN_PROGRESS','RESOLVED','CLOSED'))
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE tasks (
    task_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    assigned_to  NUMBER        NOT NULL,
    created_by   NUMBER        NOT NULL,
    title        VARCHAR2(200) NOT NULL,
    priority     VARCHAR2(10)  DEFAULT 'MEDIUM' NOT NULL,
    status       VARCHAR2(20)  DEFAULT 'OPEN' NOT NULL,
    due_date     DATE,
    completed_at TIMESTAMP,
    CONSTRAINT fk_task_assignee FOREIGN KEY (assigned_to) REFERENCES employees(emp_id),
    CONSTRAINT fk_task_creator  FOREIGN KEY (created_by)  REFERENCES employees(emp_id),
    CONSTRAINT check_task_priority CHECK (priority IN ('HIGH','MEDIUM','LOW')),
    CONSTRAINT check_task_status   CHECK (status IN ('OPEN','IN_PROGRESS','DONE','CANCELLED'))
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE kpi_logs (
    kpi_id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_id          NUMBER       NOT NULL,
    snapshot_date    DATE         DEFAULT SYSDATE NOT NULL,
    open_incidents   NUMBER       DEFAULT 0,
    resolved_today   NUMBER       DEFAULT 0,
    avg_resolution_h NUMBER(8,2),
    open_requests    NUMBER       DEFAULT 0,
    sla_breaches     NUMBER       DEFAULT 0,
    budget_pct_used  NUMBER(5,2),
    CONSTRAINT fk_kpi_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE audit_log (
    audit_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name   VARCHAR2(50)  NOT NULL,
    record_id    NUMBER        NOT NULL,
    action       VARCHAR2(10)  NOT NULL,
    changed_by   NUMBER,
    old_value    VARCHAR2(4000),
    new_value    VARCHAR2(4000),
    changed_at   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT check_audit_action CHECK (action IN ('INSERT','UPDATE','DELETE'))
);
----------------------------------------------------------------------------------------------------------------------------------
CREATE INDEX idx_requests_status      ON requests(status);
CREATE INDEX idx_requests_submitter   ON requests(submitted_by);
CREATE INDEX idx_requests_workflow    ON requests(workflow_id);
CREATE INDEX idx_requests_submitted   ON requests(submitted_at);
----------------------------------------------------------------------------------------------------------------------------------
CREATE INDEX idx_incidents_dept       ON incidents(dept_id);
CREATE INDEX idx_incidents_severity   ON incidents(severity);
CREATE INDEX idx_incidents_status     ON incidents(status);
CREATE INDEX idx_incidents_reported   ON incidents(reported_at);
----------------------------------------------------------------------------------------------------------------------------------
CREATE INDEX idx_incidents_sla ON incidents(status, reported_at);
----------------------------------------------------------------------------------------------------------------------------------
CREATE INDEX idx_decision_request    ON decisions(request_id);
CREATE INDEX idx_decisions_decider  ON decisions(decider_id);
----------------------------------------------------------------------------------------------------------------------------------
ALTER INDEX idx_decision_request
RENAME TO idx_decisions_request;
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE audit_log
RENAME TO audit_logs
----------------------------------------------------------------------------------------------------------------------------------
CREATE INDEX idx_employees_dept       ON employees(dept_id);
CREATE INDEX idx_employees_role       ON employees(role_id);
----------------------------------------------------------------------------------------------------------------------------------
CREATE INDEX idx_audit_table_record   ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_changed_at     ON audit_logs(changed_at);
----------------------------------------------------------------------------------------------------------------------------------
CREATE INDEX idx_kpi_dept_date        ON kpi_logs(dept_id, snapshot_date);
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO roles (role_name, role_level) VALUES ('Employee',   1);
INSERT INTO roles (role_name, role_level) VALUES ('Supervisor', 2);
INSERT INTO roles (role_name, role_level) VALUES ('Ops Manager',3);
INSERT INTO roles (role_name, role_level) VALUES ('Executive',  4);
INSERT INTO roles (role_name, role_level) VALUES ('Auditor',    5);

INSERT INTO departments (dept_name) VALUES ('Human Resources');
INSERT INTO departments (dept_name) VALUES ('Information Technology');
INSERT INTO departments (dept_name) VALUES ('Accounts');
INSERT INTO departments (dept_name) VALUES ('Operations');

INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Leave Request',       48);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Equipment Request',   72);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Overtime Approval',   24);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Incident Report',     12);

INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, required_level)
    VALUES (1, 'Supervisor Review', 1, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, required_level)
    VALUES (1, 'HR Approval',       2, 3);

INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, required_level)
    VALUES (2, 'Supervisor Review', 1, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, required_level)
    VALUES (2, 'IT Approval',       2, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, required_level)
    VALUES (2, 'Finance Sign-off',  3, 3);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
-- 1. Confirm all tables exist
SELECT table_name FROM user_tables ORDER BY table_name;

-- 2. Confirm all foreign keys
SELECT constraint_name, table_name, r_constraint_name
FROM user_constraints
WHERE constraint_type = 'R'
ORDER BY table_name;

-- 3. Confirm all indexes
SELECT index_name, table_name, uniqueness
FROM user_indexes
ORDER BY table_name;

-- 4. Test a basic join across all three layers
SELECT e.first_name, d.dept_name, r.role_name
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
JOIN roles      r ON e.role_id  = r.role_id;
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE log_audit (
    p_table_name  IN VARCHAR2,
    p_record_id   IN NUMBER,
    p_action      IN VARCHAR2,
    p_changed_by  IN NUMBER,
    p_old_value   IN VARCHAR2 DEFAULT NULL,
    p_new_value   IN VARCHAR2 DEFAULT NULL
) AS
BEGIN
    INSERT INTO audit_logs (
        table_name, record_id, action,
        changed_by, old_value, new_value, changed_at
    ) VALUES (
        p_table_name, p_record_id, p_action,
        p_changed_by, p_old_value, p_new_value, SYSTIMESTAMP
    );
    -- no need to add a commit because the commit will be used when the procedure is called
END log_audit;
/
----------------------------------------------------------------------------------------------------------------------------------
create or replace PROCEDURE log_audit (
    p_table_name  IN VARCHAR2,
    p_record_id   IN NUMBER,
    p_action      IN VARCHAR2,
    p_changed_by  IN NUMBER,
    p_old_value   IN VARCHAR2 DEFAULT NULL,
    p_new_value   IN VARCHAR2 DEFAULT NULL
) AS
BEGIN
    INSERT INTO audit_logs (
        table_name, record_id, action,
        changed_by, old_value, new_value, changed_at
    ) VALUES (
        p_table_name, p_record_id, p_action,
        p_changed_by, p_old_value, p_new_value, SYSTIMESTAMP
    );
    -- no need to add a commit incase you need to rollback after the procedure is called
END log_audit;
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
DROP CONSTRAINT check_req_status;
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
ADD CONSTRAINT check_req_status
CHECK (
    status IN (
        'PENDING',
        'IN_REVIEW',
        'APPROVED',
        'REJECTED',
        'IN_PROGRESS',
        'COMPLETED',
        'CANCELLED',
        'ESCALATED'
    )
);
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE workflows
ADD department_id NUMBER;
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE workflows
RENAME COLUMN department_id TO dept_id;
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE workflows
ADD CONSTRAINT fk_workflow_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id);
----------------------------------------------------------------------------------------------------------------------------------
-- Assign an owning department to every workflow
UPDATE workflows SET dept_id = 1 WHERE workflow_name = 'Leave Request';       -- HR owns leave policy
UPDATE workflows SET dept_id = 2 WHERE workflow_name = 'Equipment Request';   -- IT owns equipment
UPDATE workflows SET dept_id = 1 WHERE workflow_name = 'Overtime Approval';   -- HR owns overtime policy
UPDATE workflows SET dept_id = 4 WHERE workflow_name = 'Incident Report';     -- Operations owns incident handling
COMMIT;

-- Now enforce NOT NULL
ALTER TABLE workflows
MODIFY dept_id NUMBER NOT NULL;
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id      IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes       IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id  IN NUMBER,
        p_decider_id  IN NUMBER,
        p_decision    IN VARCHAR2,
        p_comments    IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY workflow_pkg AS

    
    --------------------------------------------------------- get the first stage_id for a workflow
    FUNCTION get_first_stage (p_workflow_id IN NUMBER) RETURN NUMBER AS
        v_stage_id workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_id
        INTO   v_stage_id
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id = p_workflow_id
               );
        RETURN v_stage_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'No stages defined for workflow_id ' || p_workflow_id);
    END get_first_stage;

    
    ----------------------------- get the next stage_id after the current one for the specific workflow
    FUNCTION get_next_stage (
        p_workflow_id IN NUMBER,
        p_current_stage_id IN NUMBER
    ) RETURN NUMBER AS
        v_current_seq  workflow_stages.stage_seq%TYPE;
        v_next_stage   workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_seq INTO v_current_seq
        FROM   workflow_stages
        WHERE  stage_id = p_current_stage_id;

        SELECT stage_id INTO v_next_stage
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id  = p_workflow_id
                   AND    stage_seq    > v_current_seq
               );
        RETURN v_next_stage;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_next_stage;


    ------------------------------------------------------------------- submit_request
    FUNCTION submit_request (
        p_emp_id      IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes       IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER AS
        v_request_id  requests.request_id%TYPE;
        v_first_stage requests.current_stage%TYPE;
    BEGIN
        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   employees
            WHERE  emp_id = p_emp_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'Employee ' || p_emp_id || ' not found or inactive.');
        END;

        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   workflows
            WHERE  workflow_id = p_workflow_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'Workflow ' || p_workflow_id || ' not found or inactive.');
        END;

        v_first_stage := get_first_stage(p_workflow_id);

        INSERT INTO requests (
            workflow_id, submitted_by, current_stage, status, notes
        ) VALUES (
            p_workflow_id, p_emp_id, v_first_stage, 'PENDING', p_notes
        )
        RETURNING request_id INTO v_request_id;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => v_request_id,
            p_action     => 'INSERT',
            p_changed_by => p_emp_id,
            p_new_value  => 'status=PENDING, stage=' || v_first_stage
        );

        COMMIT;
        RETURN v_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END submit_request;

    ----------------------------------------------------------------------- decide_stage
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision   IN VARCHAR2,
        p_comments   IN VARCHAR2 DEFAULT NULL
    ) AS
        v_workflow_id    requests.workflow_id%TYPE;
        v_current_stage  requests.current_stage%TYPE;
        v_old_status     requests.status%TYPE;
        v_next_stage     workflow_stages.stage_id%TYPE;
        v_next_stage_name workflow_stages.stage_name%TYPE;
        v_new_status     requests.status%TYPE;
        v_required_level workflow_stages.required_level%TYPE;
        v_decider_level  roles.role_level%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO   v_workflow_id, v_current_stage, v_old_status
        FROM   requests
        WHERE  request_id = p_request_id
        FOR UPDATE;

        IF v_old_status NOT IN ('PENDING', 'IN_REVIEW', 'ESCALATED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level
        INTO   v_required_level, v_decider_level
        FROM   workflow_stages ws
        JOIN   employees e  ON e.emp_id  = p_decider_id
        JOIN   roles     r  ON r.role_id = e.role_id
        WHERE  ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        INSERT INTO decisions (
            request_id, stage_id, decider_id, decision, comments
        ) VALUES (
            p_request_id, v_current_stage, p_decider_id, p_decision, p_comments
        );

        IF p_decision = 'APPROVED' THEN
            v_next_stage := get_next_stage(v_workflow_id, v_current_stage);

            SELECT stage_name
            INTO v_next_stage_name
            FROM workflow_stages
            WHERE stage_id = v_next_stage;

            IF v_next_stage IS NULL THEN
                v_new_status := 'COMPLETED';
                UPDATE requests
                SET    status        = v_new_status,
                       current_stage = NULL,
                       resolved_at   = SYSTIMESTAMP
                WHERE  request_id    = p_request_id;
            ELSIF v_next_stage_name = 'Implementation' THEN
                v_new_status := 'APPROVED';
                UPDATE requests
                SET    status        = v_new_status,
                       current_stage = v_next_stage
                WHERE  request_id    = p_request_id;
            ELSE
                v_new_status := 'IN_REVIEW';
                UPDATE requests
                SET    status        = v_new_status,
                       current_stage = v_next_stage
                WHERE  request_id    = p_request_id;
            END IF;

        ELSIF p_decision = 'REJECTED' THEN
            v_new_status := 'REJECTED';
            UPDATE requests
            SET    status        = v_new_status,
                   current_stage = NULL,
                   resolved_at   = SYSTIMESTAMP
            WHERE  request_id    = p_request_id;
        END IF;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => p_request_id,
            p_action     => 'UPDATE',
            p_changed_by => p_decider_id,
            p_old_value  => 'status=' || v_old_status,
            p_new_value  => 'status=' || v_new_status
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END decide_stage;

    ------------------------------------------------------------------ escalate_overdue requests
    PROCEDURE escalate_overdue AS
        CURSOR c_overdue IS
            SELECT r.request_id, r.submitted_at, w.sla_hours
            FROM   requests  r
            JOIN   workflows w ON w.workflow_id = r.workflow_id
            WHERE  r.status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'IN_PROGRESS')
            AND    r.submitted_at + (w.sla_hours / 24) < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            SELECT status
            INTO v_old_status
            FROM requests
            WHERE request_id = rec.request_id;

            UPDATE requests
            SET    status = 'ESCALATED'
            WHERE  request_id = rec.request_id;

            log_audit(
                p_table_name => 'REQUESTS',
                p_record_id  => rec.request_id,
                p_action     => 'UPDATE',
                p_changed_by => NULL,
                p_old_value  => v_old_status,
                p_new_value  => 'status=ESCALATED'
            );

            v_count := v_count + 1;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Escalated ' || v_count || ' overdue requests.');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END escalate_overdue;

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted  TIMESTAMP;
        v_sla_hours  NUMBER;
        v_hours_used NUMBER;
        v_pct        NUMBER;
    BEGIN
        SELECT r.submitted_at, w.sla_hours
        INTO   v_submitted, v_sla_hours
        FROM   requests  r
        JOIN   workflows w ON w.workflow_id = r.workflow_id
        WHERE  r.request_id = p_request_id;

        v_hours_used := (SYSTIMESTAMP - v_submitted) * 24;
        v_pct        := (v_hours_used / v_sla_hours) * 100;

        IF    v_pct < 70  THEN RETURN 'ON_TRACK';
        ELSIF v_pct < 100 THEN RETURN 'AT_RISK';
        ELSE                   RETURN 'BREACHED';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Request ' || p_request_id || ' not found.');
    END get_sla_status;

END workflow_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY workflow_pkg AS

    
    --------------------------------------------------------- get the first stage_id for a workflow
    FUNCTION get_first_stage (p_workflow_id IN NUMBER) RETURN NUMBER AS
        v_stage_id workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_id
        INTO   v_stage_id
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id = p_workflow_id
               );
        RETURN v_stage_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'No stages defined for workflow_id ' || p_workflow_id);
    END get_first_stage;

    
    ----------------------------- get the next stage_id after the current one for the specific workflow
    FUNCTION get_next_stage (
        p_workflow_id IN NUMBER,
        p_current_stage_id IN NUMBER
    ) RETURN NUMBER AS
        v_current_seq  workflow_stages.stage_seq%TYPE;
        v_next_stage   workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_seq INTO v_current_seq
        FROM   workflow_stages
        WHERE  stage_id = p_current_stage_id;

        SELECT stage_id INTO v_next_stage
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id  = p_workflow_id
                   AND    stage_seq    > v_current_seq
               );
        RETURN v_next_stage;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_next_stage;


    ------------------------------------------------------------------- submit_request
    FUNCTION submit_request (
        p_emp_id      IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes       IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER AS
        v_request_id  requests.request_id%TYPE;
        v_first_stage requests.current_stage%TYPE;
    BEGIN
        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   employees
            WHERE  emp_id = p_emp_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'Employee ' || p_emp_id || ' not found or inactive.');
        END;

        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   workflows
            WHERE  workflow_id = p_workflow_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'Workflow ' || p_workflow_id || ' not found or inactive.');
        END;

        v_first_stage := get_first_stage(p_workflow_id);

        INSERT INTO requests (
            workflow_id, submitted_by, current_stage, status, notes
        ) VALUES (
            p_workflow_id, p_emp_id, v_first_stage, 'PENDING', p_notes
        )
        RETURNING request_id INTO v_request_id;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => v_request_id,
            p_action     => 'INSERT',
            p_changed_by => p_emp_id,
            p_new_value  => 'status=PENDING, stage=' || v_first_stage
        );

        COMMIT;
        RETURN v_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END submit_request;

    ----------------------------------------------------------------------- decide_stage
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision   IN VARCHAR2,
        p_comments   IN VARCHAR2 DEFAULT NULL
    ) AS
        v_workflow_id    requests.workflow_id%TYPE;
        v_current_stage  requests.current_stage%TYPE;
        v_old_status     requests.status%TYPE;
        v_next_stage     workflow_stages.stage_id%TYPE;
        v_next_stage_name workflow_stages.stage_name%TYPE;
        v_new_status     requests.status%TYPE;
        v_required_level workflow_stages.required_level%TYPE;
        v_decider_level  roles.role_level%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO   v_workflow_id, v_current_stage, v_old_status
        FROM   requests
        WHERE  request_id = p_request_id
        FOR UPDATE;

        IF v_old_status NOT IN ('PENDING', 'IN_REVIEW', 'ESCALATED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level
        INTO   v_required_level, v_decider_level
        FROM   workflow_stages ws
        JOIN   employees e  ON e.emp_id  = p_decider_id
        JOIN   roles     r  ON r.role_id = e.role_id
        WHERE  ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        INSERT INTO decisions (
            request_id, stage_id, decider_id, decision, comments
        ) VALUES (
            p_request_id, v_current_stage, p_decider_id, p_decision, p_comments
        );

        IF p_decision = 'APPROVED' THEN
            v_next_stage := get_next_stage(v_workflow_id, v_current_stage);

            IF v_next_stage IS NULL THEN
                v_new_status := 'COMPLETED';
                UPDATE requests
                SET    status        = v_new_status,
                       current_stage = NULL,
                       resolved_at   = SYSTIMESTAMP
                WHERE  request_id    = p_request_id;
            ELSE
                SELECT stage_name
                INTO v_next_stage_name
                FROM workflow_stages
                WHERE stage_id = v_next_stage;

                IF v_next_stage_name = 'Implementation' THEN
                    v_new_status := 'APPROVED';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                ELSE
                    v_new_status := 'IN_REVIEW';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                END IF;
            END IF;

        ELSIF p_decision = 'REJECTED' THEN
            v_new_status := 'REJECTED';
            UPDATE requests
            SET    status        = v_new_status,
                   current_stage = NULL,
                   resolved_at   = SYSTIMESTAMP
            WHERE  request_id    = p_request_id;
        END IF;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => p_request_id,
            p_action     => 'UPDATE',
            p_changed_by => p_decider_id,
            p_old_value  => 'status=' || v_old_status,
            p_new_value  => 'status=' || v_new_status
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END decide_stage;

    ------------------------------------------------------------------ escalate_overdue requests
    PROCEDURE escalate_overdue AS
        CURSOR c_overdue IS
            SELECT r.request_id, r.submitted_at, w.sla_hours
            FROM   requests  r
            JOIN   workflows w ON w.workflow_id = r.workflow_id
            WHERE  r.status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'IN_PROGRESS')
            AND    r.submitted_at + (w.sla_hours / 24) < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            SELECT status
            INTO v_old_status
            FROM requests
            WHERE request_id = rec.request_id;

            UPDATE requests
            SET    status = 'ESCALATED'
            WHERE  request_id = rec.request_id;

            log_audit(
                p_table_name => 'REQUESTS',
                p_record_id  => rec.request_id,
                p_action     => 'UPDATE',
                p_changed_by => NULL,
                p_old_value  => v_old_status,
                p_new_value  => 'status=ESCALATED'
            );

            v_count := v_count + 1;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Escalated ' || v_count || ' overdue requests.');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END escalate_overdue;

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted  TIMESTAMP;
        v_sla_hours  NUMBER;
        v_hours_used NUMBER;
        v_pct        NUMBER;
    BEGIN
        SELECT r.submitted_at, w.sla_hours
        INTO   v_submitted, v_sla_hours
        FROM   requests  r
        JOIN   workflows w ON w.workflow_id = r.workflow_id
        WHERE  r.request_id = p_request_id;

        v_hours_used := (SYSTIMESTAMP - v_submitted) * 24;
        v_pct        := (v_hours_used / v_sla_hours) * 100;

        IF    v_pct < 70  THEN RETURN 'ON_TRACK';
        ELSIF v_pct < 100 THEN RETURN 'AT_RISK';
        ELSE                   RETURN 'BREACHED';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Request ' || p_request_id || ' not found.');
    END get_sla_status;

END workflow_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY workflow_pkg AS

    
    --------------------------------------------------------- get the first stage_id for a workflow
    FUNCTION get_first_stage (p_workflow_id IN NUMBER) RETURN NUMBER AS
        v_stage_id workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_id
        INTO   v_stage_id
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id = p_workflow_id
               );
        RETURN v_stage_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'No stages defined for workflow_id ' || p_workflow_id);
    END get_first_stage;

    
    ----------------------------- get the next stage_id after the current one for the specific workflow
    FUNCTION get_next_stage (
        p_workflow_id IN NUMBER,
        p_current_stage_id IN NUMBER
    ) RETURN NUMBER AS
        v_current_seq  workflow_stages.stage_seq%TYPE;
        v_next_stage   workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_seq INTO v_current_seq
        FROM   workflow_stages
        WHERE  stage_id = p_current_stage_id;

        SELECT stage_id INTO v_next_stage
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id  = p_workflow_id
                   AND    stage_seq    > v_current_seq
               );
        RETURN v_next_stage;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_next_stage;


    ------------------------------------------------------------------- submit_request
    FUNCTION submit_request (
        p_emp_id      IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes       IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER AS
        v_request_id  requests.request_id%TYPE;
        v_first_stage requests.current_stage%TYPE;
    BEGIN
        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   employees
            WHERE  emp_id = p_emp_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'Employee ' || p_emp_id || ' not found or inactive.');
        END;

        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   workflows
            WHERE  workflow_id = p_workflow_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'Workflow ' || p_workflow_id || ' not found or inactive.');
        END;

        v_first_stage := get_first_stage(p_workflow_id);

        INSERT INTO requests (
            workflow_id, submitted_by, current_stage, status, notes
        ) VALUES (
            p_workflow_id, p_emp_id, v_first_stage, 'PENDING', p_notes
        )
        RETURNING request_id INTO v_request_id;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => v_request_id,
            p_action     => 'INSERT',
            p_changed_by => p_emp_id,
            p_new_value  => 'status=PENDING, stage=' || v_first_stage
        );

        COMMIT;
        RETURN v_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END submit_request;

    ----------------------------------------------------------------------- decide_stage
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision   IN VARCHAR2,
        p_comments   IN VARCHAR2 DEFAULT NULL
    ) AS
        v_workflow_id    requests.workflow_id%TYPE;
        v_current_stage  requests.current_stage%TYPE;
        v_old_status     requests.status%TYPE;
        v_next_stage     workflow_stages.stage_id%TYPE;
        v_next_stage_name workflow_stages.stage_name%TYPE;
        v_new_status     requests.status%TYPE;
        v_required_level workflow_stages.required_level%TYPE;
        v_decider_level  roles.role_level%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO   v_workflow_id, v_current_stage, v_old_status
        FROM   requests
        WHERE  request_id = p_request_id
        FOR UPDATE NOWAIT;

        IF v_old_status NOT IN ('PENDING', 'IN_REVIEW', 'ESCALATED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level
        INTO   v_required_level, v_decider_level
        FROM   workflow_stages ws
        JOIN   employees e  ON e.emp_id  = p_decider_id
        JOIN   roles     r  ON r.role_id = e.role_id
        WHERE  ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        INSERT INTO decisions (
            request_id, stage_id, decider_id, decision, comments
        ) VALUES (
            p_request_id, v_current_stage, p_decider_id, p_decision, p_comments
        );

        IF p_decision = 'APPROVED' THEN
            v_next_stage := get_next_stage(v_workflow_id, v_current_stage);

            IF v_next_stage IS NULL THEN
                v_new_status := 'COMPLETED';
                UPDATE requests
                SET    status        = v_new_status,
                       current_stage = NULL,
                       resolved_at   = SYSTIMESTAMP
                WHERE  request_id    = p_request_id;
            ELSE
                SELECT stage_name
                INTO v_next_stage_name
                FROM workflow_stages
                WHERE stage_id = v_next_stage;

                IF v_next_stage_name = 'Implementation' THEN
                    v_new_status := 'APPROVED';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                ELSE
                    v_new_status := 'IN_REVIEW';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                END IF;
            END IF;

        ELSIF p_decision = 'REJECTED' THEN
            v_new_status := 'REJECTED';
            UPDATE requests
            SET    status        = v_new_status,
                   current_stage = NULL,
                   resolved_at   = SYSTIMESTAMP
            WHERE  request_id    = p_request_id;
        END IF;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => p_request_id,
            p_action     => 'UPDATE',
            p_changed_by => p_decider_id,
            p_old_value  => 'status=' || v_old_status,
            p_new_value  => 'status=' || v_new_status
        );

        COMMIT;

    EXCEPTION
        WHEN e_resource_busy THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Request ' || p_request_id || ' is currently being processed by another user.');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END decide_stage;

    ------------------------------------------------------------------ escalate_overdue requests
    PROCEDURE escalate_overdue AS
        CURSOR c_overdue IS
            SELECT r.request_id, r.submitted_at, w.sla_hours, r.status
            FROM   requests  r
            JOIN   workflows w ON w.workflow_id = r.workflow_id
            WHERE  r.status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'IN_PROGRESS')
            AND    r.submitted_at + (w.sla_hours / 24) < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            v_old_status := rec.status;

            UPDATE requests
            SET    status = 'ESCALATED'
            WHERE  request_id = rec.request_id;

            log_audit(
                p_table_name => 'REQUESTS',
                p_record_id  => rec.request_id,
                p_action     => 'UPDATE',
                p_changed_by => NULL,
                p_old_value  => v_old_status,
                p_new_value  => 'status=ESCALATED'
            );

            v_count := v_count + 1;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Escalated ' || v_count || ' overdue requests.');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END escalate_overdue;

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted  TIMESTAMP;
        v_sla_hours  NUMBER;
        v_hours_used NUMBER;
        v_pct        NUMBER;
    BEGIN
        SELECT r.submitted_at, w.sla_hours
        INTO   v_submitted, v_sla_hours
        FROM   requests  r
        JOIN   workflows w ON w.workflow_id = r.workflow_id
        WHERE  r.request_id = p_request_id;

        v_hours_used := (SYSTIMESTAMP - v_submitted) * 24;
        v_pct        := (v_hours_used / v_sla_hours) * 100;

        IF    v_pct < 70  THEN RETURN 'ON_TRACK';
        ELSIF v_pct < 100 THEN RETURN 'AT_RISK';
        ELSE                   RETURN 'BREACHED';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Request ' || p_request_id || ' not found.');
    END get_sla_status;

END workflow_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY workflow_pkg AS

    
    --------------------------------------------------------- get the first stage_id for a workflow
    FUNCTION get_first_stage (p_workflow_id IN NUMBER) RETURN NUMBER AS
        v_stage_id workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_id
        INTO   v_stage_id
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id = p_workflow_id
               );
        RETURN v_stage_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'No stages defined for workflow_id ' || p_workflow_id);
    END get_first_stage;

    
    ----------------------------- get the next stage_id after the current one for the specific workflow
    FUNCTION get_next_stage (
        p_workflow_id IN NUMBER,
        p_current_stage_id IN NUMBER
    ) RETURN NUMBER AS
        v_current_seq  workflow_stages.stage_seq%TYPE;
        v_next_stage   workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_seq INTO v_current_seq
        FROM   workflow_stages
        WHERE  stage_id = p_current_stage_id;

        SELECT stage_id INTO v_next_stage
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id  = p_workflow_id
                   AND    stage_seq    > v_current_seq
               );
        RETURN v_next_stage;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_next_stage;


    ------------------------------------------------------------------- submit_request
    FUNCTION submit_request (
        p_emp_id      IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes       IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER AS
        v_request_id  requests.request_id%TYPE;
        v_first_stage requests.current_stage%TYPE;
    BEGIN
        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   employees
            WHERE  emp_id = p_emp_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'Employee ' || p_emp_id || ' not found or inactive.');
        END;

        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   workflows
            WHERE  workflow_id = p_workflow_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'Workflow ' || p_workflow_id || ' not found or inactive.');
        END;

        v_first_stage := get_first_stage(p_workflow_id);

        INSERT INTO requests (
            workflow_id, submitted_by, current_stage, status, notes
        ) VALUES (
            p_workflow_id, p_emp_id, v_first_stage, 'PENDING', p_notes
        )
        RETURNING request_id INTO v_request_id;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => v_request_id,
            p_action     => 'INSERT',
            p_changed_by => p_emp_id,
            p_new_value  => 'status=PENDING, stage=' || v_first_stage
        );

        COMMIT;
        RETURN v_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END submit_request;

    ----------------------------------------------------------------------- decide_stage
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision   IN VARCHAR2,
        p_comments   IN VARCHAR2 DEFAULT NULL
    ) AS
        v_workflow_id    requests.workflow_id%TYPE;
        v_current_stage  requests.current_stage%TYPE;
        v_old_status     requests.status%TYPE;
        v_next_stage     workflow_stages.stage_id%TYPE;
        v_next_stage_name workflow_stages.stage_name%TYPE;
        v_new_status     requests.status%TYPE;
        v_required_level workflow_stages.required_level%TYPE;
        v_decider_level  roles.role_level%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO   v_workflow_id, v_current_stage, v_old_status
        FROM   requests
        WHERE  request_id = p_request_id
        FOR UPDATE;

        IF v_old_status NOT IN ('PENDING', 'IN_REVIEW', 'ESCALATED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level
        INTO   v_required_level, v_decider_level
        FROM   workflow_stages ws
        JOIN   employees e  ON e.emp_id  = p_decider_id
        JOIN   roles     r  ON r.role_id = e.role_id
        WHERE  ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        INSERT INTO decisions (
            request_id, stage_id, decider_id, decision, comments
        ) VALUES (
            p_request_id, v_current_stage, p_decider_id, p_decision, p_comments
        );

        IF p_decision = 'APPROVED' THEN
            v_next_stage := get_next_stage(v_workflow_id, v_current_stage);

            IF v_next_stage IS NULL THEN
                v_new_status := 'COMPLETED';
                UPDATE requests
                SET    status        = v_new_status,
                       current_stage = NULL,
                       resolved_at   = SYSTIMESTAMP
                WHERE  request_id    = p_request_id;
            ELSE
                SELECT stage_name
                INTO v_next_stage_name
                FROM workflow_stages
                WHERE stage_id = v_next_stage;

                IF v_next_stage_name = 'Implementation' THEN
                    v_new_status := 'APPROVED';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                ELSE
                    v_new_status := 'IN_REVIEW';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                END IF;
            END IF;

        ELSIF p_decision = 'REJECTED' THEN
            v_new_status := 'REJECTED';
            UPDATE requests
            SET    status        = v_new_status,
                   current_stage = NULL,
                   resolved_at   = SYSTIMESTAMP
            WHERE  request_id    = p_request_id;
        END IF;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => p_request_id,
            p_action     => 'UPDATE',
            p_changed_by => p_decider_id,
            p_old_value  => 'status=' || v_old_status,
            p_new_value  => 'status=' || v_new_status
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END decide_stage;

    ------------------------------------------------------------------ escalate_overdue requests
    PROCEDURE escalate_overdue AS
        CURSOR c_overdue IS
            SELECT r.request_id, r.submitted_at, w.sla_hours, r.status
            FROM   requests  r
            JOIN   workflows w ON w.workflow_id = r.workflow_id
            WHERE  r.status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'IN_PROGRESS')
            AND    r.submitted_at + (w.sla_hours / 24) < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            v_old_status := rec.status;

            UPDATE requests
            SET    status = 'ESCALATED'
            WHERE  request_id = rec.request_id;

            log_audit(
                p_table_name => 'REQUESTS',
                p_record_id  => rec.request_id,
                p_action     => 'UPDATE',
                p_changed_by => NULL,
                p_old_value  => v_old_status,
                p_new_value  => 'status=ESCALATED'
            );

            v_count := v_count + 1;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Escalated ' || v_count || ' overdue requests.');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END escalate_overdue;

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted  TIMESTAMP;
        v_sla_hours  NUMBER;
        v_hours_used NUMBER;
        v_pct        NUMBER;
    BEGIN
        SELECT r.submitted_at, w.sla_hours
        INTO   v_submitted, v_sla_hours
        FROM   requests  r
        JOIN   workflows w ON w.workflow_id = r.workflow_id
        WHERE  r.request_id = p_request_id;

        v_hours_used := (SYSTIMESTAMP - v_submitted) * 24;
        v_pct        := (v_hours_used / v_sla_hours) * 100;

        IF    v_pct < 70  THEN RETURN 'ON_TRACK';
        ELSIF v_pct < 100 THEN RETURN 'AT_RISK';
        ELSE                   RETURN 'BREACHED';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Request ' || p_request_id || ' not found.');
    END get_sla_status;

END workflow_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY workflow_pkg AS

    
    --------------------------------------------------------- get the first stage_id for a workflow
    FUNCTION get_first_stage (p_workflow_id IN NUMBER) RETURN NUMBER AS
        v_stage_id workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_id
        INTO   v_stage_id
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id = p_workflow_id
               );
        RETURN v_stage_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'No stages defined for workflow_id ' || p_workflow_id);
    END get_first_stage;

    
    ----------------------------- get the next stage_id after the current one for the specific workflow
    FUNCTION get_next_stage (
        p_workflow_id IN NUMBER,
        p_current_stage_id IN NUMBER
    ) RETURN NUMBER AS
        v_current_seq  workflow_stages.stage_seq%TYPE;
        v_next_stage   workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_seq INTO v_current_seq
        FROM   workflow_stages
        WHERE  stage_id = p_current_stage_id;

        SELECT stage_id INTO v_next_stage
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id  = p_workflow_id
                   AND    stage_seq    > v_current_seq
               );
        RETURN v_next_stage;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_next_stage;


    ------------------------------------------------------------------- submit_request
    FUNCTION submit_request (
        p_emp_id      IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes       IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER AS
        v_request_id  requests.request_id%TYPE;
        v_first_stage requests.current_stage%TYPE;
    BEGIN
        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   employees
            WHERE  emp_id = p_emp_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'Employee ' || p_emp_id || ' not found or inactive.');
        END;

        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   workflows
            WHERE  workflow_id = p_workflow_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'Workflow ' || p_workflow_id || ' not found or inactive.');
        END;

        v_first_stage := get_first_stage(p_workflow_id);

        INSERT INTO requests (
            workflow_id, submitted_by, current_stage, status, notes
        ) VALUES (
            p_workflow_id, p_emp_id, v_first_stage, 'PENDING', p_notes
        )
        RETURNING request_id INTO v_request_id;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => v_request_id,
            p_action     => 'INSERT',
            p_changed_by => p_emp_id,
            p_new_value  => 'status=PENDING, stage=' || v_first_stage
        );

        COMMIT;
        RETURN v_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END submit_request;

    ----------------------------------------------------------------------- decide_stage
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision   IN VARCHAR2,
        p_comments   IN VARCHAR2 DEFAULT NULL
    ) AS
        v_workflow_id    requests.workflow_id%TYPE;
        v_current_stage  requests.current_stage%TYPE;
        v_old_status     requests.status%TYPE;
        v_next_stage     workflow_stages.stage_id%TYPE;
        v_next_stage_name workflow_stages.stage_name%TYPE;
        v_new_status     requests.status%TYPE;
        v_required_level workflow_stages.required_level%TYPE;
        v_decider_level  roles.role_level%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO   v_workflow_id, v_current_stage, v_old_status
        FROM   requests
        WHERE  request_id = p_request_id
        FOR UPDATE;

        IF v_old_status NOT IN ('PENDING', 'IN_REVIEW', 'ESCALATED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level
        INTO   v_required_level, v_decider_level
        FROM   workflow_stages ws
        JOIN   employees e  ON e.emp_id  = p_decider_id
        JOIN   roles     r  ON r.role_id = e.role_id
        WHERE  ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        INSERT INTO decisions (
            request_id, stage_id, decider_id, decision, comments
        ) VALUES (
            p_request_id, v_current_stage, p_decider_id, p_decision, p_comments
        );

        IF p_decision = 'APPROVED' THEN
            v_next_stage := get_next_stage(v_workflow_id, v_current_stage);

            IF v_next_stage IS NULL THEN
                v_new_status := 'COMPLETED';
                UPDATE requests
                SET    status        = v_new_status,
                       current_stage = NULL,
                       resolved_at   = SYSTIMESTAMP
                WHERE  request_id    = p_request_id;
            ELSE
                SELECT stage_name
                INTO v_next_stage_name
                FROM workflow_stages
                WHERE stage_id = v_next_stage;

                IF v_next_stage_name = 'Implementation' THEN
                    v_new_status := 'APPROVED';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                ELSE
                    v_new_status := 'IN_REVIEW';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                END IF;
            END IF;

        ELSIF p_decision = 'REJECTED' THEN
            v_new_status := 'REJECTED';
            UPDATE requests
            SET    status        = v_new_status,
                   current_stage = NULL,
                   resolved_at   = SYSTIMESTAMP
            WHERE  request_id    = p_request_id;
        END IF;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => p_request_id,
            p_action     => 'UPDATE',
            p_changed_by => p_decider_id,
            p_old_value  => 'status=' || v_old_status,
            p_new_value  => 'status=' || v_new_status
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END decide_stage;

    ------------------------------------------------------------------ escalate_overdue requests
    PROCEDURE escalate_overdue AS
        CURSOR c_overdue IS
            SELECT r.request_id, r.submitted_at, w.sla_hours, r.status
            FROM   requests  r
            JOIN   workflows w ON w.workflow_id = r.workflow_id
            WHERE  r.status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'IN_PROGRESS')
            AND    r.submitted_at + (w.sla_hours / 24) < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            v_old_status := rec.status;

            UPDATE requests
            SET    status = 'ESCALATED'
            WHERE  request_id = rec.request_id;

            log_audit(
                p_table_name => 'REQUESTS',
                p_record_id  => rec.request_id,
                p_action     => 'UPDATE',
                p_changed_by => NULL,
                p_old_value  => v_old_status,
                p_new_value  => 'status=ESCALATED'
            );

            v_count := v_count + 1;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Escalated ' || v_count || ' overdue requests.');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END escalate_overdue;

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted  TIMESTAMP;
        v_sla_hours  NUMBER;
        v_hours_used NUMBER;
        v_pct        NUMBER;
    BEGIN
        SELECT r.submitted_at, w.sla_hours
        INTO   v_submitted, v_sla_hours
        FROM   requests  r
        JOIN   workflows w ON w.workflow_id = r.workflow_id
        WHERE  r.request_id = p_request_id;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;
        v_pct        := (v_hours_used / v_sla_hours) * 100;

        IF    v_pct < 70  THEN RETURN 'ON_TRACK';
        ELSIF v_pct < 100 THEN RETURN 'AT_RISK';
        ELSE                   RETURN 'BREACHED';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Request ' || p_request_id || ' not found.');
    END get_sla_status;

END workflow_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY workflow_pkg AS

    
    --------------------------------------------------------- get the first stage_id for a workflow
    FUNCTION get_first_stage (p_workflow_id IN NUMBER) RETURN NUMBER AS
        v_stage_id workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_id
        INTO   v_stage_id
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id = p_workflow_id
               );
        RETURN v_stage_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'No stages defined for workflow_id ' || p_workflow_id);
    END get_first_stage;

    
    ----------------------------- get the next stage_id after the current one for the specific workflow
    FUNCTION get_next_stage (
        p_workflow_id IN NUMBER,
        p_current_stage_id IN NUMBER
    ) RETURN NUMBER AS
        v_current_seq  workflow_stages.stage_seq%TYPE;
        v_next_stage   workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_seq INTO v_current_seq
        FROM   workflow_stages
        WHERE  stage_id = p_current_stage_id;

        SELECT stage_id INTO v_next_stage
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id  = p_workflow_id
                   AND    stage_seq    > v_current_seq
               );
        RETURN v_next_stage;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_next_stage;


    ------------------------------------------------------------------- submit_request
    FUNCTION submit_request (
        p_emp_id      IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes       IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER AS
        v_request_id  requests.request_id%TYPE;
        v_first_stage requests.current_stage%TYPE;
    BEGIN
        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   employees
            WHERE  emp_id = p_emp_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'Employee ' || p_emp_id || ' not found or inactive.');
        END;

        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   workflows
            WHERE  workflow_id = p_workflow_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'Workflow ' || p_workflow_id || ' not found or inactive.');
        END;

        v_first_stage := get_first_stage(p_workflow_id);

        INSERT INTO requests (
            workflow_id, submitted_by, current_stage, status, notes
        ) VALUES (
            p_workflow_id, p_emp_id, v_first_stage, 'PENDING', p_notes
        )
        RETURNING request_id INTO v_request_id;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => v_request_id,
            p_action     => 'INSERT',
            p_changed_by => p_emp_id,
            p_new_value  => 'status=PENDING, stage=' || v_first_stage
        );

        COMMIT;
        RETURN v_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END submit_request;

    ----------------------------------------------------------------------- decide_stage
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision   IN VARCHAR2,
        p_comments   IN VARCHAR2 DEFAULT NULL
    ) AS
        v_workflow_id    requests.workflow_id%TYPE;
        v_current_stage  requests.current_stage%TYPE;
        v_old_status     requests.status%TYPE;
        v_next_stage     workflow_stages.stage_id%TYPE;
        v_next_stage_name workflow_stages.stage_name%TYPE;
        v_new_status     requests.status%TYPE;
        v_required_level workflow_stages.required_level%TYPE;
        v_decider_level  roles.role_level%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO   v_workflow_id, v_current_stage, v_old_status
        FROM   requests
        WHERE  request_id = p_request_id
        FOR UPDATE;

        IF v_old_status NOT IN ('PENDING', 'IN_REVIEW', 'ESCALATED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level
        INTO   v_required_level, v_decider_level
        FROM   workflow_stages ws
        JOIN   employees e  ON e.emp_id  = p_decider_id
        JOIN   roles     r  ON r.role_id = e.role_id
        WHERE  ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        INSERT INTO decisions (
            request_id, stage_id, decider_id, decision, comments
        ) VALUES (
            p_request_id, v_current_stage, p_decider_id, p_decision, p_comments
        );

        IF p_decision = 'APPROVED' THEN
            v_next_stage := get_next_stage(v_workflow_id, v_current_stage);

            IF v_next_stage IS NULL THEN
                v_new_status := 'COMPLETED';
                UPDATE requests
                SET    status        = v_new_status,
                       current_stage = NULL,
                       resolved_at   = SYSTIMESTAMP
                WHERE  request_id    = p_request_id;
            ELSE
                SELECT stage_name
                INTO v_next_stage_name
                FROM workflow_stages
                WHERE stage_id = v_next_stage;

                IF v_next_stage_name = 'Implementation' THEN
                    v_new_status := 'APPROVED';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                ELSE
                    v_new_status := 'IN_REVIEW';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                END IF;
            END IF;

        ELSIF p_decision = 'REJECTED' THEN
            v_new_status := 'REJECTED';
            UPDATE requests
            SET    status        = v_new_status,
                   current_stage = NULL,
                   resolved_at   = SYSTIMESTAMP
            WHERE  request_id    = p_request_id;
        END IF;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => p_request_id,
            p_action     => 'UPDATE',
            p_changed_by => p_decider_id,
            p_old_value  => 'status=' || v_old_status,
            p_new_value  => 'status=' || v_new_status
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END decide_stage;

    ------------------------------------------------------------------ escalate_overdue requests
    PROCEDURE escalate_overdue AS
        CURSOR c_overdue IS
            SELECT r.request_id, r.submitted_at, w.sla_hours, r.status
            FROM   requests  r
            JOIN   workflows w ON w.workflow_id = r.workflow_id
            WHERE  r.status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'IN_PROGRESS')
            AND    r.submitted_at + (w.sla_hours / 24) < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            v_old_status := rec.status;

            UPDATE requests
            SET    status = 'ESCALATED'
            WHERE  request_id = rec.request_id;

            log_audit(
                p_table_name => 'REQUESTS',
                p_record_id  => rec.request_id,
                p_action     => 'UPDATE',
                p_changed_by => NULL,
                p_old_value  => v_old_status,
                p_new_value  => 'status=ESCALATED'
            );

            v_count := v_count + 1;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Escalated ' || v_count || ' overdue requests.');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END escalate_overdue;

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted  TIMESTAMP;
        v_sla_hours  NUMBER;
        v_hours_used NUMBER;
        v_pct        NUMBER;
    BEGIN
        SELECT r.submitted_at, w.sla_hours
        INTO   v_submitted, v_sla_hours
        FROM   requests  r
        JOIN   workflows w ON w.workflow_id = r.workflow_id
        WHERE  r.request_id = p_request_id;

        v_hours_used := EXTRACT(DAY    FROM (SYSTIMESTAMP - v_submitted)) * 24 
                        + EXTRACT(HOUR   FROM (SYSTIMESTAMP - v_submitted))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_submitted)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - v_submitted)) / 3600;
                        
        v_pct        := (v_hours_used / v_sla_hours) * 100;

        IF    v_pct < 70  THEN RETURN 'ON_TRACK';
        ELSIF v_pct < 100 THEN RETURN 'AT_RISK';
        ELSE                   RETURN 'BREACHED';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Request ' || p_request_id || ' not found.');
    END get_sla_status;

END workflow_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY workflow_pkg AS

    
    --------------------------------------------------------- get the first stage_id for a workflow
    FUNCTION get_first_stage (p_workflow_id IN NUMBER) RETURN NUMBER AS
        v_stage_id workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_id
        INTO   v_stage_id
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id = p_workflow_id
               );
        RETURN v_stage_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'No stages defined for workflow_id ' || p_workflow_id);
    END get_first_stage;

    
    ----------------------------- get the next stage_id after the current one for the specific workflow
    FUNCTION get_next_stage (
        p_workflow_id IN NUMBER,
        p_current_stage_id IN NUMBER
    ) RETURN NUMBER AS
        v_current_seq  workflow_stages.stage_seq%TYPE;
        v_next_stage   workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_seq INTO v_current_seq
        FROM   workflow_stages
        WHERE  stage_id = p_current_stage_id;

        SELECT stage_id INTO v_next_stage
        FROM   workflow_stages
        WHERE  workflow_id = p_workflow_id
        AND    stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id  = p_workflow_id
                   AND    stage_seq    > v_current_seq
               );
        RETURN v_next_stage;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_next_stage;


    ------------------------------------------------------------------- submit_request
    FUNCTION submit_request (
        p_emp_id      IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes       IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER AS
        v_request_id  requests.request_id%TYPE;
        v_first_stage requests.current_stage%TYPE;
    BEGIN
        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   employees
            WHERE  emp_id = p_emp_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'Employee ' || p_emp_id || ' not found or inactive.');
        END;

        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM   workflows
            WHERE  workflow_id = p_workflow_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'Workflow ' || p_workflow_id || ' not found or inactive.');
        END;

        v_first_stage := get_first_stage(p_workflow_id);

        INSERT INTO requests (
            workflow_id, submitted_by, current_stage, status, notes
        ) VALUES (
            p_workflow_id, p_emp_id, v_first_stage, 'PENDING', p_notes
        )
        RETURNING request_id INTO v_request_id;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => v_request_id,
            p_action     => 'INSERT',
            p_changed_by => p_emp_id,
            p_new_value  => 'status=PENDING, stage=' || v_first_stage
        );

        COMMIT;
        RETURN v_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END submit_request;

    ----------------------------------------------------------------------- decide_stage
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision   IN VARCHAR2,
        p_comments   IN VARCHAR2 DEFAULT NULL
    ) AS
        v_workflow_id    requests.workflow_id%TYPE;
        v_current_stage  requests.current_stage%TYPE;
        v_old_status     requests.status%TYPE;
        v_next_stage     workflow_stages.stage_id%TYPE;
        v_next_stage_name workflow_stages.stage_name%TYPE;
        v_new_status     requests.status%TYPE;
        v_required_level workflow_stages.required_level%TYPE;
        v_decider_level  roles.role_level%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO   v_workflow_id, v_current_stage, v_old_status
        FROM   requests
        WHERE  request_id = p_request_id
        FOR UPDATE;

        IF v_old_status NOT IN ('PENDING', 'IN_REVIEW', 'ESCALATED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level
        INTO   v_required_level, v_decider_level
        FROM   workflow_stages ws
        JOIN   employees e  ON e.emp_id  = p_decider_id
        JOIN   roles     r  ON r.role_id = e.role_id
        WHERE  ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        INSERT INTO decisions (
            request_id, stage_id, decider_id, decision, comments
        ) VALUES (
            p_request_id, v_current_stage, p_decider_id, p_decision, p_comments
        );

        IF p_decision = 'APPROVED' THEN
            v_next_stage := get_next_stage(v_workflow_id, v_current_stage);

            IF v_next_stage IS NULL THEN
                v_new_status := 'COMPLETED';
                UPDATE requests
                SET    status        = v_new_status,
                       current_stage = NULL,
                       resolved_at   = SYSTIMESTAMP
                WHERE  request_id    = p_request_id;
            ELSE
                SELECT stage_name
                INTO v_next_stage_name
                FROM workflow_stages
                WHERE stage_id = v_next_stage;

                IF v_next_stage_name = 'Implementation' THEN
                    v_new_status := 'APPROVED';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                ELSE
                    v_new_status := 'IN_REVIEW';
                    UPDATE requests
                    SET    status        = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id    = p_request_id;
                END IF;
            END IF;

        ELSIF p_decision = 'REJECTED' THEN
            v_new_status := 'REJECTED';
            UPDATE requests
            SET    status        = v_new_status,
                   current_stage = NULL,
                   resolved_at   = SYSTIMESTAMP
            WHERE  request_id    = p_request_id;
        END IF;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id  => p_request_id,
            p_action     => 'UPDATE',
            p_changed_by => p_decider_id,
            p_old_value  => 'status=' || v_old_status,
            p_new_value  => 'status=' || v_new_status
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END decide_stage;

    ------------------------------------------------------------------ escalate_overdue requests
    PROCEDURE escalate_overdue AS
        CURSOR c_overdue IS
            SELECT r.request_id, r.submitted_at, w.sla_hours, r.status
            FROM   requests  r
            JOIN   workflows w ON w.workflow_id = r.workflow_id
            WHERE  r.status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'IN_PROGRESS')
            AND    r.submitted_at + (w.sla_hours / 24) < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            v_old_status := rec.status;

            UPDATE requests
            SET    status = 'ESCALATED'
            WHERE  request_id = rec.request_id;

            log_audit(
                p_table_name => 'REQUESTS',
                p_record_id  => rec.request_id,
                p_action     => 'UPDATE',
                p_changed_by => NULL,
                p_old_value  => v_old_status,
                p_new_value  => 'status=ESCALATED'
            );

            v_count := v_count + 1;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Escalated ' || v_count || ' overdue requests.');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END escalate_overdue;

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted  TIMESTAMP;
        v_sla_hours  NUMBER;
        v_hours_used NUMBER;
        v_pct        NUMBER;
    BEGIN
        SELECT r.submitted_at, w.sla_hours
        INTO   v_submitted, v_sla_hours
        FROM   requests  r
        JOIN   workflows w ON w.workflow_id = r.workflow_id
        WHERE  r.request_id = p_request_id;

        v_hours_used := EXTRACT(DAY    FROM (SYSTIMESTAMP - v_submitted)) * 24 
                        + EXTRACT(HOUR   FROM (SYSTIMESTAMP - v_submitted))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_submitted)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - v_submitted)) / 3600;

        v_pct := (v_hours_used / v_sla_hours) * 100;

        IF    v_pct < 70  THEN RETURN 'ON_TRACK';
        ELSIF v_pct < 100 THEN RETURN 'AT_RISK';
        ELSE                   RETURN 'BREACHED';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Request ' || p_request_id || ' not found.');
    END get_sla_status;

END workflow_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY workflow_pkg AS

    
    --------------------------------------------------------- get the first stage_id for a workflow
    FUNCTION get_first_stage (p_workflow_id IN NUMBER) RETURN NUMBER AS
        v_stage_id workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_id
        INTO v_stage_id
        FROM workflow_stages
        WHERE workflow_id = p_workflow_id
        AND stage_seq   = (
                   SELECT MIN(stage_seq)
                   FROM   workflow_stages
                   WHERE  workflow_id = p_workflow_id
               );
        RETURN v_stage_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'No stages defined for workflow_id ' || p_workflow_id);
    END get_first_stage;

    
    ----------------------------- get the next stage_id after the current one for the specific workflow
    FUNCTION get_next_stage (
        p_workflow_id IN NUMBER,
        p_current_stage_id IN NUMBER
    ) RETURN NUMBER AS
        v_current_seq workflow_stages.stage_seq%TYPE;
        v_next_stage workflow_stages.stage_id%TYPE;
    BEGIN
        SELECT stage_seq INTO v_current_seq
        FROM workflow_stages
        WHERE stage_id = p_current_stage_id;

        SELECT stage_id INTO v_next_stage
        FROM workflow_stages
        WHERE workflow_id = p_workflow_id
        AND stage_seq = (
                   SELECT MIN(stage_seq)
                   FROM workflow_stages
                   WHERE workflow_id  = p_workflow_id
                   AND stage_seq    > v_current_seq
               );
        RETURN v_next_stage;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_next_stage;


    ------------------------------------------------------------------- submit_request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER AS
        v_request_id  requests.request_id%TYPE;
        v_first_stage requests.current_stage%TYPE;
    BEGIN
        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM employees
            WHERE emp_id = p_emp_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'Employee ' || p_emp_id || ' not found or inactive.');
        END;

        DECLARE
            v_check NUMBER;
        BEGIN
            SELECT 1 INTO v_check
            FROM workflows
            WHERE workflow_id = p_workflow_id AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'Workflow ' || p_workflow_id || ' not found or inactive.');
        END;

        v_first_stage := get_first_stage(p_workflow_id);

        INSERT INTO requests (
            workflow_id, submitted_by, current_stage, status, notes
        ) VALUES (
            p_workflow_id, p_emp_id, v_first_stage, 'PENDING', p_notes
        )
        RETURNING request_id INTO v_request_id;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id => v_request_id,
            p_action => 'INSERT',
            p_changed_by => p_emp_id,
            p_new_value => 'status=PENDING, stage=' || v_first_stage
        );

        COMMIT;
        RETURN v_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END submit_request;

    ----------------------------------------------------------------------- decide_stage
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    ) AS
        v_workflow_id requests.workflow_id%TYPE;
        v_current_stage requests.current_stage%TYPE;
        v_old_status requests.status%TYPE;
        v_next_stage workflow_stages.stage_id%TYPE;
        v_next_stage_name workflow_stages.stage_name%TYPE;
        v_new_status requests.status%TYPE;
        v_required_level workflow_stages.required_level%TYPE;
        v_decider_level roles.role_level%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status NOT IN ('PENDING', 'IN_REVIEW', 'ESCALATED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level
        INTO v_required_level, v_decider_level
        FROM workflow_stages ws
        JOIN employees e  ON e.emp_id  = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        INSERT INTO decisions (
            request_id, stage_id, decider_id, decision, comments
        ) VALUES (
            p_request_id, v_current_stage, p_decider_id, p_decision, p_comments
        );

        IF p_decision = 'APPROVED' THEN
            v_next_stage := get_next_stage(v_workflow_id, v_current_stage);

            IF v_next_stage IS NULL THEN
                v_new_status := 'COMPLETED';
                UPDATE requests
                SET    status = v_new_status,
                       current_stage = NULL,
                       resolved_at = SYSTIMESTAMP
                WHERE  request_id = p_request_id;
            ELSE
                SELECT stage_name
                INTO v_next_stage_name
                FROM workflow_stages
                WHERE stage_id = v_next_stage;

                IF v_next_stage_name = 'Implementation' THEN
                    v_new_status := 'APPROVED';
                    UPDATE requests
                    SET status = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id = p_request_id;
                ELSE
                    v_new_status := 'IN_REVIEW';
                    UPDATE requests
                    SET status = v_new_status,
                        current_stage = v_next_stage
                    WHERE  request_id = p_request_id;
                END IF;
            END IF;

        ELSIF p_decision = 'REJECTED' THEN
            v_new_status := 'REJECTED';
            UPDATE requests
            SET status = v_new_status, 
                current_stage = NULL, 
                resolved_at = SYSTIMESTAMP
            WHERE request_id = p_request_id;
        END IF;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id => p_request_id,
            p_action => 'UPDATE',
            p_changed_by => p_decider_id,
            p_old_value => 'status=' || v_old_status,
            p_new_value => 'status=' || v_new_status
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END decide_stage;

    ------------------------------------------------------------------ escalate_overdue requests
    PROCEDURE escalate_overdue AS
        CURSOR c_overdue IS
            SELECT r.request_id, r.submitted_at, w.sla_hours, r.status
            FROM requests  r
            JOIN workflows w ON w.workflow_id = r.workflow_id
            WHERE r.status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'IN_PROGRESS')
            AND r.submitted_at + (w.sla_hours / 24) < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            v_old_status := rec.status;

            UPDATE requests
            SET status = 'ESCALATED'
            WHERE request_id = rec.request_id;

            log_audit(
                p_table_name => 'REQUESTS',
                p_record_id => rec.request_id,
                p_action => 'UPDATE',
                p_changed_by => NULL,
                p_old_value => v_old_status,
                p_new_value => 'status=ESCALATED'
            );

            v_count := v_count + 1;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Escalated ' || v_count || ' overdue requests.');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END escalate_overdue;

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted TIMESTAMP;
        v_sla_hours NUMBER;
        v_hours_used NUMBER;
        v_pct NUMBER;
    BEGIN
        SELECT r.submitted_at, w.sla_hours
        INTO v_submitted, v_sla_hours
        FROM requests  r
        JOIN workflows w ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        v_hours_used := EXTRACT(DAY    FROM (SYSTIMESTAMP - v_submitted)) * 24 
                        + EXTRACT(HOUR   FROM (SYSTIMESTAMP - v_submitted))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_submitted)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - v_submitted)) / 3600;

        v_pct := (v_hours_used / v_sla_hours) * 100;

        IF v_pct < 70 THEN 
            RETURN 'ON_TRACK';
        ELSIF v_pct < 100 THEN 
            RETURN 'AT_RISK';
        ELSE                   
            RETURN 'BREACHED';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Request ' || p_request_id || ' not found.');
    END get_sla_status;

END workflow_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE incident_pkg AS

    FUNCTION log_incident (
        p_dept_id IN NUMBER,
        p_reported_by IN NUMBER,
        p_title IN VARCHAR2,
        p_severity IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution IN VARCHAR2
    );

    ------------------------- Automatically assign incident to employee with the least amount of work
    PROCEDURE auto_assign (p_incident_id IN NUMBER);

END incident_pkg;
/

CREATE OR REPLACE PACKAGE BODY incident_pkg AS

    FUNCTION log_incident (
        p_dept_id     IN NUMBER,
        p_reported_by IN NUMBER,
        p_title       IN VARCHAR2,
        p_severity    IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER AS
        v_incident_id incidents.incident_id%TYPE;
    BEGIN
        INSERT INTO incidents (
            dept_id, reported_by, title, severity, description, status
        ) VALUES (
            p_dept_id, p_reported_by, p_title, p_severity, p_description, 'OPEN'
        )
        RETURNING incident_id INTO v_incident_id;

        log_audit('INCIDENTS', v_incident_id, 'INSERT', p_reported_by,
                  NULL, 'severity=' || p_severity || ', status=OPEN');

        auto_assign(v_incident_id);

        COMMIT;
        RETURN v_incident_id;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END log_incident;

    PROCEDURE auto_assign (p_incident_id IN NUMBER) AS
        v_dept_id incidents.dept_id%TYPE;
        v_assignee employees.emp_id%TYPE;
    BEGIN
        SELECT dept_id 
        INTO v_dept_id
        FROM incidents 
        WHERE incident_id = p_incident_id;

        SELECT emp_id 
        INTO v_assignee
        FROM (
            SELECT e.emp_id,
                   COUNT(t.task_id) AS open_tasks
            FROM employees e
            LEFT JOIN tasks t ON t.assigned_to = e.emp_id
            AND t.status IN ('OPEN','IN_PROGRESS')
            WHERE e.dept_id = v_dept_id
            AND e.is_active = 1
            GROUP BY e.emp_id
            ORDER BY open_tasks ASC
        )
        WHERE ROWNUM = 1;

        UPDATE incidents
        SET assigned_to = v_assignee,
            status = 'IN_PROGRESS'
        WHERE incident_id = p_incident_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END auto_assign;

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution  IN VARCHAR2
    ) AS
        v_reported_at incidents.reported_at%TYPE;
        v_old_status incidents.status%TYPE;
        v_minutes NUMBER;
    BEGIN
        SELECT reported_at, status
        INTO v_reported_at, v_old_status
        FROM incidents
        WHERE incident_id = p_incident_id
        FOR UPDATE;

        IF v_old_status = 'RESOLVED' THEN
            RAISE_APPLICATION_ERROR(-20010,
                'Incident ' || p_incident_id || ' is already resolved.');
        END IF;

        v_minutes := ROUND((SYSTIMESTAMP - v_reported_at) * 24 * 60);

        UPDATE incidents
        SET status = 'RESOLVED',
            resolved_at = SYSTIMESTAMP,
            resolution_min = v_minutes,
            description = description || CHR(10) || 'RESOLUTION: ' || p_resolution
        WHERE incident_id = p_incident_id;

        log_audit('INCIDENTS', p_incident_id, 'UPDATE', p_resolved_by,
                  'status=' || v_old_status,
                  'status=RESOLVED, resolution_min=' || v_minutes);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END resolve_incident;

END incident_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE incident_pkg AS

    FUNCTION log_incident (
        p_dept_id IN NUMBER,
        p_reported_by IN NUMBER,
        p_title IN VARCHAR2,
        p_severity IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution IN VARCHAR2
    );

    ------------------------- Automatically assign incident to employee with the least amount of work
    PROCEDURE auto_assign (p_incident_id IN NUMBER);

END incident_pkg;
/

CREATE OR REPLACE PACKAGE BODY incident_pkg AS

    FUNCTION log_incident (
        p_dept_id     IN NUMBER,
        p_reported_by IN NUMBER,
        p_title       IN VARCHAR2,
        p_severity    IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER AS
        v_incident_id incidents.incident_id%TYPE;
    BEGIN
        INSERT INTO incidents (
            dept_id, reported_by, title, severity, description, status
        ) VALUES (
            p_dept_id, p_reported_by, p_title, p_severity, p_description, 'OPEN'
        )
        RETURNING incident_id INTO v_incident_id;

        log_audit('INCIDENTS', v_incident_id, 'INSERT', p_reported_by,
                  NULL, 'severity=' || p_severity || ', status=OPEN');

        auto_assign(v_incident_id);

        COMMIT;
        RETURN v_incident_id;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END log_incident;

    PROCEDURE auto_assign (p_incident_id IN NUMBER) AS
        v_dept_id incidents.dept_id%TYPE;
        v_assignee employees.emp_id%TYPE;
    BEGIN
        SELECT dept_id 
        INTO v_dept_id
        FROM incidents 
        WHERE incident_id = p_incident_id;

        SELECT emp_id 
        INTO v_assignee
        FROM (
            SELECT e.emp_id,
                   COUNT(t.task_id) AS open_tasks
            FROM employees e
            LEFT JOIN tasks t ON t.assigned_to = e.emp_id
            AND t.status IN ('OPEN','IN_PROGRESS')
            WHERE e.dept_id = v_dept_id
            AND e.is_active = 1
            GROUP BY e.emp_id
            ORDER BY open_tasks ASC
        )
        WHERE ROWNUM = 1;

        UPDATE incidents
        SET assigned_to = v_assignee,
            status = 'IN_PROGRESS'
        WHERE incident_id = p_incident_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END auto_assign;

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution  IN VARCHAR2
    ) AS
        v_reported_at incidents.reported_at%TYPE;
        v_old_status incidents.status%TYPE;
        v_minutes NUMBER;
    BEGIN
        SELECT reported_at, status
        INTO v_reported_at, v_old_status
        FROM incidents
        WHERE incident_id = p_incident_id
        FOR UPDATE;

        IF v_old_status = 'RESOLVED' THEN
            RAISE_APPLICATION_ERROR(-20010,
                'Incident ' || p_incident_id || ' is already resolved.');
        END IF;

        v_minutes := ROUND( EXTRACT(DAY FROM (SYSTIMESTAMP - v_reported_at)) * 1440
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - v_reported_at)) * 60
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_reported_at))
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - v_reported_at)) / 60
                    );

        UPDATE incidents
        SET status = 'RESOLVED',
            resolved_at = SYSTIMESTAMP,
            resolution_min = v_minutes,
            description = description || CHR(10) || 'RESOLUTION: ' || p_resolution
        WHERE incident_id = p_incident_id;

        log_audit('INCIDENTS', p_incident_id, 'UPDATE', p_resolved_by,
                  'status=' || v_old_status,
                  'status=RESOLVED, resolution_min=' || v_minutes);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END resolve_incident;

END incident_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE reporting_pkg AS
    PROCEDURE take_kpi_snapshot;

    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR;

    FUNCTION employee_workload_report RETURN SYS_REFCURSOR;

    FUNCTION incident_trend_report RETURN SYS_REFCURSOR;

END reporting_pkg;
/

CREATE OR REPLACE PACKAGE BODY reporting_pkg AS
    PROCEDURE take_kpi_snapshot AS
        CURSOR c_depts IS 
            SELECT dept_id 
            FROM departments;
            
        v_open_inc NUMBER;
        v_resolved NUMBER;
        v_avg_res_h NUMBER;
        v_open_req NUMBER;
        v_breaches NUMBER;
        v_budget_pct NUMBER;
    BEGIN
        FOR dept IN c_depts LOOP
            SELECT COUNT(*) 
            INTO v_open_inc
            FROM incidents
            WHERE dept_id = dept.dept_id
            AND status IN ('OPEN','IN_PROGRESS');

            SELECT COUNT(*) 
            INTO v_resolved
            FROM incidents
            WHERE dept_id = dept.dept_id
            AND status = 'RESOLVED'
            AND TRUNC(resolved_at) = TRUNC(SYSDATE);

            SELECT ROUND(AVG(resolution_min) / 60, 2)
            INTO v_avg_res_h
            FROM incidents
            WHERE dept_id = dept.dept_id
            AND resolution_min IS NOT NULL;

            SELECT COUNT(*) 
            INTO v_open_req
            FROM requests r
            JOIN employees e ON e.emp_id = r.submitted_by
            WHERE e.dept_id  = dept.dept_id
            AND r.status NOT IN ('COMPLETED','CANCELLED','REJECTED');

            SELECT COUNT(*) 
            INTO v_breaches
            FROM requests r
            JOIN workflows w ON w.workflow_id = r.workflow_id
            JOIN employees e ON e.emp_id = r.submitted_by
            WHERE e.dept_id = dept.dept_id
            AND r.status  = 'ESCALATED'
            AND TRUNC(r.submitted_at, 'MM') = TRUNC(SYSDATE, 'MM');

            SELECT ROUND((spent / NULLIF(allocated,0)) * 100, 2)
            INTO v_budget_pct
            FROM budgets
            WHERE dept_id = dept.dept_id
            AND fiscal_year = TO_NUMBER(TO_CHAR(SYSDATE,'YYYY'));

            -- Upsert — update today's snapshot if it exists, else insert
            MERGE INTO kpi_logs k
            USING (SELECT dept.dept_id AS dept_id, TRUNC(SYSDATE) AS snap_date
                   FROM dual) src
            ON (k.dept_id = src.dept_id AND k.snapshot_date = src.snap_date)
            WHEN MATCHED THEN UPDATE SET
                open_incidents  = v_open_inc,
                resolved_today  = v_resolved,
                avg_resolution_h = v_avg_res_h,
                open_requests   = v_open_req,
                sla_breaches    = v_breaches,
                budget_pct_used = v_budget_pct
            WHEN NOT MATCHED THEN INSERT (
                dept_id, snapshot_date, open_incidents, resolved_today,
                avg_resolution_h, open_requests, sla_breaches, budget_pct_used
            ) VALUES (
                dept.dept_id, TRUNC(SYSDATE), v_open_inc, v_resolved,
                v_avg_res_h, v_open_req, v_breaches, v_budget_pct
            );

        END LOOP;
        COMMIT;
    END take_kpi_snapshot;

    ------------------------------------------------------------------ rank departments by efficiency
    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                COUNT(DISTINCT i.incident_id) AS total_incidents,
                ROUND(AVG(i.resolution_min) / 60, 2) AS avg_resolution_h,
                COUNT(CASE WHEN i.status IN ('OPEN','IN_PROGRESS') THEN 1 END) AS open_incidents,
                
                RANK() OVER (
                    ORDER BY AVG(i.resolution_min) ASC NULLS LAST
                ) AS efficiency_rank,

                ROUND(
                    AVG(i.resolution_min) - AVG(AVG(i.resolution_min))
                        OVER (), 2
                ) AS vs_company_avg_min
            FROM departments d
            LEFT JOIN incidents i ON i.dept_id = d.dept_id
            GROUP BY d.dept_id, d.dept_name
            ORDER BY efficiency_rank;

        RETURN v_cur;
    END dept_efficiency_report;

    ------------------------------------------------------------------- employee workload within dept
    FUNCTION employee_workload_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                e.first_name || ' ' || e.last_name   AS employee_name,
                COUNT(t.task_id) AS active_tasks,
                
                DENSE_RANK() OVER (
                    PARTITION BY e.dept_id
                    ORDER BY COUNT(t.task_id) DESC
                ) AS dept_workload_rank,
                
                ROUND(
                    COUNT(t.task_id) * 100.0 /
                    NULLIF(SUM(COUNT(t.task_id)) OVER (PARTITION BY e.dept_id), 0),
                2) AS pct_of_dept_load
            FROM employees e
            JOIN departments d ON d.dept_id = e.dept_id
            LEFT JOIN tasks  t ON t.assigned_to = e.emp_id
            AND t.status IN ('OPEN','IN_PROGRESS')
            WHERE e.is_active = 1
            GROUP BY e.emp_id, e.first_name, e.last_name, e.dept_id, d.dept_name
            ORDER BY d.dept_name, dept_workload_rank;

        RETURN v_cur;
    END employee_workload_report;

    -------------------------------------- Incident trend: weekly counts for last 8 weeks by severity
    FUNCTION incident_trend_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                TRUNC(reported_at, 'IW') AS week_start,
                severity,
                COUNT(*) AS incident_count,
                
                SUM(COUNT(*)) OVER (
                    PARTITION BY severity
                    ORDER BY TRUNC(reported_at, 'IW')
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ) AS running_total
            FROM incidents
            WHERE reported_at >= SYSDATE - 56
            GROUP BY TRUNC(reported_at, 'IW'), severity
            ORDER BY week_start, severity;

        RETURN v_cur;
    END incident_trend_report;

END reporting_pkg;
/
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_incident_resolve
BEFORE UPDATE ON incidents
FOR EACH ROW
WHEN (NEW.status = 'RESOLVED' AND OLD.status != 'RESOLVED')
BEGIN
    :NEW.resolved_at := SYSTIMESTAMP;
    :NEW.resolution_min := ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(:OLD.reported_at AS DATE)) * 24 * 60);
END;
/

CREATE OR REPLACE TRIGGER trg_audit_immutable
BEFORE UPDATE OR DELETE ON audit_logs
BEGIN
    RAISE_APPLICATION_ERROR(-20020,
        'audit_logs is immutable. Updates and deletes are not permitted.');
END;
/

CREATE OR REPLACE TRIGGER trg_request_resolve
BEFORE UPDATE ON requests
FOR EACH ROW
WHEN (NEW.status IN ('COMPLETED','REJECTED', 'CANCELLED') AND OLD.resolved_at IS NULL)
BEGIN
    :NEW.resolved_at := SYSTIMESTAMP;
END;
/
----------------------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE workflow_stages
----------------------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE workflows;
----------------------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE roles;
----------------------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE departments;
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE workflows
DROP CONSTRAINT fk_workflow_dept;
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE workflows
DROP COLUMN dept_id;
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE workflow_stages
ADD dept_id NUMBER;
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE workflow_stages
ADD CONSTRAINT fk_wfstags_dept
FOREIGN KEY (dept_id)
REFERENCES departments(dept_id);
----------------------------------------------------------------------------------------------------------------------------------
-- Roles (insert these first, lowest level to highest)
INSERT INTO roles (role_name, role_level) VALUES ('Employee',   1);
INSERT INTO roles (role_name, role_level) VALUES ('Supervisor', 2);
INSERT INTO roles (role_name, role_level) VALUES ('Ops Manager',3);
INSERT INTO roles (role_name, role_level) VALUES ('Executive',  4);
INSERT INTO roles (role_name, role_level) VALUES ('System Admin', 5);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
-- Departments (manager_id left null for now, update after employees inserted)
INSERT INTO departments (dept_name) VALUES ('Human Resources');
INSERT INTO departments (dept_name) VALUES ('Information Technology');
INSERT INTO departments (dept_name) VALUES ('Accounts');
INSERT INTO departments (dept_name) VALUES ('Procurement');
INSERT INTO departments (dept_name) VALUES ('Internal Audit');

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
