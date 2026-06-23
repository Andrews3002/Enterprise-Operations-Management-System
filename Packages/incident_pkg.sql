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