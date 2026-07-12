CREATE ROLE role_ops_manager;

GRANT EXECUTE ON employee_pkg TO role_ops_manager;
GRANT EXECUTE ON supervisor_pkg TO role_ops_manager;
GRANT EXECUTE ON ops_manager_pkg TO role_ops_manager;
GRANT SELECT ON mv_dept_dashboard TO role_ops_manager;