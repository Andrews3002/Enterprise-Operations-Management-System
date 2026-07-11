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
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('John', 'Smith', 'john.smith@company.com', 21, 21);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Sarah', 'Williams', 'sarah.williams@company.com', 21, 21);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Michael', 'Brown', 'michael.brown@company.com', 21, 22);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Jennifer', 'Davis', 'jennifer.davis@company.com', 21, 23);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Robert', 'Miller', 'robert.miller@company.com', 21, 24);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('David', 'Taylor', 'david.taylor@company.com', 22, 21);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Emma', 'Anderson', 'emma.anderson@company.com', 22, 21);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('James', 'Thomas', 'james.thomas@company.com', 22, 22);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Olivia', 'Jackson', 'olivia.jackson@company.com', 22, 23);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('William', 'White', 'william.white@company.com', 22, 24);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Sophia', 'Harris', 'sophia.harris@company.com', 22, 25);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Benjamin', 'Martin', 'benjamin.martin@company.com', 23, 21);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Mia', 'Thompson', 'mia.thompson@company.com', 23, 21);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Lucas', 'Garcia', 'lucas.garcia@company.com', 23, 22);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Charlotte', 'Martinez', 'charlotte.martinez@company.com', 23, 23);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Henry', 'Robinson', 'henry.robinson@company.com', 23, 24);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Joseph', 'Young', 'joseph.young@company.com', 25, 21);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Ella', 'King', 'ella.king@company.com', 25, 21);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Samuel', 'Wright', 'samuel.wright@company.com', 25, 22);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Grace', 'Scott', 'grace.scott@company.com', 25, 23);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Andrew', 'Green', 'andrew.green@company.com', 25, 24);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Leave Request', 48);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Equipment Request', 72);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Overtime Request', 24);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Incident Report', 12);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (21, 'Supervisor Review', 1, 21, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (21, 'HR Approval', 2, 21, 2);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (22, 'Supervisor Review', 1, 24, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (22, 'Procuement Approval', 2, 24, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (22, 'Finance Sign-off', 3, 23, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (22, 'Implementation', 4, 24, 2);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (23, 'Supervisor Review', 1, 21, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (23, 'HR Approval', 2, 21, 2);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (24, 'Supervisor Review', 1, 25, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (24, 'Internal Audit Approval', 2, 25, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (24, 'Implementation', 3, 25, 2);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Alexander', 'Rodriguez', 'alexander.rodriguez@company.com', 24, 21);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Harper', 'Lewis', 'harper.lewis@company.com', 24, 21);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Daniel', 'Lee', 'daniel.lee@company.com', 24, 22);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Evelyn', 'Walker', 'evelyn.walker@company.com', 24, 23);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Matthew', 'Hall', 'matthew.hall@company.com', 24, 24);

COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
SET SERVEROUTPUT ON;

DECLARE
    v_id NUMBER;
BEGIN
    v_id := workflow_pkg.submit_request(
        p_emp_id      => 22,
        p_workflow_id => 21,
        p_notes       => 'Annual leave, 5 days from July 1'
    );
    DBMS_OUTPUT.PUT_LINE('Created request_id: ' || v_id);
END;
/
----------------------------------------------------------------------------------------------------------------------------------
SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE(
        workflow_pkg.get_sla_status(1)
    );
END;
/
----------------------------------------------------------------------------------------------------------------------------------
create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id department.dept_id%TYPE;
        v_decider_dept_id department.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level. ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
----------------------------------------------------------------------------------------------------------------------------------
create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level. ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
----------------------------------------------------------------------------------------------------------------------------------
create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
----------------------------------------------------------------------------------------------------------------------------------
BEGIN
    workflow_pkg.decide_stage(
        p_request_id => 1,
        p_decider_id => 1,
        p_decision   => 'APPROVED',
        p_comments   => 'Approved, coverage arranged.'
    );
END;
/
----------------------------------------------------------------------------------------------------------------------------------
BEGIN
    workflow_pkg.decide_stage(
        p_request_id => 1,
        p_decider_id => 6,
        p_decision   => 'APPROVED',
        p_comments   => 'Approved, coverage arranged.'
    );
END;
/
----------------------------------------------------------------------------------------------------------------------------------
BEGIN
    workflow_pkg.decide_stage(
        p_request_id => 1,
        p_decider_id => 8,
        p_decision   => 'APPROVED',
        p_comments   => 'Approved, coverage arranged.'
    );
END;
/
----------------------------------------------------------------------------------------------------------------------------------
BEGIN
    workflow_pkg.decide_stage(
        p_request_id => 1,
        p_decider_id => 3,
        p_decision   => 'APPROVED',
        p_comments   => 'Approved, coverage arranged.'
    );
END;
/
----------------------------------------------------------------------------------------------------------------------------------
DECLARE
    v_id NUMBER;
BEGIN
    v_id := incident_pkg.log_incident(
        p_dept_id => 22,
        p_reported_by => 13,
        p_title => 'Email server unresponsive',
        p_severity => 'HIGH'
    );
    DBMS_OUTPUT.PUT_LINE('Created incident_id: ' || v_id);
END;
/
----------------------------------------------------------------------------------------------------------------------------------
create or replace PACKAGE BODY incident_pkg AS

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
        v_ops_manager_id NUMBER := 23;
    BEGIN
        SELECT dept_id 
        INTO v_dept_id
        FROM incidents 
        WHERE incident_id = p_incident_id;

        SELECT e.emp_id 
        INTO v_assignee
        FROM employees e
        WHERE e.dept_id = v_dept_id
        AND e.role_id = v_ops_manager_id
        AND e.is_active = 1;

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
----------------------------------------------------------------------------------------------------------------------------------
BEGIN
    reporting_pkg.take_kpi_snapshot;
END;
/
SELECT * FROM kpi_logs;
----------------------------------------------------------------------------------------------------------------------------------
-- since we havent seeded budget yet
create or replace PACKAGE BODY reporting_pkg AS
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
----------------------------------------------------------------------------------------------------------------------------------
BEGIN
    reporting_pkg.take_kpi_snapshot;
END;
/
SELECT * FROM kpi_logs;
----------------------------------------------------------------------------------------------------------------------------------
BEGIN
    workflow_pkg.escalate_overdue;
