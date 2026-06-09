CREATE INDEX idx_audit_table_record   ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_changed_at     ON audit_logs(changed_at);