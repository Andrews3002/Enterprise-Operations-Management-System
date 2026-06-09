-- Roles (insert these first, lowest level to highest)
INSERT INTO roles (role_name, role_level) VALUES ('Employee',   1);
INSERT INTO roles (role_name, role_level) VALUES ('Supervisor', 2);
INSERT INTO roles (role_name, role_level) VALUES ('Ops Manager',3);
INSERT INTO roles (role_name, role_level) VALUES ('Executive',  4);
INSERT INTO roles (role_name, role_level) VALUES ('Auditor',    5);

-- Departments (manager_id left null for now, update after employees inserted)
INSERT INTO departments (dept_name) VALUES ('Human Resources');
INSERT INTO departments (dept_name) VALUES ('Information Technology');
INSERT INTO departments (dept_name) VALUES ('Accounts');
INSERT INTO departments (dept_name) VALUES ('Operations');

-- Workflows
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Leave Request',       48);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Equipment Request',   72);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Overtime Approval',   24);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Incident Report',     12);

-- Workflow stages for Leave Request (workflow_id = 1)
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, required_level)
    VALUES (1, 'Supervisor Review', 1, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, required_level)
    VALUES (1, 'HR Approval',       2, 3);

-- Workflow stages for Equipment Request (workflow_id = 2)
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, required_level)
    VALUES (2, 'Supervisor Review', 1, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, required_level)
    VALUES (2, 'IT Approval',       2, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, required_level)
    VALUES (2, 'Finance Sign-off',  3, 3);

COMMIT;