END;
/
----------------------------------------------------------------------------------------------------------------------------------
SELECT table_name, action, old_value, new_value, changed_at
FROM audit_logs
ORDER BY changed_at;
----------------------------------------------------------------------------------------------------------------------------------
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (21, 2026, 600000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (22, 2026, 3000000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (23, 2026, 1500000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (24, 2026, 400000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (25, 2026, 200000);
COMMIT;
----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE department_spend(
    p_dept_id NUMBER,
    p_amount_spent NUMBER
)
AS
BEGIN
    UPDATE budgets
    SET spent = NVL(spent, 0) + p_amount_spent
    WHERE dept_id = p_dept_id;

    IF SQL%NOTFOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Department ID ' || p_dept_id || ' not found.');
    END IF;
END;
----------------------------------------------------------------------------------------------------------------------------------
create or replace PROCEDURE department_spend(
    p_dept_id NUMBER,
    p_amount_spent NUMBER
)
AS
BEGIN
    UPDATE budgets
    SET spent = NVL(spent, 0) + p_amount_spent
    WHERE dept_id = p_dept_id;

    IF SQL%NOTFOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Department ID ' || p_dept_id || ' not found.');
    END IF;

    COMMIT;
END;
----------------------------------------------------------------------------------------------------------------------------------
DECLARE
    v_dept_id NUMBER := 24;
    v_amount NUMBER := 556.64;
BEGIN
    department_spend(v_dept_id, v_amount);
END;
----------------------------------------------------------------------------------------------------------------------------------
DECLARE
    v_dept_id NUMBER := 22;
    v_amount NUMBER := 500.001111;
BEGIN
    department_spend(v_dept_id, v_amount);
END;
----------------------------------------------------------------------------------------------------------------------------------
DECLARE
    v_dept_id NUMBER := 21;
    v_amount NUMBER := 300.004445;
BEGIN
    department_spend(v_dept_id, v_amount);
END;
----------------------------------------------------------------------------------------------------------------------------------
DECLARE
    v_dept_id NUMBER := 21;
    v_amount NUMBER := 300.005;
BEGIN
    department_spend(v_dept_id, v_amount);
END;
----------------------------------------------------------------------------------------------------------------------------------
create or replace PACKAGE BODY reporting_pkg AS
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
----------------------------------------------------------------------------------------------------------------------------------
BEGIN
    reporting_pkg.take_kpi_snapshot;
END;
/
SELECT * FROM kpi_logs;
----------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE budgets
DROP CONSTRAINT FK_BUDGET_DEPT
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE budgets
ADD CONSTRAINT fk_budget_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE decisions
DROP CONSTRAINT fk_decision_decider;

ALTER TABLE decisions
ADD CONSTRAINT fk_decision_decider FOREIGN KEY (decider_id) REFERENCES employees(emp_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE decisions
DROP CONSTRAINT fk_decision_request;

ALTER TABLE decisions
ADD CONSTRAINT fk_decision_request FOREIGN KEY (request_id) REFERENCES requests(request_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE departments
DROP CONSTRAINT fk_dept_manager;

ALTER TABLE departments
ADD CONSTRAINT fk_dept_manager FOREIGN KEY (manager_id) REFERENCES employees(emp_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE employees
DROP CONSTRAINT fk_emp_dept;

ALTER TABLE employees
ADD CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE employees
DROP CONSTRAINT fk_emp_role;

ALTER TABLE employees
ADD CONSTRAINT fk_emp_role FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE incidents
DROP CONSTRAINT fk_inc_assignee;

ALTER TABLE incidents
ADD CONSTRAINT fk_inc_assignee FOREIGN KEY (assigned_to) REFERENCES employees(emp_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE incidents
DROP CONSTRAINT fk_inc_dept;

ALTER TABLE incidents
ADD CONSTRAINT fk_inc_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE incidents
DROP CONSTRAINT fk_inc_reporter;

ALTER TABLE incidents
ADD CONSTRAINT fk_inc_reporter FOREIGN KEY (reported_by) REFERENCES employees(emp_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE kpi_logs
DROP CONSTRAINT fk_kpi_dept;

ALTER TABLE kpi_logs
ADD CONSTRAINT fk_kpi_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
DROP CONSTRAINT fk_req_stage;

ALTER TABLE requests
ADD CONSTRAINT fk_req_stage FOREIGN KEY (current_stage) REFERENCES workflow_stages(stage_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
DROP CONSTRAINT fk_req_submitter;

ALTER TABLE requests
ADD CONSTRAINT fk_req_submitter FOREIGN KEY (submitted_by) REFERENCES employees(emp_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
DROP CONSTRAINT fk_req_workflow;

ALTER TABLE requests
ADD CONSTRAINT fk_req_workflow FOREIGN KEY (workflow_id) REFERENCES workflows(workflow_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
DROP CONSTRAINT fk_task_assignee;

ALTER TABLE tasks
ADD CONSTRAINT fk_task_assignee FOREIGN KEY (assigned_to) REFERENCES employees(emp_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
DROP CONSTRAINT fk_task_creator;

ALTER TABLE tasks
ADD CONSTRAINT fk_task_creator FOREIGN KEY (created_by) REFERENCES employees(emp_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE workflow_stages
DROP CONSTRAINT fk_wfstage_workflow;

ALTER TABLE workflow_stages
ADD CONSTRAINT fk_wfstage_workflow FOREIGN KEY (workflow_id) REFERENCES workflows(workflow_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
ALTER TABLE workflow_stages
DROP CONSTRAINT fk_wfstags_dept;

ALTER TABLE workflow_stages
ADD CONSTRAINT fk_wfstage_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE CASCADE;
--------------------------------------------------------------------------------------------------------------------
DELETE FROM roles
WHERE role_id = 25;

COMMIT;
--------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_one_ops_manager_per_department
BEFORE INSERT OR UPDATE ON "ADMIN"."EMPLOYEES"
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    IF :NEW.is_active = 1 AND :NEW.role_id = 23 THEN
        
        SELECT COUNT(*)
        INTO v_count
        FROM "ADMIN"."EMPLOYEES"
        WHERE dept_id = :NEW.dept_id
        AND is_active = 1
        AND role_id = 23
        AND emp_id != NVL(:NEW.emp_id, -1);

        IF v_count > 0 THEN 
            RAISE_APPLICATION_ERROR(-20001, 'Validation Error: This department already has an active Operations Manager.');
        END IF;
        
    END IF;
END;
/
--------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_one_executive_per_department
BEFORE INSERT OR UPDATE ON "ADMIN"."EMPLOYEES"
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    IF :NEW.is_active = 1 AND :NEW.role_id = 24 THEN
        
        SELECT COUNT(*)
        INTO v_count
        FROM "ADMIN"."EMPLOYEES"
        WHERE dept_id = :NEW.dept_id
        AND is_active = 1
        AND role_id = 24
        AND emp_id != NVL(:NEW.emp_id, -1);

        IF v_count > 0 THEN 
            RAISE_APPLICATION_ERROR(-20001, 'Validation Error: This department already has an active Operations Manager.');
        END IF;
        
    END IF;
END;
/
--------------------------------------------------------------------------------------------------------------------
CREATE ROLE role_employee;
CREATE ROLE role_supervisor;
CREATE ROLE role_ops_manager;
CREATE ROLE role_executive;
--------------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON workflow_pkg TO role_employee;
GRANT EXECUTE ON incident_pkg TO role_employee;
--------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE assign_task(
    created_by NUMBER,
    assigned_to NUMBER,
    title VARCHAR2,
    priority VARCHAR2,
    due_date DATE
)
IS
BEGIN
    INSERT INTO tasks (assigned_to, created_by, title, priority, due_date)
    VALUES (assigned_to, created_by, title, priority, due_date);
END;
--------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE assign_task(
    created_by NUMBER,
    assigned_to NUMBER,
    title VARCHAR2,
    priority VARCHAR2,
    due_date DATE
)
IS
BEGIN
    INSERT INTO tasks (assigned_to, created_by, title, priority, due_date)
    VALUES (assigned_to, created_by, title, priority, due_date);
END;
/
--------------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON workflow_pkg TO role_supervisor;
GRANT EXECUTE ON incident_pkg TO role_supervisor;
GRANT EXECUTE ON assign_task TO role_supervisor;
--------------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON workflow_pkg TO role_ops_manager;
GRANT EXECUTE ON incident_pkg TO role_ops_manager;
GRANT EXECUTE ON reporting_pkg TO role_ops_manager;
GRANT EXECUTE ON department_spend TO role_ops_manager;
GRANT EXECUTE ON assign_task TO role_ops_manager;
--------------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON reporting_pkg TO role_executive;
GRANT EXECUTE ON incident_pkg TO role_executive;
--------------------------------------------------------------------------------------------------------------------
CREATE ROLE role_auditor;
--------------------------------------------------------------------------------------------------------------------
GRANT SELECT ON audit_logs TO role_auditor;
--------------------------------------------------------------------------------------------------------------------
CREATE USER app_employee IDENTIFIED BY "Emp2026#Secure";
CREATE USER app_auditor IDENTIFIED BY "Aud2026#Secure";
CREATE USER app_supervisor IDENTIFIED BY "Sup2026#Secure";
CREATE USER app_ops_manager IDENTIFIED BY "Mgr2026#Secure";
CREATE USER app_executive IDENTIFIED BY "Exe2026#Secure";
--------------------------------------------------------------------------------------------------------------------
GRANT CREATE SESSION TO app_employee;
GRANT CREATE SESSION TO app_auditor;
GRANT CREATE SESSION TO app_supervisor;
GRANT CREATE SESSION TO app_ops_manager;
GRANT CREATE SESSION TO app_executive;
--------------------------------------------------------------------------------------------------------------------
GRANT role_employee TO app_employee;
GRANT role_auditor TO app_auditor;
GRANT role_supervisor TO app_supervisor;
GRANT role_ops_manager TO app_ops_manager;
GRANT role_executive TO app_executive;
--------------------------------------------------------------------------------------------------------------------
SELECT grantee, privilege, table_name
FROM user_tab_privs
WHERE grantee IN (
    'ROLE_EMPLOYEE','ROLE_SUPERVISOR','ROLE_OPS_MANAGER',
    'ROLE_EXECUTIVE','ROLE_AUDITOR'
)
ORDER BY grantee, table_name;
--------------------------------------------------------------------------------------------------------------------
SELECT granted_role, grantee
FROM dba_role_privs
WHERE grantee IN (
    'APP_EMPLOYEE','APP_SUPERVISOR','APP_OPS_MANAGER',
    'APP_EXECUTIVE','APP_AUDIT_EMPLOYEE'
)
ORDER BY grantee;
--------------------------------------------------------------------------------------------------------------------
CONNECT app_employee/"Emp2026#Secure";

DECLARE
    v_id NUMBER;
BEGIN
    v_id := ADMIN.workflow_pkg.submit_request(
        p_emp_id      => 6,
        p_workflow_id => 21,
        p_notes       => 'Security test request'
    );
    DBMS_OUTPUT.PUT_LINE('Submitted: ' || v_id);
END;
/
--------------------------------------------------------------------------------------------------------------------
CONNECT app_employee/"Emp2026#Secure";
SELECT * FROM ADMIN.requests;
--------------------------------------------------------------------------------------------------------------------
CONNECT app_employee/"Emp2026#Secure";
BEGIN
    ADMIN.reporting_pkg.take_kpi_snapshot;
END;
/
--------------------------------------------------------------------------------------------------------------------
CONNECT app_audit_employee/"Aud2026#Secure";

SELECT table_name, action, changed_at 
FROM ADMIN.audit_logs 
WHERE ROWNUM <= 5;
--------------------------------------------------------------------------------------------------------------------
CONNECT app_audit_employee/"Aud2026#Secure";

BEGIN
    ADMIN.workflow_pkg.escalate_overdue;
END;
/
--------------------------------------------------------------------------------------------------------------------
CONNECT app_audit_employee/"Aud2026#Secure";

BEGIN
    ADMIN.reporting_pkg.employee_workload_report;
END;
/
--------------------------------------------------------------------------------------------------------------------
CREATE PUBLIC SYNONYM workflow_pkg FOR ADMIN.workflow_pkg;
CREATE PUBLIC SYNONYM incident_pkg FOR ADMIN.incident_pkg;
CREATE PUBLIC SYNONYM reporting_pkg FOR ADMIN.reporting_pkg;
CREATE PUBLIC SYNONYM department_spend FOR ADMIN.department_spend;
CREATE PUBLIC SYNONYM assign_task FOR ADMIN.assign_task;
CREATE PUBLIC SYNONYM audit_logs FOR ADMIN.audit_logs;
--------------------------------------------------------------------------------------------------------------------
DROP USER app_audit_employee;
-----------------------------------------------------------------------------------------------------------------
CREATE USER app_auditor IDENTIFIED BY "Aud2026#Secure";
-----------------------------------------------------------------------------------------------------------------
GRANT CREATE SESSION TO app_auditor;
-----------------------------------------------------------------------------------------------------------------
GRANT role_auditor TO app_auditor;
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_assign_tasks_to_subordinates_in_department
BEFORE INSERT OR UPDATE ON "ADMIN"."TASKS"
FOR EACH ROW
DECLARE
    v_creator_department departments.dept_id%TYPE;
    v_assignee_department departments.dept_id%TYPE;
    v_creator_role_level roles.role_level%TYPE;
    v_assignee_role_level roles.role_level%TYPE;
BEGIN  
    IF :NEW.created_by IS NULL THEN
        RAISE_APPLICATION_ERROR(-20003, 'You cannot assign a task without specifying who created it');
    ELSIF :NEW.assigned_to IS NULL THEN
        RAISE_APPLICATION_ERROR(-20004, 'You must specify who you are assigning the task to');
    END IF;

    SELECT e.dept_id, r.role_level
    INTO v_creator_department, v_creator_role_level
    FROM employees e
    JOIN roles r 
    ON r.role_id = e.role_id
    WHERE e.emp_id = :NEW.created_by;

    SELECT e.dept_id, r.role_level
    INTO v_assignee_department, v_assignee_role_level
    FROM employees e
    JOIN roles r 
    ON r.role_id = e.role_id
    WHERE e.emp_id = :NEW.assigned_to;

    IF v_creator_department != v_assignee_department THEN
        RAISE_APPLICATION_ERROR(-20001, 'Tasks cannot be assigned to users outside your department');
    END IF;

    IF v_creator_role_level <= v_assignee_role_level THEN
        RAISE_APPLICATION_ERROR(-20002, 'Tasks can only be assigned to users with a lower role level than yourself');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20005, 'Either the user you tried to assign the task to does not exist or the specified creator of the task does not exists');
END;
/
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE departments
DROP CONSTRAINT fk_dept_manager;

ALTER TABLE departments
ADD CONSTRAINT fk_dept_manager FOREIGN KEY (manager_id) REFERENCES employees(emp_id);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE employees
DROP CONSTRAINT fk_emp_dept;

ALTER TABLE employees
ADD CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE employees
DROP CONSTRAINT fk_emp_role;

ALTER TABLE employees
ADD CONSTRAINT fk_emp_role FOREIGN KEY (role_id) REFERENCES roles(role_id);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE incidents
DROP CONSTRAINT fk_inc_assignee;

ALTER TABLE incidents
ADD CONSTRAINT fk_inc_assignee FOREIGN KEY (assigned_to) REFERENCES employees(emp_id);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE incidents
MODIFY(reported_by NUMBER NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE incidents
DROP CONSTRAINT fk_inc_reporter;

ALTER TABLE incidents
ADD CONSTRAINT fk_inc_reporter FOREIGN KEY (reported_by) REFERENCES employees(emp_id);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
MODIFY(submitted_by NUMBER NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
DROP CONSTRAINT fk_req_submitter;

ALTER TABLE requests
ADD CONSTRAINT fk_req_submitter FOREIGN KEY (submitted_by) REFERENCES employees(emp_id)
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
DROP CONSTRAINT fk_req_stage;

ALTER TABLE requests
ADD CONSTRAINT fk_req_stage FOREIGN KEY (current_stage) REFERENCES workflow_stages(stage_id);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
MODIFY(assigned_to NUMBER NULL);

ALTER TABLE tasks
MODIFY(created_by NUMBER NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
DROP CONSTRAINT fk_task_assignee;

ALTER TABLE tasks
ADD CONSTRAINT fk_task_assignee FOREIGN KEY (assigned_to) REFERENCES employees(emp_id);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
DROP CONSTRAINT fk_task_creator;

ALTER TABLE tasks
ADD CONSTRAINT fk_task_creator FOREIGN KEY (created_by) REFERENCES employees(emp_id);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE workflow_stages
DROP CONSTRAINT fk_wfstage_dept;

ALTER TABLE workflow_stages
ADD CONSTRAINT fk_wfstage_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE employees
MODIFY(dept_id NUMBER NOT NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE employees
MODIFY(role_id NUMBER NOT NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE incidents
MODIFY(assigned_to NUMBER NOT NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
DROP CONSTRAINT fk_req_workflow;

ALTER TABLE requests
ADD CONSTRAINT fk_req_workflow FOREIGN KEY (workflow_id) REFERENCES workflows(workflow_id);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
MODIFY(current_stage NUMBER NOT NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE requests
MODIFY(submitted_by NUMBER NOT NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
MODIFY(assigned_to NUMBER NOT NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
MODIFY(created_by NUMBER NOT NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE workflow_stages
MODIFY(dept_id NUMBER NOT NULL);
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE kpi_logs MODIFY (kpi_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE roles MODIFY (role_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE departments MODIFY (dept_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE budgets MODIFY (budget_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE incidents MODIFY (incident_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE employees MODIFY (emp_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE requests MODIFY (request_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE decisions MODIFY (decision_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE tasks MODIFY (task_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE audit_logs MODIFY (audit_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE workflows MODIFY (workflow_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
ALTER TABLE workflow_stages MODIFY (stage_id GENERATED ALWAYS AS IDENTITY (START WITH 1));
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_one_executive_per_department
BEFORE INSERT OR UPDATE ON "ADMIN"."EMPLOYEES"
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    IF :NEW.is_active = 1 AND :NEW.role_id = 4 THEN
        
        SELECT COUNT(*)
        INTO v_count
        FROM "ADMIN"."EMPLOYEES"
        WHERE dept_id = :NEW.dept_id
        AND is_active = 1
        AND role_id = 4
        AND emp_id != NVL(:NEW.emp_id, -1);

        IF v_count > 0 THEN 
            RAISE_APPLICATION_ERROR(-20001, 'Validation Error: This department already has an active Operations Manager.');
        END IF;
        
    END IF;
END;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_one_executive_per_department
FOR INSERT OR UPDATE ON "ADMIN"."EMPLOYEES"
COMPOUND TRIGGER

    TYPE t_dept_ids IS TABLE OF "ADMIN"."EMPLOYEES".dept_id%TYPE;
    v_depts t_dept_ids := t_dept_ids();

    BEFORE EACH ROW IS
    BEGIN
        IF :NEW.is_active = 1 AND :NEW.role_id = 4 THEN
            v_depts.EXTEND;
            v_depts(v_depts.LAST) := :NEW.dept_id;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
        v_count NUMBER;
    BEGIN
        IF v_depts.COUNT > 0 THEN
            FOR i IN 1..v_depts.COUNT LOOP
                SELECT COUNT(*)
                INTO v_count
                FROM "ADMIN"."EMPLOYEES"
                WHERE dept_id = v_depts(i)
                AND is_active = 1
                AND role_id = 4;

                IF v_count > 1 THEN 
                    RAISE_APPLICATION_ERROR(-20001, 'Validation Error: This department already has an active Executive.');
                END IF;
            END LOOP;
        END IF;
    END AFTER STATEMENT;
END;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_one_ops_manager_per_department
FOR INSERT OR UPDATE ON "ADMIN"."EMPLOYEES"
COMPOUND TRIGGER

    TYPE t_dept_ids IS TABLE OF "ADMIN"."EMPLOYEES".dept_id%TYPE;
    v_depts t_dept_ids := t_dept_ids();

    BEFORE EACH ROW IS
    BEGIN
        IF :NEW.is_active = 1 AND :NEW.role_id = 3 THEN
            v_depts.EXTEND;
            v_depts(v_depts.LAST) := :NEW.dept_id;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
        v_count NUMBER;
    BEGIN
        IF v_depts.COUNT > 0 THEN
            FOR i IN 1..v_depts.COUNT LOOP
                SELECT COUNT(*)
                INTO v_count
                FROM "ADMIN"."EMPLOYEES"
                WHERE dept_id = v_depts(i)
                AND is_active = 1
                AND role_id = 3;

                IF v_count > 1 THEN 
                    RAISE_APPLICATION_ERROR(-20001, 'Validation Error: This department already has an active Operations Manager.');
                END IF;
            END LOOP;
        END IF;
    END AFTER STATEMENT;
END;
/
-----------------------------------------------------------------------------------------------------------------
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

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
        v_request_status NUMBER;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

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
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE incidents
MODIFY assigned_to NUMBER NULL;
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := EXTRACT(DAY    FROM (SYSTIMESTAMP - v_submitted)) * 24 
                        + EXTRACT(HOUR   FROM (SYSTIMESTAMP - v_submitted))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_submitted)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - v_submitted)) / 3600;

        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used);
        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours);
        v_pct := (v_hours_used / v_sla_hours) * 100;

        DBMS_OUTPUT.PUT_LINE('percentage of time given used: ' || v_pct);

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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := EXTRACT(DAY    FROM (SYSTIMESTAMP - v_submitted)) * 24 
                        + EXTRACT(HOUR   FROM (SYSTIMESTAMP - v_submitted))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_submitted)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - v_submitted)) / 3600;

        v_hours_used := v_hours_used * -1;

        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used);
        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours);
        v_pct := (v_hours_used / v_sla_hours) * 100;

        DBMS_OUTPUT.PUT_LINE('percentage of time given used: ' || v_pct);

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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := EXTRACT(DAY    FROM (SYSTIMESTAMP - v_submitted)) * 24 
                        + EXTRACT(HOUR   FROM (SYSTIMESTAMP - v_submitted))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_submitted)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - v_submitted)) / 3600;

        v_hours_used := v_hours_used * -1;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');
    
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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');
    
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
-----------------------------------------------------------------------------------------------------------------
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
        v_ops_manager_id departments.manager_id%TYPE;
    BEGIN
        SELECT i.dept_id, d.manager_id
        INTO v_dept_id, v_ops_manager_id
        FROM incidents i
        JOIN departments d
        ON d.dept_id = i.dept_id
        WHERE i.incident_id = p_incident_id;

        IF v_ops_manager_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'the department does not have manager');
        END IF;

        UPDATE incidents
        SET assigned_to = v_ops_manager_id,
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
-----------------------------------------------------------------------------------------------------------------
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
        v_ops_manager_id departments.manager_id%TYPE;
    BEGIN
        SELECT i.dept_id, d.manager_id
        INTO v_dept_id, v_ops_manager_id
        FROM incidents i
        JOIN departments d
        ON d.dept_id = i.dept_id
        WHERE i.incident_id = p_incident_id;

        IF v_ops_manager_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'the department does not have manager');
        END IF;

        UPDATE incidents
        SET assigned_to = v_ops_manager_id,
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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
            AND r.submitted_at + NUMTODSINTERVAL(w.sla_hours, 'HOUR') < SYSTIMESTAMP;

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
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');
    
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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
            AND r.submitted_at + NUMTODSINTERVAL(w.sla_hours, 'HOUR') < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            DBMS_OUTPUT.PUT_LINE(rec.request_id);
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
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');
    
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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
            AND (r.submitted_at + NUMTODSINTERVAL(w.sla_hours, 'HOUR')) < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            DBMS_OUTPUT.PUT_LINE(rec.request_id);
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
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');
    
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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
            AND (r.submitted_at + NUMTODSINTERVAL(w.sla_hours, 'HOUR')) > SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            DBMS_OUTPUT.PUT_LINE(rec.request_id);
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
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');
    
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
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE workflow_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- checks to see if jobs are overdue and if they are escalates the job to a hire authority to handle
    PROCEDURE escalate_overdue;

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

END workflow_pkg;
/

create or replace PACKAGE BODY workflow_pkg AS

    
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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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
            AND (FROM_TZ(r.submitted_at, 'UTC') + NUMTODSINTERVAL(w.sla_hours, 'HOUR')) < SYSTIMESTAMP;

        v_count NUMBER := 0;
        v_old_status requests.status%TYPE;
    BEGIN
        FOR rec IN c_overdue LOOP
            DBMS_OUTPUT.PUT_LINE(rec.request_id);
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
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');
    
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
-----------------------------------------------------------------------------------------------------------------
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
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id  = dept.dept_id
            AND r.status NOT IN ('COMPLETED','CANCELLED','REJECTED');

            SELECT COUNT(*) 
            INTO v_breaches
            FROM requests r
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id = dept.dept_id
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
-----------------------------------------------------------------------------------------------------------------
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
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id  = dept.dept_id
            AND r.status NOT IN ('COMPLETED','CANCELLED','REJECTED');

            SELECT COUNT(*) 
            INTO v_breaches
            FROM requests r
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id = dept.dept_id
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

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            WITH stage_decisions AS (
                SELECT
                    d.request_id,
                    d.stage_id,
                    ws.stage_name,
                    ws.stage_seq,
                    w.workflow_name,
                    d.decision_at,
                    LAG(d.decision_at) OVER (
                        PARTITION BY d.request_id
                        ORDER BY ws.stage_seq
                    ) AS prev_decision_at
                FROM decisions d
                JOIN workflow_stages ws ON ws.stage_id  = d.stage_id
                JOIN requests r ON r.request_id = d.request_id
                JOIN workflows w ON w.workflow_id = r.workflow_id
            ),
            dwell_times AS (
                SELECT
                    sd.workflow_name,
                    sd.stage_name,
                    sd.stage_seq,
                    ROUND(
                        EXTRACT(DAY  FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) * 24
                        + EXTRACT(HOUR FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        )))
                        + EXTRACT(MINUTE FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) / 60,
                    2) AS dwell_hours
                FROM stage_decisions sd
            )
            SELECT
                workflow_name,
                stage_name,
                stage_seq,
                COUNT(*) AS requests_through_stage,
                ROUND(AVG(dwell_hours), 2) AS avg_dwell_hours,
                ROUND(MAX(dwell_hours), 2) AS max_dwell_hours,
                
                RANK() OVER (
                    PARTITION BY workflow_name
                    ORDER BY AVG(dwell_hours) DESC
                )
            AS bottleneck_rank
            FROM dwell_times
            GROUP BY workflow_name, stage_name, stage_seq
            ORDER BY workflow_name, bottleneck_rank;

        RETURN v_cur;
    END workflow_bottleneck_report;

END reporting_pkg;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE reporting_pkg AS
    PROCEDURE take_kpi_snapshot;

    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR;

    FUNCTION employee_workload_report RETURN SYS_REFCURSOR;

    FUNCTION incident_trend_report RETURN SYS_REFCURSOR;

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR;

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
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id  = dept.dept_id
            AND r.status NOT IN ('COMPLETED','CANCELLED','REJECTED');

            SELECT COUNT(*) 
            INTO v_breaches
            FROM requests r
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id = dept.dept_id
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

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            WITH stage_decisions AS (
                SELECT
                    d.request_id,
                    d.stage_id,
                    ws.stage_name,
                    ws.stage_seq,
                    w.workflow_name,
                    d.decision_at,
                    LAG(d.decision_at) OVER (
                        PARTITION BY d.request_id
                        ORDER BY ws.stage_seq
                    ) AS prev_decision_at
                FROM decisions d
                JOIN workflow_stages ws ON ws.stage_id  = d.stage_id
                JOIN requests r ON r.request_id = d.request_id
                JOIN workflows w ON w.workflow_id = r.workflow_id
            ),
            dwell_times AS (
                SELECT
                    sd.workflow_name,
                    sd.stage_name,
                    sd.stage_seq,
                    ROUND(
                        EXTRACT(DAY  FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) * 24
                        + EXTRACT(HOUR FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        )))
                        + EXTRACT(MINUTE FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) / 60,
                    2) AS dwell_hours
                FROM stage_decisions sd
            )
            SELECT
                workflow_name,
                stage_name,
                stage_seq,
                COUNT(*) AS requests_through_stage,
                ROUND(AVG(dwell_hours), 2) AS avg_dwell_hours,
                ROUND(MAX(dwell_hours), 2) AS max_dwell_hours,
                
                RANK() OVER (
                    PARTITION BY workflow_name
                    ORDER BY AVG(dwell_hours) DESC
                )
            AS bottleneck_rank
            FROM dwell_times
            GROUP BY workflow_name, stage_name, stage_seq
            ORDER BY workflow_name, bottleneck_rank;

        RETURN v_cur;
    END workflow_bottleneck_report;

END reporting_pkg;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE reporting_pkg AS
    PROCEDURE take_kpi_snapshot;

    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR;

    FUNCTION employee_workload_report RETURN SYS_REFCURSOR;

    FUNCTION incident_trend_report RETURN SYS_REFCURSOR;

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR;

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
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id  = dept.dept_id
            AND r.status NOT IN ('COMPLETED','CANCELLED','REJECTED');

            SELECT COUNT(*) 
            INTO v_breaches
            FROM requests r
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id = dept.dept_id
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

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            WITH stage_decisions AS (
                SELECT
                    d.request_id,
                    d.stage_id,
                    ws.stage_name,
                    ws.stage_seq,
                    w.workflow_name,
                    d.decision_at,
                    LAG(d.decision_at) OVER (
                        PARTITION BY d.request_id
                        ORDER BY ws.stage_seq
                    ) AS prev_decision_at
                FROM decisions d
                JOIN workflow_stages ws ON ws.stage_id  = d.stage_id
                JOIN requests r ON r.request_id = d.request_id
                JOIN workflows w ON w.workflow_id = r.workflow_id
            ),
            dwell_times AS (
                SELECT
                    sd.workflow_name,
                    sd.stage_name,
                    sd.stage_seq,
                    ROUND(
                        EXTRACT(DAY  FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) * 24
                        + EXTRACT(HOUR FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        )))
                        + EXTRACT(MINUTE FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) / 60,
                    2) AS dwell_hours
                FROM stage_decisions sd
            )
            SELECT
                workflow_name,
                stage_name,
                stage_seq,
                COUNT(*) AS requests_through_stage,
                ROUND(AVG(dwell_hours), 2) AS avg_dwell_hours,
                ROUND(MAX(dwell_hours), 2) AS max_dwell_hours,
                
                RANK() OVER (
                    PARTITION BY workflow_name
                    ORDER BY AVG(dwell_hours) DESC
                )
            AS bottleneck_rank
            FROM dwell_times
            GROUP BY workflow_name, stage_name, stage_seq
            ORDER BY workflow_name, bottleneck_rank;

        RETURN v_cur;
    END workflow_bottleneck_report;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                b.allocated,
                b.spent,
                b.allocated - b.spent AS remaining,
                ROUND((b.spent / NULLIF(b.allocated,0)) * 100, 2) AS pct_used,
                ROUND(RATIO_TO_REPORT(b.spent) OVER () * 100, 2) AS pct_of_company_spend,
                RANK() OVER (ORDER BY b.spent DESC) AS spend_rank,
                CASE
                    WHEN b.spent / NULLIF(b.allocated,0) >= 1.00 THEN 'OVERSPENT'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.85 THEN 'AT_RISK'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.60 THEN 'ON_TRACK'
                    ELSE 'UNDERSPENT'
                END AS spend_status
            FROM budgets b
            JOIN departments d ON d.dept_id = b.dept_id
            WHERE b.fiscal_year = TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'))
            ORDER BY spend_rank;

        RETURN v_cur;
    END budget_utilisation_report;


END reporting_pkg;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE reporting_pkg AS
    PROCEDURE take_kpi_snapshot;

    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR;

    FUNCTION employee_workload_report RETURN SYS_REFCURSOR;

    FUNCTION incident_trend_report RETURN SYS_REFCURSOR;

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR;

    FUNCTION request_aging_report RETURN SYS_REFCURSOR;

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
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id  = dept.dept_id
            AND r.status NOT IN ('COMPLETED','CANCELLED','REJECTED');

            SELECT COUNT(*) 
            INTO v_breaches
            FROM requests r
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id = dept.dept_id
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

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            WITH stage_decisions AS (
                SELECT
                    d.request_id,
                    d.stage_id,
                    ws.stage_name,
                    ws.stage_seq,
                    w.workflow_name,
                    d.decision_at,
                    LAG(d.decision_at) OVER (
                        PARTITION BY d.request_id
                        ORDER BY ws.stage_seq
                    ) AS prev_decision_at
                FROM decisions d
                JOIN workflow_stages ws ON ws.stage_id  = d.stage_id
                JOIN requests r ON r.request_id = d.request_id
                JOIN workflows w ON w.workflow_id = r.workflow_id
            ),
            dwell_times AS (
                SELECT
                    sd.workflow_name,
                    sd.stage_name,
                    sd.stage_seq,
                    ROUND(
                        EXTRACT(DAY  FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) * 24
                        + EXTRACT(HOUR FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        )))
                        + EXTRACT(MINUTE FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) / 60,
                    2) AS dwell_hours
                FROM stage_decisions sd
            )
            SELECT
                workflow_name,
                stage_name,
                stage_seq,
                COUNT(*) AS requests_through_stage,
                ROUND(AVG(dwell_hours), 2) AS avg_dwell_hours,
                ROUND(MAX(dwell_hours), 2) AS max_dwell_hours,
                
                RANK() OVER (
                    PARTITION BY workflow_name
                    ORDER BY AVG(dwell_hours) DESC
                )
            AS bottleneck_rank
            FROM dwell_times
            GROUP BY workflow_name, stage_name, stage_seq
            ORDER BY workflow_name, bottleneck_rank;

        RETURN v_cur;
    END workflow_bottleneck_report;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                b.allocated,
                b.spent,
                b.allocated - b.spent AS remaining,
                ROUND((b.spent / NULLIF(b.allocated,0)) * 100, 2) AS pct_used,
                ROUND(RATIO_TO_REPORT(b.spent) OVER () * 100, 2) AS pct_of_company_spend,
                RANK() OVER (ORDER BY b.spent DESC) AS spend_rank,
                CASE
                    WHEN b.spent / NULLIF(b.allocated,0) >= 1.00 THEN 'OVERSPENT'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.85 THEN 'AT_RISK'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.60 THEN 'ON_TRACK'
                    ELSE 'UNDERSPENT'
                END AS spend_status
            FROM budgets b
            JOIN departments d ON d.dept_id = b.dept_id
            WHERE b.fiscal_year = TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'))
            ORDER BY spend_rank;

        RETURN v_cur;
    END budget_utilisation_report;

    FUNCTION request_aging_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                r.request_id,
                w.workflow_name,
                e.first_name || ' ' || e.last_name AS submitted_by,
                d.dept_name,
                ws.stage_name AS waiting_at_stage,
                r.status,
                r.submitted_at,
                ROUND(
                    EXTRACT(DAY FROM (SYSTIMESTAMP - r.submitted_at)) * 24
                    + EXTRACT(HOUR FROM (SYSTIMESTAMP - r.submitted_at))
                    + EXTRACT(MINUTE FROM (SYSTIMESTAMP - r.submitted_at)) / 60
                    + EXTRACT(SECOND FROM (SYSTIMESTAMP - r.submitted_at)) / 3600,
                1) AS hours_open,
                CASE
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - r.submitted_at)) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - r.submitted_at))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - r.submitted_at)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - r.submitted_at)) / 3600
                    ) < 24 THEN 'Under 1 day'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - r.submitted_at)) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - r.submitted_at))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - r.submitted_at)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - r.submitted_at)) / 3600
                    ) < 72    THEN '1-3 days'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - r.submitted_at)) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - r.submitted_at))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - r.submitted_at)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - r.submitted_at)) / 3600
                    ) < 168   THEN '3-7 days'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - r.submitted_at)) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - r.submitted_at))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - r.submitted_at)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - r.submitted_at)) / 3600
                    ) < 336   THEN '1-2 weeks'
                    ELSE 'Over 2 weeks'
                END AS age_bucket,
                CASE
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - r.submitted_at)) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - r.submitted_at))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - r.submitted_at)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - r.submitted_at)) / 3600
                    ) / w.sla_hours < 0.70 THEN 'ON_TRACK'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - r.submitted_at)) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - r.submitted_at))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - r.submitted_at)) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - r.submitted_at)) / 3600
                    ) / w.sla_hours < 1.00 THEN 'AT_RISK'
                    ELSE 'BREACHED'
                END AS sla_status,
                RANK() OVER (
                    PARTITION BY d.dept_id
                    ORDER BY r.submitted_at ASC
                ) AS dept_age_rank
            FROM requests r
            JOIN workflows w ON w.workflow_id = r.workflow_id
            JOIN employees e ON e.emp_id = r.submitted_by
            JOIN departments d ON d.dept_id = e.dept_id
            LEFT JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE r.status NOT IN ('COMPLETED','REJECTED','CANCELLED')
            ORDER BY hours_open DESC;

        RETURN v_cur;
    END request_aging_report;


