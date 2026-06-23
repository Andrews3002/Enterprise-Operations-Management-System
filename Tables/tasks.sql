CREATE TABLE tasks (
    task_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    assigned_to NUMBER NOT NULL,
    created_by NUMBER NOT NULL,
    title VARCHAR2(200) NOT NULL,
    priority VARCHAR2(10) DEFAULT 'MEDIUM' NOT NULL,
    status VARCHAR2(20) DEFAULT 'OPEN' NOT NULL,
    due_date DATE,
    completed_at TIMESTAMP,
    CONSTRAINT fk_task_assignee FOREIGN KEY (assigned_to) REFERENCES employees(emp_id),
    CONSTRAINT fk_task_creator FOREIGN KEY (created_by) REFERENCES employees(emp_id),
    CONSTRAINT check_task_priority CHECK (priority IN ('HIGH','MEDIUM','LOW')),
    CONSTRAINT check_task_status CHECK (status IN ('OPEN','IN_PROGRESS','DONE','CANCELLED'))
);