CREATE OR REPLACE TRIGGER trg_one_ops_manager_per_department
BEFORE INSERT OR UPDATE ON "ADMIN"."EMPLOYEES"
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    IF :NEW.is_active = 1 AND :NEW.role_id = 23 THEN
        
        SELECT COUNT(*)
        INTO v_count
        FROM "ADMIN"."EMPLOYEES"
        WHERE dept_id = :NEW.dept_id
        AND is_active = 1
        AND role_id = 23
        AND emp_id != NVL(:NEW.emp_id, -1);

        IF v_count > 0 THEN 
            RAISE_APPLICATION_ERROR(-20001, 'Validation Error: This department already has an active Operations Manager.');
        END IF;
        
    END IF;
END;
/