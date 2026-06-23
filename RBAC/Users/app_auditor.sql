CREATE USER app_auditor IDENTIFIED BY "Aud2026#Secure";

GRANT CREATE SESSION TO app_auditor;

GRANT role_auditor TO app_auditor;