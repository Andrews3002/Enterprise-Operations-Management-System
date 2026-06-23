CREATE USER app_supervisor IDENTIFIED BY "Sup2026#Secure";

GRANT CREATE SESSION TO app_supervisor;

GRANT role_supervisor TO app_supervisor;