CREATE INDEX idx_incidents_dept ON incidents(dept_id);
CREATE INDEX idx_incidents_severity ON incidents(severity);
CREATE INDEX idx_incidents_status ON incidents(status);
CREATE INDEX idx_incidents_reported ON incidents(reported_at);
CREATE INDEX idx_incidents_sla ON incidents(status, reported_at);