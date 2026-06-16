CREATE TABLE workflows (
    workflow_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workflow_name VARCHAR2(100) NOT NULL UNIQUE,
    description   VARCHAR2(500),
    sla_hours     NUMBER(5)    NOT NULL,
    is_active     NUMBER(1)    DEFAULT 1 NOT NULL,
    CONSTRAINT check_workflow_active CHECK (is_active IN (0,1))
);

ALTER TABLE workflows
ADD department_id NUMBER;

ALTER TABLE workflows
RENAME COLUMN department_id TO dept_id;

ALTER TABLE workflows
ADD CONSTRAINT fk_workflow_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id);

ALTER TABLE workflows
MODIFY dept_id NUMBER NOT NULL;