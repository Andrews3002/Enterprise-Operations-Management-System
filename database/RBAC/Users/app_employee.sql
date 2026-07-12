CREATE USER app_employee IDENTIFIED BY "Emp2026#Secure";

GRANT CREATE SESSION TO app_employee;

GRANT role_employee TO app_employee;