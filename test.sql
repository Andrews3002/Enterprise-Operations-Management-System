SET SERVEROUTPUT ON;

-- 1. Submit a leave request from employee 1 on workflow 1
DECLARE
    v_id NUMBER;
BEGIN
    v_id := workflow_pkg.submit_request(
        p_emp_id => 22,
        p_workflow_id => 21,
        p_notes => 'Annual leave, 5 days from July 1'
    );
    DBMS_OUTPUT.PUT_LINE('Created request_id: ' || v_id);
END;
/

-- 2. Check SLA status
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        workflow_pkg.get_sla_status(1)
    );
END;
/

-- 3. Approve the first stage (need an employee with role_level >= 2)
BEGIN
    workflow_pkg.decide_stage(
        p_request_id => 1,
        p_decider_id => 2,
        p_decision => 'APPROVED',
        p_comments => 'Approved, coverage arranged.'
    );
END;
/

-- 4. Log an incident
DECLARE
    v_id NUMBER;
BEGIN
    v_id := incident_pkg.log_incident(
        p_dept_id => 2,
        p_reported_by => 3,
        p_title => 'Email server unresponsive',
        p_severity => 'HIGH'
    );
    DBMS_OUTPUT.PUT_LINE('Created incident_id: ' || v_id);
END;
/

-- 5. Take a KPI snapshot and verify
BEGIN
    reporting_pkg.take_kpi_snapshot;
END;
/
SELECT * FROM kpi_logs;

-- 6. Run escalation batch (nothing to escalate yet, but should run cleanly)
BEGIN
    workflow_pkg.escalate_overdue;
END;
/

-- 7. Confirm audit trail captured everything
SELECT table_name, action, old_value, new_value, changed_at
FROM audit_logs
ORDER BY changed_at;