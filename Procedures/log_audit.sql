CREATE OR REPLACE PROCEDURE log_audit (
    p_table_name IN VARCHAR2,
    p_record_id IN NUMBER,
    p_action IN VARCHAR2,
    p_changed_by IN NUMBER,
    p_old_value IN VARCHAR2 DEFAULT NULL,
    p_new_value IN VARCHAR2 DEFAULT NULL
) AS
BEGIN
    INSERT INTO audit_logs (
        table_name, record_id, action,
        changed_by, old_value, new_value, changed_at
    ) VALUES (
        p_table_name, p_record_id, p_action,
        p_changed_by, p_old_value, p_new_value, SYSTIMESTAMP
    );
    COMMIT;
END log_audit;