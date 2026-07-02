DELETE FROM audit_logs
WHERE audit_id != 0;

DELETE FROM decisions
WHERE decision_id != 0;

DELETE FROM tasks
WHERE task_id != 0;

DELETE FROM incidents
WHERE incident_id != 0;

DELETE FROM budgets
WHERE budget_id != 0;

DELETE FROM kpi_logs
WHERE kpi_id != 0;

DELETE FROM requests
WHERE request_id != 0;

DELETE FROM workflows
WHERE workflow_id != 0;

DELETE FROM workflow_stages
WHERE stage_id != 0;

UPDATE departments
SET manager = NULL
WHERE dept_id != 0;

DELETE FROM employees
WHERE emp_id != 0;

DELETE FROM departments
WHERE dept_id != 0;

DELETE FROM roles
WHERE role_id != 0;

COMMIT;