END reporting_pkg;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE reporting_pkg AS
    PROCEDURE take_kpi_snapshot;

    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR;

    FUNCTION employee_workload_report RETURN SYS_REFCURSOR;

    FUNCTION incident_trend_report RETURN SYS_REFCURSOR;

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR;

    FUNCTION request_aging_report RETURN SYS_REFCURSOR;

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
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id  = dept.dept_id
            AND r.status NOT IN ('COMPLETED','CANCELLED','REJECTED');

            SELECT COUNT(*) 
            INTO v_breaches
            FROM requests r
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id = dept.dept_id
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

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            WITH stage_decisions AS (
                SELECT
                    d.request_id,
                    d.stage_id,
                    ws.stage_name,
                    ws.stage_seq,
                    w.workflow_name,
                    d.decision_at,
                    LAG(d.decision_at) OVER (
                        PARTITION BY d.request_id
                        ORDER BY ws.stage_seq
                    ) AS prev_decision_at
                FROM decisions d
                JOIN workflow_stages ws ON ws.stage_id  = d.stage_id
                JOIN requests r ON r.request_id = d.request_id
                JOIN workflows w ON w.workflow_id = r.workflow_id
            ),
            dwell_times AS (
                SELECT
                    sd.workflow_name,
                    sd.stage_name,
                    sd.stage_seq,
                    ROUND(
                        EXTRACT(DAY  FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) * 24
                        + EXTRACT(HOUR FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        )))
                        + EXTRACT(MINUTE FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) / 60,
                    2) AS dwell_hours
                FROM stage_decisions sd
            )
            SELECT
                workflow_name,
                stage_name,
                stage_seq,
                COUNT(*) AS requests_through_stage,
                ROUND(AVG(dwell_hours), 2) AS avg_dwell_hours,
                ROUND(MAX(dwell_hours), 2) AS max_dwell_hours,
                
                RANK() OVER (
                    PARTITION BY workflow_name
                    ORDER BY AVG(dwell_hours) DESC
                )
            AS bottleneck_rank
            FROM dwell_times
            GROUP BY workflow_name, stage_name, stage_seq
            ORDER BY workflow_name, bottleneck_rank;

        RETURN v_cur;
    END workflow_bottleneck_report;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                b.allocated,
                b.spent,
                b.allocated - b.spent AS remaining,
                ROUND((b.spent / NULLIF(b.allocated,0)) * 100, 2) AS pct_used,
                ROUND(RATIO_TO_REPORT(b.spent) OVER () * 100, 2) AS pct_of_company_spend,
                RANK() OVER (ORDER BY b.spent DESC) AS spend_rank,
                CASE
                    WHEN b.spent / NULLIF(b.allocated,0) >= 1.00 THEN 'OVERSPENT'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.85 THEN 'AT_RISK'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.60 THEN 'ON_TRACK'
                    ELSE 'UNDERSPENT'
                END AS spend_status
            FROM budgets b
            JOIN departments d ON d.dept_id = b.dept_id
            WHERE b.fiscal_year = TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'))
            ORDER BY spend_rank;

        RETURN v_cur;
    END budget_utilisation_report;

    FUNCTION request_aging_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                r.request_id,
                w.workflow_name,
                e.first_name || ' ' || e.last_name AS submitted_by,
                d.dept_name,
                ws.stage_name AS waiting_at_stage,
                r.status,
                r.submitted_at,
                ROUND(
                    EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                    + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                    + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                    + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600,
                1) AS hours_open,
                CASE
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 24 THEN 'Under 1 day'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 72    THEN '1-3 days'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 168   THEN '3-7 days'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 336   THEN '1-2 weeks'
                    ELSE 'Over 2 weeks'
                END AS age_bucket,
                CASE
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) / w.sla_hours < 0.70 THEN 'ON_TRACK'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) / w.sla_hours < 1.00 THEN 'AT_RISK'
                    ELSE 'BREACHED'
                END AS sla_status,
                RANK() OVER (
                    PARTITION BY d.dept_id
                    ORDER BY r.submitted_at ASC
                ) AS dept_age_rank
            FROM requests r
            JOIN workflows w ON w.workflow_id = r.workflow_id
            JOIN employees e ON e.emp_id = r.submitted_by
            JOIN departments d ON d.dept_id = e.dept_id
            LEFT JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE r.status NOT IN ('COMPLETED','REJECTED','CANCELLED')
            ORDER BY hours_open DESC;

        RETURN v_cur;
    END request_aging_report;


