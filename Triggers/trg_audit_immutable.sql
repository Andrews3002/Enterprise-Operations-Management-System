CREATE OR REPLACE TRIGGER trg_audit_immutable
BEFORE UPDATE OR DELETE ON audit_logs
BEGIN
    RAISE_APPLICATION_ERROR(-20020,
        'audit_logs is immutable. Updates and deletes are not permitted.');
END;
/