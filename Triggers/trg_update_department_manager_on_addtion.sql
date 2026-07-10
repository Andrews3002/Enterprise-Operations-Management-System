CREATE OR REPLACE TRIGGER trg_update_department_manager_on_addtion
AFTER INSERT OR UPDATE ON employees
FOR EACH ROW
WHEN (NEW.role_id = 3)
BEGIN
    UPDATE departments
    SET manager_id = :NEW.emp_id
    WHERE dept_id = :NEW.dept_id;
END;
/