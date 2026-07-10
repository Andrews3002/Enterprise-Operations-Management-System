CREATE OR REPLACE TRIGGER trg_assign_tasks_to_subordinates_only
BEFORE INSERT ON tasks
FOR EACH ROW
DECLARE
    v_creator_level NUMBER;
    v_assignee_level NUMBER;
BEGIN
    SELECT r.role_level
    INTO v_creator_level
    FROM employees e
    JOIN roles r ON r.role_id = e.role_id
    WHERE e.emp_id = :NEW.created_by;

    SELECT r.role_level
    INTO v_assignee_level
    FROM employees e
    JOIN roles r ON r.role_id = e.role_id
    WHERE emp_id = :NEW.assigned_to; 

    IF v_creator_level <= v_assignee_level THEN
        RAISE_APPLICATION_ERROR(-20020, 'cannot assign tasks to users with a higher role level than you');
    END IF;
END;
/