END reporting_pkg;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE reporting_pkg AS
    PROCEDURE take_kpi_snapshot;

    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR;

    FUNCTION employee_workload_report RETURN SYS_REFCURSOR;

    FUNCTION incident_trend_report RETURN SYS_REFCURSOR;

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR;

    FUNCTION request_aging_report RETURN SYS_REFCURSOR;
    
    FUNCTION dept_kpi_trend_report RETURN SYS_REFCURSOR;

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
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id  = dept.dept_id
            AND r.status NOT IN ('COMPLETED','CANCELLED','REJECTED');

            SELECT COUNT(*) 
            INTO v_breaches
            FROM requests r
            JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE ws.dept_id = dept.dept_id
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

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            WITH stage_decisions AS (
                SELECT
                    d.request_id,
                    d.stage_id,
                    ws.stage_name,
                    ws.stage_seq,
                    w.workflow_name,
                    d.decision_at,
                    LAG(d.decision_at) OVER (
                        PARTITION BY d.request_id
                        ORDER BY ws.stage_seq
                    ) AS prev_decision_at
                FROM decisions d
                JOIN workflow_stages ws ON ws.stage_id  = d.stage_id
                JOIN requests r ON r.request_id = d.request_id
                JOIN workflows w ON w.workflow_id = r.workflow_id
            ),
            dwell_times AS (
                SELECT
                    sd.workflow_name,
                    sd.stage_name,
                    sd.stage_seq,
                    ROUND(
                        EXTRACT(DAY  FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) * 24
                        + EXTRACT(HOUR FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        )))
                        + EXTRACT(MINUTE FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) / 60,
                    2) AS dwell_hours
                FROM stage_decisions sd
            )
            SELECT
                workflow_name,
                stage_name,
                stage_seq,
                COUNT(*) AS requests_through_stage,
                ROUND(AVG(dwell_hours), 2) AS avg_dwell_hours,
                ROUND(MAX(dwell_hours), 2) AS max_dwell_hours,
                
                RANK() OVER (
                    PARTITION BY workflow_name
                    ORDER BY AVG(dwell_hours) DESC
                )
            AS bottleneck_rank
            FROM dwell_times
            GROUP BY workflow_name, stage_name, stage_seq
            ORDER BY workflow_name, bottleneck_rank;

        RETURN v_cur;
    END workflow_bottleneck_report;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                b.allocated,
                b.spent,
                b.allocated - b.spent AS remaining,
                ROUND((b.spent / NULLIF(b.allocated,0)) * 100, 2) AS pct_used,
                ROUND(RATIO_TO_REPORT(b.spent) OVER () * 100, 2) AS pct_of_company_spend,
                RANK() OVER (ORDER BY b.spent DESC) AS spend_rank,
                CASE
                    WHEN b.spent / NULLIF(b.allocated,0) >= 1.00 THEN 'OVERSPENT'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.85 THEN 'AT_RISK'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.60 THEN 'ON_TRACK'
                    ELSE 'UNDERSPENT'
                END AS spend_status
            FROM budgets b
            JOIN departments d ON d.dept_id = b.dept_id
            WHERE b.fiscal_year = TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'))
            ORDER BY spend_rank;

        RETURN v_cur;
    END budget_utilisation_report;

    FUNCTION request_aging_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                r.request_id,
                w.workflow_name,
                e.first_name || ' ' || e.last_name AS submitted_by,
                d.dept_name,
                ws.stage_name AS waiting_at_stage,
                r.status,
                r.submitted_at,
                ROUND(
                    EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                    + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                    + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                    + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600,
                1) AS hours_open,
                CASE
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 24 THEN 'Under 1 day'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 72    THEN '1-3 days'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 168   THEN '3-7 days'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 336   THEN '1-2 weeks'
                    ELSE 'Over 2 weeks'
                END AS age_bucket,
                CASE
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) / w.sla_hours < 0.70 THEN 'ON_TRACK'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) / w.sla_hours < 1.00 THEN 'AT_RISK'
                    ELSE 'BREACHED'
                END AS sla_status,
                RANK() OVER (
                    PARTITION BY d.dept_id
                    ORDER BY r.submitted_at ASC
                ) AS dept_age_rank
            FROM requests r
            JOIN workflows w ON w.workflow_id = r.workflow_id
            JOIN employees e ON e.emp_id = r.submitted_by
            JOIN departments d ON d.dept_id = e.dept_id
            LEFT JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE r.status NOT IN ('COMPLETED','REJECTED','CANCELLED')
            ORDER BY hours_open DESC;

        RETURN v_cur;
    END request_aging_report;

    FUNCTION dept_kpi_trend_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                k.snapshot_date,
                k.open_incidents,
                k.open_requests,
                k.sla_breaches,
                k.budget_pct_used,
                k.open_incidents - LAG(k.open_incidents) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                ) AS incident_delta,
                k.open_requests - LAG(k.open_requests) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                ) AS request_delta,
                k.budget_pct_used - LAG(k.budget_pct_used) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                ) AS budget_delta,
                ROUND(AVG(k.open_incidents) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
                ), 2) AS inc_3day_avg
            FROM kpi_logs k
            JOIN departments d ON d.dept_id = k.dept_id
            ORDER BY d.dept_name, k.snapshot_date;

        RETURN v_cur;
    END dept_kpi_trend_report;


