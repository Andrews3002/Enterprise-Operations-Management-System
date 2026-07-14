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
        v_role_id roles.role_id%TYPE;
    BEGIN
        
        SELECT role_id
        INTO v_role_id
        FROM employees
        WHERE emp_id = created_by;

        IF v_role_id IN (4, 1) THEN
            RAISE_APPLICATION_ERROR(-20020, 'Only managers and supervisors can assign tasks');
        END IF;

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