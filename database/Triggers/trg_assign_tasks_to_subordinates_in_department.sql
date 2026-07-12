CREATE OR REPLACE TRIGGER trg_assign_tasks_to_subordinates_in_department
BEFORE INSERT OR UPDATE ON "ADMIN"."TASKS"
FOR EACH ROW
DECLARE
    v_creator_department departments.dept_id%TYPE;
    v_assignee_department departments.dept_id%TYPE;
    v_creator_role_level roles.role_level%TYPE;
    v_assignee_role_level roles.role_level%TYPE;
BEGIN  
    IF :NEW.created_by IS NULL THEN
        RAISE_APPLICATION_ERROR(-20003, 'You cannot assign a task without specifying who created it');
    ELSIF :NEW.assigned_to IS NULL THEN
        RAISE_APPLICATION_ERROR(-20004, 'You must specify who you are assigning the task to');
    END IF;

    SELECT e.dept_id, r.role_level
    INTO v_creator_department, v_creator_role_level
    FROM employees e
    JOIN roles r 
    ON r.role_id = e.role_id
    WHERE e.emp_id = :NEW.created_by;

    SELECT e.dept_id, r.role_level
    INTO v_assignee_department, v_assignee_role_level
    FROM employees e
    JOIN roles r 
    ON r.role_id = e.role_id
    WHERE e.emp_id = :NEW.assigned_to;

    IF v_creator_department != v_assignee_department THEN
        RAISE_APPLICATION_ERROR(-20001, 'Tasks cannot be assigned to users outside your department');
    END IF;

    IF v_creator_role_level <= v_assignee_role_level THEN
        RAISE_APPLICATION_ERROR(-20002, 'Tasks can only be assigned to users with a lower role level than yourself');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20005, 'Either the user you tried to assign the task to does not exist or the specified creator of the task does not exists');
END;