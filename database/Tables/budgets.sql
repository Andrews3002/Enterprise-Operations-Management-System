CREATE TABLE budgets (
    budget_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_id NUMBER NOT NULL,
    fiscal_year NUMBER(4) NOT NULL,
    allocated NUMBER(12,2) NOT NULL,
    spent NUMBER(12,2) DEFAULT 0 NOT NULL,
    CONSTRAINT fk_budget_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE CASCADE,
    CONSTRAINT uq_budget_dept_year UNIQUE (dept_id, fiscal_year),
    CONSTRAINT check_budget_spent CHECK (spent >= 0)
);