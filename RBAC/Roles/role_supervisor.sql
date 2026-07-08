CREATE ROLE role_supervisor;

GRANT EXECUTE ON employee_pkg TO role_supervisor;
GRANT EXECUTE ON supervisor_pkg TO role_supervisor;