CREATE OR REPLACE TRIGGER trg_incident_resolve
BEFORE UPDATE ON incidents
FOR EACH ROW
WHEN (NEW.status = 'RESOLVED' AND OLD.status != 'RESOLVED')
BEGIN
    :NEW.resolved_at := SYSTIMESTAMP;
    :NEW.resolution_min := ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(:OLD.reported_at AS DATE)) * 24 * 60);
END;
/