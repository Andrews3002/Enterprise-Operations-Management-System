CREATE OR REPLACE TRIGGER trg_update_department_manager_on_change_in_role
AFTER UPDATE ON employees
FOR EACH ROW
WHEN (OLD.role_id = 3 AND NEW.role_id != 3)
BEGIN
    UPDATE departments
    SET manager_id = NULL
    WHERE dept_id = :OLD.dept_id;
END;
/