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