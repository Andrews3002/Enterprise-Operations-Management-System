CREATE TABLE audit_log (
    audit_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name   VARCHAR2(50)  NOT NULL,
    record_id    NUMBER        NOT NULL,
    action       VARCHAR2(10)  NOT NULL,
    changed_by   NUMBER,
    old_value    VARCHAR2(4000),
    new_value    VARCHAR2(4000),
    changed_at   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT check_audit_action CHECK (action IN ('INSERT','UPDATE','DELETE'))
);

ALTER TABLE audit_log
RENAME TO audit_logs