END reporting_pkg;
/
-----------------------------------------------------------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_dept_dashboard
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    d.dept_id,
    d.dept_name,
    COUNT(DISTINCT i.incident_id) AS total_incidents,
    COUNT(DISTINCT CASE WHEN i.status IN ('OPEN','IN_PROGRESS') THEN i.incident_id END) AS open_incidents,
    COUNT(DISTINCT CASE WHEN i.status = 'RESOLVED' THEN i.incident_id END) AS resolved_incidents,
    ROUND(AVG(i.resolution_min) / 60, 2) AS avg_resolution_h,
    COUNT(DISTINCT r.request_id) AS total_requests,
    COUNT(DISTINCT CASE WHEN r.status NOT IN ('COMPLETED','REJECTED','CANCELLED') THEN r.request_id END) AS open_requests,
    COUNT(DISTINCT CASE WHEN r.status = 'ESCALATED' THEN r.request_id END) AS escalated_requests,
    MAX(b.allocated) AS budget_allocated,
    MAX(b.spent) AS budget_spent,
    ROUND(MAX(b.spent) / NULLIF(MAX(b.allocated),0) * 100, 2)  AS budget_pct_used,
    RANK() OVER (ORDER BY AVG(i.resolution_min) ASC NULLS LAST) AS efficiency_rank,
    SYSDATE AS last_refreshed
FROM departments d
LEFT JOIN incidents i ON i.dept_id = d.dept_id
LEFT JOIN employees e ON e.dept_id = d.dept_id AND e.is_active = 1
LEFT JOIN requests r ON r.submitted_by = e.emp_id
LEFT JOIN budgets b ON b.dept_id = d.dept_id
AND b.fiscal_year = TO_NUMBER(TO_CHAR(SYSDATE,'YYYY'))
GROUP BY d.dept_id, d.dept_name;
-----------------------------------------------------------------------------------------------------------------
GRANT SELECT ON mv_dept_dashboard TO role_ops_manager;
GRANT SELECT ON mv_dept_dashboard TO role_executive;
CREATE PUBLIC SYNONYM mv_dept_dashboard FOR ADMIN.mv_dept_dashboard;
-----------------------------------------------------------------------------------------------------------------
REVOKE SELECT ON audit_logs FROM role_auditor;
-----------------------------------------------------------------------------------------------------------------
REVOKE EXECUTE ON workflow_pkg FROM role_employee;
REVOKE EXECUTE ON incident_pkg FROM role_employee;
-----------------------------------------------------------------------------------------------------------------
REVOKE EXECUTE ON reporting_pkg FROM role_executive;
REVOKE EXECUTE ON incident_pkg FROM role_executive;
REVOKE SELECT ON mv_dept_dashboard FROM role_executive;
-----------------------------------------------------------------------------------------------------------------
REVOKE EXECUTE ON workflow_pkg FROM role_ops_manager;
REVOKE EXECUTE ON incident_pkg FROM role_ops_manager;
REVOKE EXECUTE ON reporting_pkg FROM role_ops_manager;
REVOKE EXECUTE ON department_spend FROM role_ops_manager;
REVOKE EXECUTE ON assign_task FROM role_ops_manager;
REVOKE SELECT ON mv_dept_dashboard FROM role_ops_manager;
-----------------------------------------------------------------------------------------------------------------
REVOKE EXECUTE ON workflow_pkg FROM role_supervisor;
REVOKE EXECUTE ON incident_pkg FROM role_supervisor;
REVOKE EXECUTE ON assign_task FROM role_supervisor;
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE employee_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

END employee_pkg;
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE BODY employee_pkg AS

    
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

END employee_pkg;
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE BODY employee_pkg AS

    
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

END employee_pkg;
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE employee_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    PROCEDURE log_audit (
        p_table_name IN VARCHAR2,
        p_record_id IN NUMBER,
        p_action IN VARCHAR2,
        p_changed_by IN NUMBER,
        p_old_value IN VARCHAR2 DEFAULT NULL,
        p_new_value IN VARCHAR2 DEFAULT NULL
    );

END employee_pkg;
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE employee_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

END employee_pkg;
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE escalate_overdue AS
    CURSOR c_overdue IS
        SELECT r.request_id, r.submitted_at, w.sla_hours, r.status
        FROM requests  r
        JOIN workflows w ON w.workflow_id = r.workflow_id
        WHERE r.status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'IN_PROGRESS')
        AND (FROM_TZ(r.submitted_at, 'UTC') + NUMTODSINTERVAL(w.sla_hours, 'HOUR')) < SYSTIMESTAMP;

    v_count NUMBER := 0;
    v_old_status requests.status%TYPE;
BEGIN
    FOR rec IN c_overdue LOOP
        DBMS_OUTPUT.PUT_LINE(rec.request_id);
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
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE supervisor_pkg AS

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    );

END supervisor_pkg;
/

create or replace PACKAGE BODY supervisor_pkg AS


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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted TIMESTAMP;
        v_sla_hours NUMBER;
        v_hours_used NUMBER;
        v_pct NUMBER;
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');

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

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    )
    IS
    BEGIN
        INSERT INTO tasks (assigned_to, created_by, title, priority, due_date)
        VALUES (assigned_to, created_by, title, priority, due_date);
    END assign_task;

END supervisor_pkg;
/
-----------------------------------------------------------------------------------------------------------------
DROP PROCEDURE assign_task;
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE employee_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    FUNCTION log_incident (
        p_dept_id IN NUMBER,
        p_reported_by IN NUMBER,
        p_title IN VARCHAR2,
        p_severity IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    PROCEDURE auto_assign (p_incident_id IN NUMBER);

END employee_pkg;
/

create or replace PACKAGE BODY employee_pkg AS

    
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
        v_ops_manager_id departments.manager_id%TYPE;
    BEGIN
        SELECT i.dept_id, d.manager_id
        INTO v_dept_id, v_ops_manager_id
        FROM incidents i
        JOIN departments d
        ON d.dept_id = i.dept_id
        WHERE i.incident_id = p_incident_id;

        IF v_ops_manager_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'the department does not have manager');
        END IF;

        UPDATE incidents
        SET assigned_to = v_ops_manager_id,
            status = 'IN_PROGRESS'
        WHERE incident_id = p_incident_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END auto_assign;

END employee_pkg;
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE ops_manager_pkg AS

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution IN VARCHAR2
    );

END ops_manager_pkg;
/

create or replace PACKAGE BODY ops_manager_pkg AS

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
            description = description || CHR(10) || 'RESOLUTION: ' || p_resolution
        WHERE incident_id = p_incident_id;

        log_audit('INCIDENTS', p_incident_id, 'UPDATE', p_resolved_by,
                  'status=' || v_old_status,
                  'status=RESOLVED, resolution_min=' || v_minutes);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END resolve_incident;

END ops_manager_pkg;
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE ops_manager_pkg AS

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution IN VARCHAR2
    );

    PROCEDURE department_spend(
        p_dept_id NUMBER,
        p_amount_spent NUMBER
    );

END ops_manager_pkg;
/

create or replace PACKAGE BODY ops_manager_pkg AS

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
            description = description || CHR(10) || 'RESOLUTION: ' || p_resolution
        WHERE incident_id = p_incident_id;

        log_audit('INCIDENTS', p_incident_id, 'UPDATE', p_resolved_by,
                  'status=' || v_old_status,
                  'status=RESOLVED, resolution_min=' || v_minutes);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END resolve_incident;

    PROCEDURE department_spend(
        p_dept_id NUMBER,
        p_amount_spent NUMBER
    )
    AS
    BEGIN
        UPDATE budgets
        SET spent = NVL(spent, 0) + p_amount_spent
        WHERE dept_id = p_dept_id;

        IF SQL%NOTFOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Department ID ' || p_dept_id || ' not found.');
        END IF;

        COMMIT;
    END department_spend;

END ops_manager_pkg;
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE take_kpi_snapshot AS
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
        JOIN workflow_stages ws ON ws.stage_id = r.current_stage
        WHERE ws.dept_id  = dept.dept_id
        AND r.status NOT IN ('COMPLETED','CANCELLED','REJECTED');

        SELECT COUNT(*) 
        INTO v_breaches
        FROM requests r
        JOIN workflow_stages ws ON ws.stage_id = r.current_stage
        WHERE ws.dept_id = dept.dept_id
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
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE executive_pkg AS

    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR;

    FUNCTION employee_workload_report RETURN SYS_REFCURSOR;

    FUNCTION incident_trend_report RETURN SYS_REFCURSOR;

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR;

    FUNCTION request_aging_report RETURN SYS_REFCURSOR;
    
    FUNCTION dept_kpi_trend_report RETURN SYS_REFCURSOR;

END executive_pkg;
/

