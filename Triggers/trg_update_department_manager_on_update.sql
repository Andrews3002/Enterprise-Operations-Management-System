CREATE OR REPLACE TRIGGER trg_update_department_manager_on_update
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
    IF :NEW.role_id = 3 AND :NEW.is_active = 0 THEN
        UPDATE departments
        SET manager_id = null
        WHERE dept_id = :NEW.dept_id;
    ELSIF :OLD.role_id = 3 AND :NEW.role_id != 3 THEN
        UPDATE departments
        SET manager_id = NULL
        WHERE dept_id = :OLD.dept_id;
    ELSIF :OLD.role_id != 3 AND :NEW.role_id = 3 THEN
        UPDATE departments
        SET manager_id = :NEW.emp_id
        WHERE dept_id = :NEW.dept_id;
    END IF;
END;
/