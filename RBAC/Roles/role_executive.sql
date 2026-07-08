CREATE ROLE role_executive;

GRANT EXECUTE ON employee_pkg TO role_executive;
GRANT EXECUTE ON supervisor_pkg TO role_executive;
GRANT EXECUTE ON executive_pkg TO role_executive;
GRANT SELECT ON mv_dept_dashboard TO role_executive;