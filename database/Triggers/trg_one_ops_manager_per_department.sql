CREATE OR REPLACE TRIGGER trg_one_ops_manager_per_department
FOR INSERT OR UPDATE ON "ADMIN"."EMPLOYEES"
COMPOUND TRIGGER

    TYPE t_dept_ids IS TABLE OF "ADMIN"."EMPLOYEES".dept_id%TYPE;
    v_depts t_dept_ids := t_dept_ids();

    BEFORE EACH ROW IS
    BEGIN
        IF :NEW.is_active = 1 AND :NEW.role_id = 3 THEN
            v_depts.EXTEND;
            v_depts(v_depts.LAST) := :NEW.dept_id;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
        v_count NUMBER;
    BEGIN
        IF v_depts.COUNT > 0 THEN
            FOR i IN 1..v_depts.COUNT LOOP
                SELECT COUNT(*)
                INTO v_count
                FROM "ADMIN"."EMPLOYEES"
                WHERE dept_id = v_depts(i)
                AND is_active = 1
                AND role_id = 3;

                IF v_count > 1 THEN 
                    RAISE_APPLICATION_ERROR(-20001, 'Validation Error: This department already has an active Operations Manager.');
                END IF;
            END LOOP;
        END IF;
    END AFTER STATEMENT;
END;
/