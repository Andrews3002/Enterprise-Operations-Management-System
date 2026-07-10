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