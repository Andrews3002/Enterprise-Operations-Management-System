CREATE ROLE role_ops_manager;

GRANT EXECUTE ON workflow_pkg TO role_ops_manager;
GRANT EXECUTE ON incident_pkg TO role_ops_manager;
GRANT EXECUTE ON reporting_pkg TO role_ops_manager;
GRANT EXECUTE ON department_spend TO role_ops_manager;
GRANT EXECUTE ON assign_task TO role_ops_manager;