create or replace PACKAGE BODY executive_pkg AS

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

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            WITH stage_decisions AS (
                SELECT
                    d.request_id,
                    d.stage_id,
                    ws.stage_name,
                    ws.stage_seq,
                    w.workflow_name,
                    d.decision_at,
                    LAG(d.decision_at) OVER (
                        PARTITION BY d.request_id
                        ORDER BY ws.stage_seq
                    ) AS prev_decision_at
                FROM decisions d
                JOIN workflow_stages ws ON ws.stage_id  = d.stage_id
                JOIN requests r ON r.request_id = d.request_id
                JOIN workflows w ON w.workflow_id = r.workflow_id
            ),
            dwell_times AS (
                SELECT
                    sd.workflow_name,
                    sd.stage_name,
                    sd.stage_seq,
                    ROUND(
                        EXTRACT(DAY  FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) * 24
                        + EXTRACT(HOUR FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        )))
                        + EXTRACT(MINUTE FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) / 60,
                    2) AS dwell_hours
                FROM stage_decisions sd
            )
            SELECT
                workflow_name,
                stage_name,
                stage_seq,
                COUNT(*) AS requests_through_stage,
                ROUND(AVG(dwell_hours), 2) AS avg_dwell_hours,
                ROUND(MAX(dwell_hours), 2) AS max_dwell_hours,
                
                RANK() OVER (
                    PARTITION BY workflow_name
                    ORDER BY AVG(dwell_hours) DESC
                )
            AS bottleneck_rank
            FROM dwell_times
            GROUP BY workflow_name, stage_name, stage_seq
            ORDER BY workflow_name, bottleneck_rank;

        RETURN v_cur;
    END workflow_bottleneck_report;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                b.allocated,
                b.spent,
                b.allocated - b.spent AS remaining,
                ROUND((b.spent / NULLIF(b.allocated,0)) * 100, 2) AS pct_used,
                ROUND(RATIO_TO_REPORT(b.spent) OVER () * 100, 2) AS pct_of_company_spend,
                RANK() OVER (ORDER BY b.spent DESC) AS spend_rank,
                CASE
                    WHEN b.spent / NULLIF(b.allocated,0) >= 1.00 THEN 'OVERSPENT'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.85 THEN 'AT_RISK'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.60 THEN 'ON_TRACK'
                    ELSE 'UNDERSPENT'
                END AS spend_status
            FROM budgets b
            JOIN departments d ON d.dept_id = b.dept_id
            WHERE b.fiscal_year = TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'))
            ORDER BY spend_rank;

        RETURN v_cur;
    END budget_utilisation_report;

    FUNCTION request_aging_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                r.request_id,
                w.workflow_name,
                e.first_name || ' ' || e.last_name AS submitted_by,
                d.dept_name,
                ws.stage_name AS waiting_at_stage,
                r.status,
                r.submitted_at,
                ROUND(
                    EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                    + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                    + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                    + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600,
                1) AS hours_open,
                CASE
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 24 THEN 'Under 1 day'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 72    THEN '1-3 days'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 168   THEN '3-7 days'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 336   THEN '1-2 weeks'
                    ELSE 'Over 2 weeks'
                END AS age_bucket,
                CASE
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) / w.sla_hours < 0.70 THEN 'ON_TRACK'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) / w.sla_hours < 1.00 THEN 'AT_RISK'
                    ELSE 'BREACHED'
                END AS sla_status,
                RANK() OVER (
                    PARTITION BY d.dept_id
                    ORDER BY r.submitted_at ASC
                ) AS dept_age_rank
            FROM requests r
            JOIN workflows w ON w.workflow_id = r.workflow_id
            JOIN employees e ON e.emp_id = r.submitted_by
            JOIN departments d ON d.dept_id = e.dept_id
            LEFT JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE r.status NOT IN ('COMPLETED','REJECTED','CANCELLED')
            ORDER BY hours_open DESC;

        RETURN v_cur;
    END request_aging_report;

    FUNCTION dept_kpi_trend_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                k.snapshot_date,
                k.open_incidents,
                k.open_requests,
                k.sla_breaches,
                k.budget_pct_used,
                k.open_incidents - LAG(k.open_incidents) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                ) AS incident_delta,
                k.open_requests - LAG(k.open_requests) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                ) AS request_delta,
                k.budget_pct_used - LAG(k.budget_pct_used) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                ) AS budget_delta,
                ROUND(AVG(k.open_incidents) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
                ), 2) AS inc_3day_avg
            FROM kpi_logs k
            JOIN departments d ON d.dept_id = k.dept_id
            ORDER BY d.dept_name, k.snapshot_date;

        RETURN v_cur;
    END dept_kpi_trend_report;


END executive_pkg;
/
-----------------------------------------------------------------------------------------------------------------
DROP PACKAGE incident_pkg;
DROP PACKAGE reporting_pkg;
DROP PACKAGE workflow_pkg;
-----------------------------------------------------------------------------------------------------------------
DROP ROLE role_auditor;
-----------------------------------------------------------------------------------------------------------------
DROP USER app_auditor;
-----------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON employee_pkg TO role_employee;
-----------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON employee_pkg TO role_supervisor;
GRANT EXECUTE ON supervisor_pkg TO role_supervisor;
-----------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON employee_pkg TO role_ops_manager;
GRANT EXECUTE ON supervisor_pkg TO role_ops_manager;
GRANT EXECUTE ON ops_manager_pkg TO role_ops_manager;
GRANT SELECT ON mv_dept_dashboard TO role_ops_manager;
-----------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON employee_pkg TO role_executive;
GRANT EXECUTE ON supervisor_pkg TO role_executive;
GRANT EXECUTE ON executive_pkg TO role_executive;
GRANT SELECT ON mv_dept_dashboard TO role_executive;
-----------------------------------------------------------------------------------------------------------------
CREATE PUBLIC SYNONYM employee_pkg FOR ADMIN.employee_pkg;
CREATE PUBLIC SYNONYM supervisor_pkg FOR ADMIN.supervisor_pkg;
CREATE PUBLIC SYNONYM ops_manager_pkg FOR ADMIN.ops_manager_pkg;
CREATE PUBLIC SYNONYM executive_pkg FOR ADMIN.executive_pkg;
DROP PUBLIC SYNONYM workflow_pkg;
DROP PUBLIC SYNONYM incident_pkg;
DROP PUBLIC SYNONYM reporting_pkg;
DROP PUBLIC SYNONYM department_spend;
DROP PUBLIC SYNONYM assign_task;
DROP PUBLIC SYNONYM audit_logs;
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_update_department_manager_on_addtion
BEFORE INSERT OR UPDATE ON employees
FOR EACH ROW
WHEN (NEW.role_id = 3)
BEGIN
    UPDATE departments
    SET manager_id = :NEW.emp_id
    WHERE dept_id = :NEW.dept_id;
END;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_update_department_manager_on_addtion
AFTER INSERT OR UPDATE ON employees
FOR EACH ROW
WHEN (NEW.role_id = 3)
BEGIN
    UPDATE departments
    SET manager_id = :NEW.emp_id
    WHERE dept_id = :NEW.dept_id;
END;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_update_department_manager_on_delete
AFTER DELETE ON employees
FOR EACH ROW
WHEN (OLD.role_id = 3)
BEGIN
    UPDATE departments
    SET manager_id = NULL
    WHERE dept_id = :OLD.dept_id;
END;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_update_department_manager_on_demotion
AFTER UPDATE ON employees
FOR EACH ROW
WHEN (OLD.role_id = 3 AND NEW.role_id != 3)
BEGIN
    UPDATE departments
    SET manager_id = NULL
    WHERE dept_id = :OLD.dept_id;
END;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_update_department_manager_on_update
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
    IF :OLD.role_id = 3 AND :NEW.role_id != 3 THEN
        UPDATE departments
        SET manager_id = NULL
        WHERE dept_id = :OLD.dept_id;
        
    ELSIF :OLD.role_id != 3 AND :NEW.role_id = 3 THEN
        UPDATE departments
        SET manager_id = :NEW.emp_id
        WHERE dept_id = :NEW.dept_id;
    END IF;
END;
/
-----------------------------------------------------------------------------------------------------------------
DROP TRIGGER trg_update_department_manager_on_demotion
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_update_department_manager_on_insert
AFTER INSERT ON employees
FOR EACH ROW
WHEN (NEW.role_id = 3)
BEGIN
    UPDATE departments
    SET manager_id = :NEW.emp_id
    WHERE dept_id = :NEW.dept_id;
END;
/
-----------------------------------------------------------------------------------------------------------------
DROP TRIGGER trg_update_department_manager_on_addtion
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_update_department_manager_on_update
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
    IF :NEW.role_id = 3 AND :NEW.is_active = 0 THEN
        UPDATE departments
        SET manager_id = null
        WHERE dept_id = :NEW.dept_id;
    ELSIF :OLD.role_id = 3 AND :NEW.role_id != 3 THEN
        UPDATE departments
        SET manager_id = NULL
        WHERE dept_id = :OLD.dept_id;
    ELSIF :OLD.role_id != 3 AND :NEW.role_id = 3 THEN
        UPDATE departments
        SET manager_id = :NEW.emp_id
        WHERE dept_id = :NEW.dept_id;
    END IF;
END;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_update_department_manager_on_update
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
    IF :NEW.role_id = 3 AND :NEW.is_active = 0 THEN
        UPDATE departments
        SET manager_id = null
        WHERE dept_id = :NEW.dept_id;
    ELSIF :NEW.role_id = 3 AND :NEW.is_active = 1 THEN
        UPDATE departments
        SET manager_id = :NEW.emp_id
        WHERE dept_id = :NEW.dept_id;
    ELSIF :OLD.role_id = 3 AND :NEW.role_id != 3 THEN
        UPDATE departments
        SET manager_id = NULL
        WHERE dept_id = :OLD.dept_id;
    END IF;
END;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_update_department_manager_on_update
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
    IF :NEW.role_id = 3 AND :NEW.is_active = 0 THEN
        UPDATE departments
        SET manager_id = null
        WHERE dept_id = :NEW.dept_id;
    ELSIF :NEW.role_id = 3 AND :NEW.is_active = 1 THEN
        UPDATE departments
        SET manager_id = :NEW.emp_id
        WHERE dept_id = :NEW.dept_id;

        IF :OLD.dept_id != :NEW.dept_id THEN
            UPDATE departments
            SET manager_id = NULL
            WHERE dept_id = :OLD.dept_id;
        END IF;
    ELSIF :OLD.role_id = 3 AND :NEW.role_id != 3 THEN
        UPDATE departments
        SET manager_id = NULL
        WHERE dept_id = :NEW.dept_id;
    END IF;
END;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_assign_tasks_to_subordinates_only
BEFORE INSERT ON tasks
FOR EACH ROW
DECLARE
    v_creator_level NUMBER;
    v_assignee_level NUMBER;
BEGIN
    SELECT r.role_level
    INTO v_creator_level
    FROM employees e
    JOIN roles r ON r.role_id = e.role_id
    WHERE e.emp_id = :NEW.created_by;

    SELECT r.role_level
    INTO v_assignee_level
    FROM employees e
    JOIN roles r ON r.role_id = e.role_id
    WHERE emp_id = :NEW.assigned_to; 

    IF v_creator_level <= v_assignee_level THEN
        RAISE_APPLICATION_ERROR(-20020, 'cannot assign tasks to users with a higher role level than you');
    END IF;
END;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_assign_tasks_to_subordinates_only
BEFORE INSERT ON tasks
FOR EACH ROW
DECLARE
    v_creator_level NUMBER;
    v_assignee_level NUMBER;
BEGIN
    SELECT r.role_level
    INTO v_creator_level
    FROM employees e
    JOIN roles r ON r.role_id = e.role_id
    WHERE e.emp_id = :NEW.created_by;

    SELECT r.role_level
    INTO v_assignee_level
    FROM employees e
    JOIN roles r ON r.role_id = e.role_id
    WHERE emp_id = :NEW.assigned_to; 

    IF v_creator_level <= v_assignee_level THEN
        RAISE_APPLICATION_ERROR(-20020, 'cannot assign tasks to users with an equal or higher role level than you');
    END IF;
END;
/
-----------------------------------------------------------------------------------------------------------------
DROP TRIGGER trg_assign_tasks_to_subordinates_only;
COMMIT;
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE supervisor_pkg AS

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    );

END supervisor_pkg;
/

create or replace PACKAGE BODY supervisor_pkg AS


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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted TIMESTAMP;
        v_sla_hours NUMBER;
        v_hours_used NUMBER;
        v_pct NUMBER;
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');

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

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    )
    IS
    BEGIN
        INSERT INTO tasks (assigned_to, created_by, title, priority, due_date)
        VALUES (assigned_to, created_by, title, priority, due_date);
        COMMIT;
    END assign_task;

END supervisor_pkg;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_task_complete
BEFORE UPDATE ON tasks
FOR EACH ROW
WHEN (NEW.status = 'DONE' AND OLD.completed_at IS NULL)
BEGIN
    :NEW.completed_at := SYSTIMESTAMP;
