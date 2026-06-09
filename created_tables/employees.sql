CREATE TABLE employees (
    emp_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name   VARCHAR2(50)  NOT NULL,
    last_name    VARCHAR2(50)  NOT NULL,
    email        VARCHAR2(150) NOT NULL UNIQUE,
    dept_id      NUMBER        NOT NULL,
    role_id      NUMBER        NOT NULL,
    hire_date    DATE          DEFAULT SYSDATE NOT NULL,
    is_active    NUMBER(1)     DEFAULT 1 NOT NULL,
    CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id),
    CONSTRAINT fk_emp_role FOREIGN KEY (role_id) REFERENCES roles(role_id),
    CONSTRAINT check_employee_active CHECK (is_active IN (0,1))
);