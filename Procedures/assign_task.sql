CREATE OR REPLACE PROCEDURE assign_task(
    created_by NUMBER,
    assigned_to NUMBER,
    title VARCHAR2,
    priority VARCHAR2,
    due_date DATE
)
IS
BEGIN
    INSERT INTO tasks (assigned_to, created_by, title, priority, due_date)
    VALUES (assigned_to, created_by, title, priority, due_date);
END;
/