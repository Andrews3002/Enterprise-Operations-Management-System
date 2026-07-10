CREATE OR REPLACE TRIGGER trg_task_complete_or_reopen
BEFORE UPDATE ON tasks
FOR EACH ROW
BEGIN
    IF :NEW.status = 'DONE' AND :OLD.completed_at IS NULL THEN
        :NEW.completed_at := SYSTIMESTAMP;
    ELSIF :NEW.status = 'IN_PROGRESS' THEN
        :NEW.completed_at := NULL;
    END IF;
END;
/