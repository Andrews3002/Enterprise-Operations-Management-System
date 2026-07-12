CREATE USER app_ops_manager IDENTIFIED BY "Mgr2026#Secure";

GRANT CREATE SESSION TO app_ops_manager;

GRANT role_ops_manager TO app_ops_manager;