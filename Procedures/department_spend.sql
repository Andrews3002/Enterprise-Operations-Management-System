create or replace PROCEDURE department_spend(
    p_dept_id NUMBER,
    p_amount_spent NUMBER
)
AS
BEGIN
    UPDATE budgets
    SET spent = NVL(spent, 0) + p_amount_spent
    WHERE dept_id = p_dept_id;

    IF SQL%NOTFOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Department ID ' || p_dept_id || ' not found.');
    END IF;

    COMMIT;
END;