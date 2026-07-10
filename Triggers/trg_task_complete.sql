CREATE OR REPLACE TRIGGER trg_task_complete
BEFORE UPDATE ON tasks
FOR EACH ROW
WHEN (NEW.status = 'DONE' AND OLD.completed_at IS NULL)
BEGIN
    :NEW.completed_at := SYSTIMESTAMP;
END;