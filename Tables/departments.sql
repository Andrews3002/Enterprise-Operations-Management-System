CREATE TABLE departments (
    dept_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR2(100) NOT NULL,
    manager_id NUMBER,
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT fk_dept_manager FOREIGN KEY (manager_id) REFERENCES employees(emp_id)
);