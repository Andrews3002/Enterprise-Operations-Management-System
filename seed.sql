-- Roles (insert these first, lowest level to highest)
INSERT INTO roles (role_name, role_level) VALUES ('Employee',   1);
INSERT INTO roles (role_name, role_level) VALUES ('Supervisor', 2);
INSERT INTO roles (role_name, role_level) VALUES ('Ops Manager',3);
INSERT INTO roles (role_name, role_level) VALUES ('Executive',  4);
INSERT INTO roles (role_name, role_level) VALUES ('System Admin', 5);

-- Departments (manager_id left null for now, update after employees inserted)
INSERT INTO departments (dept_name) VALUES ('Human Resources');
INSERT INTO departments (dept_name) VALUES ('Information Technology');
INSERT INTO departments (dept_name) VALUES ('Accounts');
INSERT INTO departments (dept_name) VALUES ('Procurement');
INSERT INTO departments (dept_name) VALUES ('Internal Audit');

-- Annual Budgets for each department
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (21, 2026, 600000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (22, 2026, 3000000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (23, 2026, 1500000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (24, 2026, 400000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (25, 2026, 200000);

-- Human Resources
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('John', 'Smith', 'john.smith@company.com', 1, 1);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Sarah', 'Williams', 'sarah.williams@company.com', 1, 1);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Michael', 'Brown', 'michael.brown@company.com', 1, 2);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Jennifer', 'Davis', 'jennifer.davis@company.com', 1, 3);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Robert', 'Miller', 'robert.miller@company.com', 1, 4);

-- Information Technology
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('David', 'Taylor', 'david.taylor@company.com', 2, 1);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Emma', 'Anderson', 'emma.anderson@company.com', 2, 1);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('James', 'Thomas', 'james.thomas@company.com', 2, 2);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Olivia', 'Jackson', 'olivia.jackson@company.com', 2, 3);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('William', 'White', 'william.white@company.com', 2, 4);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Sophia', 'Harris', 'sophia.harris@company.com', 2, 5);

-- Accounts
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Benjamin', 'Martin', 'benjamin.martin@company.com', 3, 1);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Mia', 'Thompson', 'mia.thompson@company.com', 3, 1);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Lucas', 'Garcia', 'lucas.garcia@company.com', 3, 2);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Charlotte', 'Martinez', 'charlotte.martinez@company.com', 3, 3);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Henry', 'Robinson', 'henry.robinson@company.com', 3, 4);

-- Procurement
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Alexander', 'Rodriguez', 'alexander.rodriguez@company.com', 4, 1);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Harper', 'Lewis', 'harper.lewis@company.com', 4, 1);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Daniel', 'Lee', 'daniel.lee@company.com', 4, 2);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Evelyn', 'Walker', 'evelyn.walker@company.com', 4, 3);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Matthew', 'Hall', 'matthew.hall@company.com', 4, 4);

-- Internal Audit
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Joseph', 'Young', 'joseph.young@company.com', 5, 1);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Ella', 'King', 'ella.king@company.com', 5, 1);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Samuel', 'Wright', 'samuel.wright@company.com', 5, 2);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Grace', 'Scott', 'grace.scott@company.com', 5, 3);
INSERT INTO employees (first_name, last_name, email, dept_id, role_id)
VALUES ('Andrew', 'Green', 'andrew.green@company.com', 5, 4);

-- Workflows
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Leave Request', 48);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Equipment Request', 72);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Overtime Request', 24);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Incident Report', 12);

-- Workflow Stages for Leave Request
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (1, 'Supervisor Review', 1, 1, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (1, 'HR Approval', 2, 1, 2);

-- Workflow Stages for Equipment Request
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (2, 'Supervisor Review', 1, 4, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (2, 'Procuement Approval', 2, 4, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (2, 'Finance Sign-off', 3, 3, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (2, 'Implementation', 4, 4, 2);

-- Workflow Stages for Overtime Request
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (3, 'Supervisor Review', 1, 1, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (3, 'HR Approval', 2, 1, 2);

-- Workflow Stages for Incident Report
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (4, 'Supervisor Review', 1, 5, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (4, 'Internal Audit Approval', 2, 5, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
    VALUES (4, 'Implementation', 3, 5, 2);

COMMIT;