END;
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE employee_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    FUNCTION log_incident (
        p_dept_id IN NUMBER,
        p_reported_by IN NUMBER,
        p_title IN VARCHAR2,
        p_severity IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    PROCEDURE auto_assign (p_incident_id IN NUMBER);

    PROCEDURE start_task (
        p_assignee_id IN NUMBER,
        p_task_id IN NUMBER
    );

    PROCEDURE complete_task (
        p_assignee_id IN NUMBER,
        p_task_id IN NUMBER
    );

END employee_pkg;
/

create or replace PACKAGE BODY employee_pkg AS

    
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

    FUNCTION log_incident (
        p_dept_id IN NUMBER,
        p_reported_by IN NUMBER,
        p_title IN VARCHAR2,
        p_severity IN VARCHAR2,
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
        v_ops_manager_id departments.manager_id%TYPE;
    BEGIN
        SELECT i.dept_id, d.manager_id
        INTO v_dept_id, v_ops_manager_id
        FROM incidents i
        JOIN departments d
        ON d.dept_id = i.dept_id
        WHERE i.incident_id = p_incident_id;

        IF v_ops_manager_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'the department does not have manager');
        END IF;

        UPDATE incidents
        SET assigned_to = v_ops_manager_id,
            status = 'IN_PROGRESS'
        WHERE incident_id = p_incident_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END auto_assign;

   
    PROCEDURE start_task (
        p_assignee_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_assigned_to tasks.assigned_to%TYPE;
    BEGIN
        SELECT assigned_to
        INTO v_assigned_to
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_assignee_id != v_assigned_to THEN
            RAISE_APPLICATION_ERROR(-20020, 'this task has not been assigned to you so you cannot start it');
        END IF;

        UPDATE tasks
        SET status = 'IN_PROGRESS'
        WHERE task_id = p_task_id;
        COMMIT;
    END start_task;

    
    PROCEDURE complete_task (
        p_assignee_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_assigned_to tasks.assigned_to%TYPE;
    BEGIN
        SELECT assigned_to
        INTO v_assigned_to
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_assignee_id != v_assigned_to THEN
            RAISE_APPLICATION_ERROR(-20020, 'this task has not been assigned to you so you cannot complete it');
        END IF;

        UPDATE tasks
        SET status = 'COMPLETE'
        WHERE task_id = p_task_id;
        COMMIT;
    END complete_task;

END employee_pkg;
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE supervisor_pkg AS

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    );

    PROCEDURE cancel_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    );

END supervisor_pkg;
/

create or replace PACKAGE BODY supervisor_pkg AS


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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted TIMESTAMP;
        v_sla_hours NUMBER;
        v_hours_used NUMBER;
        v_pct NUMBER;
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');

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

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    )
    IS
    BEGIN
        INSERT INTO tasks (assigned_to, created_by, title, priority, due_date)
        VALUES (assigned_to, created_by, title, priority, due_date);
        COMMIT;
    END assign_task;

    PROCEDURE cancel_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_created_by tasks.created_by%TYPE;
    BEGIN
        SELECT created_by
        INTO v_created_by
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_creator_id != v_created_by THEN
            RAISE_APPLICATION_ERROR(-20020, 'this task was not created by you, so you cannot cancel it');
        END IF;

        UPDATE tasks
        SET status = 'CANCELLED'
        WHERE task_id = p_task_id;
        COMMIT;
    END cancel_task;

END supervisor_pkg;
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE employee_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    FUNCTION log_incident (
        p_dept_id IN NUMBER,
        p_reported_by IN NUMBER,
        p_title IN VARCHAR2,
        p_severity IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    PROCEDURE auto_assign (p_incident_id IN NUMBER);

    PROCEDURE complete_task (
        p_assignee_id IN NUMBER,
        p_task_id IN NUMBER
    );

    PROCEDURE reopen_task (
        p_assignee_id IN NUMBER,
        p_task_id IN NUMBER
    );

END employee_pkg;
/

create or replace PACKAGE BODY employee_pkg AS

    
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

    FUNCTION log_incident (
        p_dept_id IN NUMBER,
        p_reported_by IN NUMBER,
        p_title IN VARCHAR2,
        p_severity IN VARCHAR2,
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
        v_ops_manager_id departments.manager_id%TYPE;
    BEGIN
        SELECT i.dept_id, d.manager_id
        INTO v_dept_id, v_ops_manager_id
        FROM incidents i
        JOIN departments d
        ON d.dept_id = i.dept_id
        WHERE i.incident_id = p_incident_id;

        IF v_ops_manager_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'the department does not have manager');
        END IF;

        UPDATE incidents
        SET assigned_to = v_ops_manager_id,
            status = 'IN_PROGRESS'
        WHERE incident_id = p_incident_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END auto_assign;

    
    PROCEDURE complete_task (
        p_assignee_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_assigned_to tasks.assigned_to%TYPE;
        v_current_status tasks.status%TYPE;
    BEGIN
        SELECT assigned_to, status
        INTO v_assigned_to, v_current_status
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_assignee_id != v_assigned_to THEN
            RAISE_APPLICATION_ERROR(-20020, 'this task has not been assigned to you so you cannot complete it');
        END IF;

        IF v_current_status IN ('DONE', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20020, 'the task is already done or cancelled');
        END IF;

        UPDATE tasks
        SET status = 'DONE'
        WHERE task_id = p_task_id;
        COMMIT;
    END complete_task;

    
    PROCEDURE reopen_task (
        p_assignee_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_assigned_to tasks.assigned_to%TYPE;
        v_current_status tasks.status%TYPE;
    BEGIN
        SELECT assigned_to, status
        INTO v_assigned_to, v_current_status
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_assignee_id != v_assigned_to THEN
            RAISE_APPLICATION_ERROR(-20020, 'this task has not been assigned to you so you cannot complete it');
        END IF;

        IF v_current_status = 'CANCELLED' THEN
            RAISE_APPLICATION_ERROR(-20020, 'the task has been cancelled');
        END IF;

        UPDATE tasks
        SET status = 'IN_PROGRESS'
        WHERE task_id = p_task_id;
        COMMIT;
    END reopen_task;

END employee_pkg;
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE supervisor_pkg AS

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    );

    PROCEDURE cancel_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    );

END supervisor_pkg;
/

create or replace PACKAGE BODY supervisor_pkg AS


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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted TIMESTAMP;
        v_sla_hours NUMBER;
        v_hours_used NUMBER;
        v_pct NUMBER;
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');

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

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    )
    IS
    BEGIN
        INSERT INTO tasks (assigned_to, created_by, title, priority, due_date)
        VALUES (assigned_to, created_by, title, priority, due_date);
        COMMIT;
    END assign_task;

    PROCEDURE cancel_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_created_by tasks.created_by%TYPE;
        v_status tasks.status%TYPE;
    BEGIN
        SELECT created_by, status
        INTO v_created_by, v_status
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_creator_id != v_created_by THEN
            RAISE_APPLICATION_ERROR(-20020, 'this task was not created by you, so you cannot cancel it');
        END IF;

        IF v_status = 'DONE' THEN
            RAISE_APPLICATION_ERROR(-20020, 'the task has already been completed');
        END IF;

        UPDATE tasks
        SET status = 'CANCELLED'
        WHERE task_id = p_task_id;
        COMMIT;
    END cancel_task;

END supervisor_pkg;
/
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
DROP CONSTRAINT check_task_status;
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
ADD CONSTRAINT check_task_status CHECK (status IN ('IN_PROGRESS','DONE','CANCELLED'));
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
MODIFY status VARCHAR2(20) DEFAULT 'IN_PROGRESS' NULL;
-----------------------------------------------------------------------------------------------------------------
ALTER TABLE tasks
MODIFY status VARCHAR2(20) DEFAULT 'IN_PROGRESS' NOT NULL;
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_task_complete_or_reopen
BEFORE UPDATE ON tasks
FOR EACH ROW
BEGIN
    IF :NEW.status = 'DONE' AND :OLD.completed_at = NULL THEN
        :NEW.completed_at := SYSTIMESTAMP;
    ELSIF :NEW.status = 'IN_PROGRESS' THEN
        :NEW.completed_at := NULL;
    END IF;
END;
/
-----------------------------------------------------------------------------------------------------------------
DROP TRIGGER trg_task_complete;
COMMIT;
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE employee_pkg AS

    -- Submits a new request and returns the id of the created request
    FUNCTION submit_request (
        p_emp_id IN NUMBER,
        p_workflow_id IN NUMBER,
        p_notes IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    FUNCTION log_incident (
        p_dept_id IN NUMBER,
        p_reported_by IN NUMBER,
        p_title IN VARCHAR2,
        p_severity IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    PROCEDURE auto_assign (p_incident_id IN NUMBER);

    PROCEDURE complete_task (
        p_assignee_id IN NUMBER,
        p_task_id IN NUMBER
    );

END employee_pkg;
/

create or replace PACKAGE BODY employee_pkg AS

    
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

    FUNCTION log_incident (
        p_dept_id IN NUMBER,
        p_reported_by IN NUMBER,
        p_title IN VARCHAR2,
        p_severity IN VARCHAR2,
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
        v_ops_manager_id departments.manager_id%TYPE;
    BEGIN
        SELECT i.dept_id, d.manager_id
        INTO v_dept_id, v_ops_manager_id
        FROM incidents i
        JOIN departments d
        ON d.dept_id = i.dept_id
        WHERE i.incident_id = p_incident_id;

        IF v_ops_manager_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'the department does not have manager');
        END IF;

        UPDATE incidents
        SET assigned_to = v_ops_manager_id,
            status = 'IN_PROGRESS'
        WHERE incident_id = p_incident_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END auto_assign;

    
    PROCEDURE complete_task (
        p_assignee_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_assigned_to tasks.assigned_to%TYPE;
        v_current_status tasks.status%TYPE;
    BEGIN
        SELECT assigned_to, status
        INTO v_assigned_to, v_current_status
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_assignee_id != v_assigned_to THEN
            RAISE_APPLICATION_ERROR(-20020, 'this task has not been assigned to you so you cannot complete it');
        END IF;

        IF v_current_status IN ('DONE', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20020, 'the task is already done or cancelled');
        END IF;

        UPDATE tasks
        SET status = 'DONE'
        WHERE task_id = p_task_id;
        COMMIT;
    END complete_task;

END employee_pkg;
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE supervisor_pkg AS

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    );

    PROCEDURE reopen_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    );

    PROCEDURE cancel_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    );

END supervisor_pkg;
/

create or replace PACKAGE BODY supervisor_pkg AS


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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted TIMESTAMP;
        v_sla_hours NUMBER;
        v_hours_used NUMBER;
        v_pct NUMBER;
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');

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

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    )
    IS
    BEGIN
        INSERT INTO tasks (assigned_to, created_by, title, priority, due_date)
        VALUES (assigned_to, created_by, title, priority, due_date);
        COMMIT;
    END assign_task;

    PROCEDURE reopen_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_created_by tasks.created_by%TYPE;
        v_current_status tasks.status%TYPE;
    BEGIN
        SELECT created_by, status
        INTO v_created_by, v_current_status
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_creator_id != v_created_by THEN
            RAISE_APPLICATION_ERROR(-20020, 'you did not create this task so you so you cannot reopen it');
        END IF;

        IF v_current_status = 'CANCELLED' THEN
            RAISE_APPLICATION_ERROR(-20020, 'the task has been cancelled');
        END IF;

        UPDATE tasks
        SET status = 'IN_PROGRESS'
        WHERE task_id = p_task_id;
        COMMIT;
    END reopen_task;

    PROCEDURE cancel_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_created_by tasks.created_by%TYPE;
        v_status tasks.status%TYPE;
    BEGIN
        SELECT created_by, status
        INTO v_created_by, v_status
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_creator_id != v_created_by THEN
            RAISE_APPLICATION_ERROR(-20020, 'this task was not created by you, so you cannot cancel it');
        END IF;

        IF v_status = 'DONE' THEN
            RAISE_APPLICATION_ERROR(-20020, 'the task has already been completed');
        END IF;

        UPDATE tasks
        SET status = 'CANCELLED'
        WHERE task_id = p_task_id;
        COMMIT;
    END cancel_task;

END supervisor_pkg;
/
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_task_complete_or_reopen
BEFORE UPDATE ON tasks
FOR EACH ROW
BEGIN
    IF :NEW.status = 'DONE' AND :OLD.completed_at IS NULL THEN
        :NEW.completed_at := SYSTIMESTAMP;
    ELSIF :NEW.status = 'IN_PROGRESS' THEN
        :NEW.completed_at := NULL;
    END IF;
END;
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE supervisor_pkg AS

    -- Adds an approval or rejection decision to the decisions table and advances or closes the request based on the decision
    PROCEDURE decide_stage (
        p_request_id IN NUMBER,
        p_decider_id IN NUMBER,
        p_decision IN VARCHAR2,
        p_comments IN VARCHAR2 DEFAULT NULL
    );

    -- based on the workflow's sla_hours, requests are evaluated as ON_TRACK, AT_RISK, or BREACHED
    FUNCTION get_sla_status (
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    );

    PROCEDURE reopen_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    );

    PROCEDURE cancel_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    );

END supervisor_pkg;
/

