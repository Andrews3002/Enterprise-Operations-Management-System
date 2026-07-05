CREATE ROLE role_executive;

GRANT EXECUTE ON reporting_pkg TO role_executive;
GRANT EXECUTE ON incident_pkg TO role_executive;
GRANT SELECT ON mv_dept_dashboard TO role_executive;