create or replace PACKAGE BODY supervisor_pkg AS


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
        v_current_dept_id departments.dept_id%TYPE;
        v_decider_dept_id departments.dept_id%TYPE;
    BEGIN
        SELECT workflow_id, current_stage, status
        INTO v_workflow_id, v_current_stage, v_old_status
        FROM requests
        WHERE request_id = p_request_id
        FOR UPDATE;

        IF v_old_status IN ('REJECTED', 'COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Request ' || p_request_id || ' is already ' || v_old_status);
        END IF;

        SELECT ws.required_level, r.role_level, ws.dept_id, e.dept_id
        INTO v_required_level, v_decider_level, v_current_dept_id, v_decider_dept_id
        FROM workflow_stages ws
        JOIN employees e ON e.emp_id = p_decider_id
        JOIN roles r ON r.role_id = e.role_id
        WHERE ws.stage_id = v_current_stage;

        IF v_decider_level < v_required_level THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Decider role level ' || v_decider_level ||
                ' insufficient for stage requiring level ' || v_required_level);
        END IF;

        IF v_current_dept_id != v_decider_dept_id THEN
            RAISE_APPLICATION_ERROR(-20005,
                'The decider is not part of nor responsible for department id ' || v_current_dept_id || ' and therefore is not authorized to make a decision on this stage of the request');
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
                SET status = v_new_status
                WHERE request_id = p_request_id;
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
            SET status = v_new_status
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

    ------------------------------------------------------------------------------ get_sla_status
    FUNCTION get_sla_status (p_request_id IN NUMBER) RETURN VARCHAR2 AS
        v_submitted TIMESTAMP;
        v_sla_hours NUMBER;
        v_hours_used NUMBER;
        v_pct NUMBER;
        v_request_status requests.status%TYPE;
    BEGIN
        SELECT r.submitted_at, w.sla_hours, r.status
        INTO v_submitted, v_sla_hours, v_request_status
        FROM requests  r
        JOIN workflows w 
        ON w.workflow_id = r.workflow_id
        WHERE r.request_id = p_request_id;

        IF v_request_status IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN
            RETURN 'RESOLVED';
        END IF;

        v_hours_used := (CAST(SYSTIMESTAMP AS DATE) - CAST(v_submitted AS DATE)) * 24;

        DBMS_OUTPUT.PUT_LINE('time given to complete request: ' || v_sla_hours || ' hours');
        DBMS_OUTPUT.PUT_LINE('time passed: ' || v_hours_used || ' hours');

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

    PROCEDURE assign_task(
        created_by NUMBER,
        assigned_to NUMBER,
        title VARCHAR2,
        priority VARCHAR2,
        due_date DATE
    )
    IS
    BEGIN
        INSERT INTO tasks (assigned_to, created_by, title, priority, due_date)
        VALUES (assigned_to, created_by, title, priority, due_date);
        COMMIT;
    END assign_task;

    PROCEDURE reopen_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_created_by tasks.created_by%TYPE;
        v_current_status tasks.status%TYPE;
    BEGIN
        SELECT created_by, status
        INTO v_created_by, v_current_status
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_creator_id != v_created_by THEN
            RAISE_APPLICATION_ERROR(-20020, 'you did not create this task, so you cannot reopen it');
        END IF;

        IF v_current_status = 'CANCELLED' THEN
            RAISE_APPLICATION_ERROR(-20020, 'the task has been cancelled');
        END IF;

        UPDATE tasks
        SET status = 'IN_PROGRESS'
        WHERE task_id = p_task_id;
        COMMIT;
    END reopen_task;

    PROCEDURE cancel_task (
        p_creator_id IN NUMBER,
        p_task_id IN NUMBER
    )
    AS
        v_created_by tasks.created_by%TYPE;
        v_status tasks.status%TYPE;
    BEGIN
        SELECT created_by, status
        INTO v_created_by, v_status
        FROM tasks
        WHERE task_id = p_task_id;

        IF p_creator_id != v_created_by THEN
            RAISE_APPLICATION_ERROR(-20020, 'this task was not created by you, so you cannot cancel it');
        END IF;

        IF v_status = 'DONE' THEN
            RAISE_APPLICATION_ERROR(-20020, 'the task has already been completed');
        END IF;

        UPDATE tasks
        SET status = 'CANCELLED'
        WHERE task_id = p_task_id;
        COMMIT;
    END cancel_task;

END supervisor_pkg;
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE ops_manager_pkg AS

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution IN VARCHAR2
    );

    PROCEDURE department_spend(
        p_dept_id NUMBER,
        p_amount_spent NUMBER
    );

END ops_manager_pkg;
/

create or replace PACKAGE BODY ops_manager_pkg AS

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution  IN VARCHAR2
    ) AS
        v_reported_at incidents.reported_at%TYPE;
        v_old_status incidents.status%TYPE;
        v_minutes NUMBER;
        v_assigned_to incidents.assigned_to%TYPE;
    BEGIN
        SELECT reported_at, status, assigned_to
        INTO v_reported_at, v_old_status, v_assigned_to
        FROM incidents
        WHERE incident_id = p_incident_id
        FOR UPDATE;

        IF v_assigned_to != p_resolved_by THEN
            RAISE_APPLICATION_ERROR(-20010,'you were not assigned this incident and therefore cannot resolve it');
        END IF;

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
            description = description || CHR(10) || 'RESOLUTION: ' || p_resolution
        WHERE incident_id = p_incident_id;

        log_audit('INCIDENTS', p_incident_id, 'UPDATE', p_resolved_by,
                  'status=' || v_old_status,
                  'status=RESOLVED, resolution_min=' || v_minutes);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END resolve_incident;

    PROCEDURE department_spend(
        p_dept_id NUMBER,
        p_amount_spent NUMBER
    )
    AS
    BEGIN
        UPDATE budgets
        SET spent = NVL(spent, 0) + p_amount_spent
        WHERE dept_id = p_dept_id;

        IF SQL%NOTFOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Department ID ' || p_dept_id || ' not found.');
        END IF;

        COMMIT;
    END department_spend;

END ops_manager_pkg;
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE ops_manager_pkg AS

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution IN VARCHAR2
    );

    PROCEDURE department_spend(
        p_dept_id NUMBER,
        p_user_id NUMBER,
        p_amount_spent NUMBER
    );

END ops_manager_pkg;
/

create or replace PACKAGE BODY ops_manager_pkg AS

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution  IN VARCHAR2
    ) AS
        v_reported_at incidents.reported_at%TYPE;
        v_old_status incidents.status%TYPE;
        v_minutes NUMBER;
        v_assigned_to incidents.assigned_to%TYPE;
    BEGIN
        SELECT reported_at, status, assigned_to
        INTO v_reported_at, v_old_status, v_assigned_to
        FROM incidents
        WHERE incident_id = p_incident_id
        FOR UPDATE;

        IF v_assigned_to != p_resolved_by THEN
            RAISE_APPLICATION_ERROR(-20010,'you were not assigned this incident and therefore cannot resolve it');
        END IF;

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
            description = description || CHR(10) || 'RESOLUTION: ' || p_resolution
        WHERE incident_id = p_incident_id;

        log_audit('INCIDENTS', p_incident_id, 'UPDATE', p_resolved_by,
                  'status=' || v_old_status,
                  'status=RESOLVED, resolution_min=' || v_minutes);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END resolve_incident;

    PROCEDURE department_spend(
        p_dept_id NUMBER,
        p_user_id NUMBER,
        p_amount_spent NUMBER
    )
    AS
        v_user_dept_id employees.dept_id%TYPE;
    BEGIN
        SELECT dept_id
        INTO v_user_dept_id
        FROM employees
        WHERE emp_id = p_user_id;

        IF v_user_dept_id != p_dept_id THEN
            RAISE_APPLICATION_ERROR(-20001, 'You can only spend funds on behalf of your own department');
        END IF;
        
        UPDATE budgets
        SET spent = NVL(spent, 0) + p_amount_spent
        WHERE dept_id = p_dept_id;

        IF SQL%NOTFOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Department ID ' || p_dept_id || ' not found.');
        END IF;

        COMMIT;
    END department_spend;

END ops_manager_pkg;
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE ops_manager_pkg AS

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution IN VARCHAR2
    );

    PROCEDURE department_spend(
        p_dept_id NUMBER,
        p_user_id NUMBER,
        p_amount_spent NUMBER
    );

END ops_manager_pkg;
/

create or replace PACKAGE BODY ops_manager_pkg AS

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution  IN VARCHAR2
    ) AS
        v_reported_at incidents.reported_at%TYPE;
        v_old_status incidents.status%TYPE;
        v_minutes NUMBER;
        v_assigned_to incidents.assigned_to%TYPE;
    BEGIN
        SELECT reported_at, status, assigned_to
        INTO v_reported_at, v_old_status, v_assigned_to
        FROM incidents
        WHERE incident_id = p_incident_id
        FOR UPDATE;

        IF v_assigned_to != p_resolved_by THEN
            RAISE_APPLICATION_ERROR(-20010,'you were not assigned this incident and therefore cannot resolve it');
        END IF;

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
            description = description || CHR(10) || 'RESOLUTION: ' || p_resolution
        WHERE incident_id = p_incident_id;

        log_audit('INCIDENTS', p_incident_id, 'UPDATE', p_resolved_by,
                  'status=' || v_old_status,
                  'status=RESOLVED, resolution_min=' || v_minutes);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END resolve_incident;

    PROCEDURE department_spend(
        p_dept_id NUMBER,
        p_user_id NUMBER,
        p_amount_spent NUMBER
    )
    AS
        v_user_dept_id employees.dept_id%TYPE;
    BEGIN
        SELECT dept_id
        INTO v_user_dept_id
        FROM employees
        WHERE emp_id = p_user_id
        AND role_id = 3
        AND is_active = 1;

        IF v_user_dept_id != p_dept_id THEN
            RAISE_APPLICATION_ERROR(-20001, 'You can only spend funds on behalf of your own department');
        END IF;
        
        UPDATE budgets
        SET spent = NVL(spent, 0) + p_amount_spent
        WHERE dept_id = p_dept_id;

        IF SQL%NOTFOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Department ID ' || p_dept_id || ' not found.');
        END IF;

        COMMIT;
    END department_spend;

END ops_manager_pkg;
/
-----------------------------------------------------------------------------------------------------------------
create or replace PACKAGE ops_manager_pkg AS

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution IN VARCHAR2
    );

    PROCEDURE department_spend(
        p_dept_id NUMBER,
        p_user_id NUMBER,
        p_amount_spent NUMBER
    );

END ops_manager_pkg;
/

create or replace PACKAGE BODY ops_manager_pkg AS

    PROCEDURE resolve_incident (
        p_incident_id IN NUMBER,
        p_resolved_by IN NUMBER,
        p_resolution  IN VARCHAR2
    ) AS
        v_reported_at incidents.reported_at%TYPE;
        v_old_status incidents.status%TYPE;
        v_minutes NUMBER;
        v_assigned_to incidents.assigned_to%TYPE;
    BEGIN
        SELECT reported_at, status, assigned_to
        INTO v_reported_at, v_old_status, v_assigned_to
        FROM incidents
        WHERE incident_id = p_incident_id
        FOR UPDATE;

        IF v_assigned_to != p_resolved_by THEN
            RAISE_APPLICATION_ERROR(-20010,'you were not assigned this incident and therefore cannot resolve it');
        END IF;

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
            description = description || CHR(10) || 'RESOLUTION: ' || p_resolution
        WHERE incident_id = p_incident_id;

        log_audit('INCIDENTS', p_incident_id, 'UPDATE', p_resolved_by,
                  'status=' || v_old_status,
                  'status=RESOLVED, resolution_min=' || v_minutes);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END resolve_incident;

    PROCEDURE department_spend(
        p_dept_id NUMBER,
        p_user_id NUMBER,
        p_amount_spent NUMBER
    )
    AS
        v_user_dept_id employees.dept_id%TYPE;
    BEGIN
        SELECT dept_id
        INTO v_user_dept_id
        FROM employees
        WHERE emp_id = p_user_id
        AND role_id = 3
        AND is_active = 1;

        IF v_user_dept_id != p_dept_id THEN
            RAISE_APPLICATION_ERROR(-20001, 'You can only spend funds on behalf of your own department');
        END IF;
        
        UPDATE budgets
        SET spent = NVL(spent, 0) + p_amount_spent
        WHERE dept_id = p_dept_id;

        IF SQL%NOTFOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Department ID ' || p_dept_id || ' not found.');
        END IF;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'you are not an active ops manager');
    END department_spend;

END ops_manager_pkg;
/
-----------------------------------------------------------------------------------------------------------------
