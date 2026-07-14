-- Departments (manager_id left null for now, update after employees inserted)
INSERT INTO departments (dept_name) VALUES ('Human Resources');
INSERT INTO departments (dept_name) VALUES ('Information Technology');
INSERT INTO departments (dept_name) VALUES ('Accounts');
INSERT INTO departments (dept_name) VALUES ('Procurement');
INSERT INTO departments (dept_name) VALUES ('Internal Audit');
COMMIT;

-- Annual Budgets for each department (make sure and change the dept_ids to reference the departments you want to assign the budgets too)
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (1, 2026, 600000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (2, 2026, 3000000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (3, 2026, 1500000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (4, 2026, 400000);
INSERT INTO budgets (dept_id, fiscal_year, allocated) VALUES (5, 2026, 200000);
COMMIT;

-- Workflows
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Leave Request', 48);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Equipment Request', 72);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Overtime Request', 24);
INSERT INTO workflows (workflow_name, sla_hours) VALUES ('Incident Report', 12);
COMMIT;

-- Workflow Stages for Leave Request (ensure to change workflow_id and dept_id to reference the the workflows the stage is part of and the deptartment the stage must handled by)
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (1, 'Supervisor Review', 1, 1, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (1, 'HR Approval', 2, 1, 2);
COMMIT;

-- Workflow Stages for Equipment Request (ensure to change workflow_id and dept_id to reference the the workflows the stage is part of and the deptartment the stage must handled by)
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (2, 'Supervisor Review', 1, 4, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (2, 'Procuement Approval', 2, 4, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (2, 'Finance Sign-off', 3, 3, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (2, 'Implementation', 4, 4, 2);
COMMIT;

-- Workflow Stages for Overtime Request (ensure to change workflow_id and dept_id to reference the the workflows the stage is part of and the deptartment the stage must handled by)
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (3, 'Supervisor Review', 1, 1, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (3, 'HR Approval', 2, 1, 2);
COMMIT;

-- Workflow Stages for Incident Report (ensure to change workflow_id and dept_id to reference the the workflows the stage is part of and the deptartment the stage must handled by)
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (4, 'Supervisor Review', 1, 5, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (4, 'Internal Audit Approval', 2, 5, 2);
INSERT INTO workflow_stages (workflow_id, stage_name, stage_seq, dept_id, required_level)
VALUES (4, 'Implementation', 3, 5, 2);
COMMIT;

-- Roles (insert these first, lowest level to highest)
INSERT INTO roles (role_name, role_level) VALUES ('Employee',   1);
INSERT INTO roles (role_name, role_level) VALUES ('Supervisor', 2);
INSERT INTO roles (role_name, role_level) VALUES ('Ops Manager',3);
INSERT INTO roles (role_name, role_level) VALUES ('Executive',  4);
INSERT INTO roles (role_name, role_level) VALUES ('System Admin', 5);
COMMIT;

-- Human Resources (make sure and change dept_ids and role_ids to reference the correct departments you want the employee in and the role you want the employee to have)
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
COMMIT;

-- Information Technology (make sure and change dept_ids and role_ids to reference the correct departments you want the employee in and the role you want the employee to have)
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
COMMIT;

-- Accounts (make sure and change dept_ids and role_ids to reference the correct departments you want the employee in and the role you want the employee to have)
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
COMMIT;

-- Procurement (make sure and change dept_ids and role_ids to reference the correct departments you want the employee in and the role you want the employee to have)
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
COMMIT;

-- Internal Audit (make sure and change dept_ids and role_ids to reference the correct departments you want the employee in and the role you want the employee to have)
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
COMMIT;

DECLARE
    v_id NUMBER;
BEGIN
    v_id := employee_pkg.submit_request(7,  2, 'Laptop replacement needed');
    v_id := employee_pkg.submit_request(6,  2, 'Monitor upgrade request');
    v_id := employee_pkg.submit_request(12, 3, 'Leave request - 3 days');
    v_id := employee_pkg.submit_request(17, 1, 'Overtime approval needed');
    v_id := employee_pkg.submit_request(21, 1, 'Leave request - 1 week');
    v_id := employee_pkg.submit_request(22, 2, 'Second equipment request');
    DBMS_OUTPUT.PUT_LINE('Requests seeded.');
END;
/

DECLARE
    v_id NUMBER;
BEGIN
    v_id := employee_pkg.log_incident(1, 1,  'Payroll system delay', 'MEDIUM');
    v_id := employee_pkg.log_incident(2, 7,  'Network outage - floor 2', 'CRITICAL');
    v_id := employee_pkg.log_incident(3, 12, 'Invoice processing backlog', 'LOW');
    v_id := employee_pkg.log_incident(4, 21, 'Supplier delivery failure', 'HIGH');
    v_id := employee_pkg.log_incident(2, 6,  'VPN authentication failure', 'HIGH');
    DBMS_OUTPUT.PUT_LINE('Incidents seeded.');
END;
/

BEGIN
    ops_manager_pkg.resolve_incident(1, 4, 'Email server restarted and restored.');---------------------------------------------------
    ops_manager_pkg.resolve_incident(3, 15, 'VPN certificates renewed.');
END;
/

BEGIN
    supervisor_pkg.assign_task(9, 6, 'Patch server OS', 'HIGH', TO_DATE('2026-07-15', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(9, 7, 'Update firewall rules', 'MEDIUM', TO_DATE('2026-07-27', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(9, 6, 'Audit user accounts', 'HIGH', TO_DATE('2026-08-10', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(9, 8, 'Deploy monitoring agent', 'LOW', TO_DATE('2026-08-14', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(3, 1, 'Review leave policy', 'MEDIUM', TO_DATE('2026-09-21', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(3, 2, 'Update employee handbook', 'LOW', TO_DATE('2027-03-31', 'YYYY-MM-DD'));
    COMMIT;
END;
/

BEGIN
    ops_manager_pkg.department_spend(1, 4, 125000);
    ops_manager_pkg.department_spend(2, 9, 870000);
    ops_manager_pkg.department_spend(3, 15, 450000);
    ops_manager_pkg.department_spend(4, 20, 82000);
    ops_manager_pkg.department_spend(5, 25, 11000);
END;
/

-- =============================================================
-- Extended Seed Data
-- Run after seed_all.sql — adds volume across all operational tables
-- =============================================================

-- =============================================================
-- ADDITIONAL REQUESTS
-- =============================================================

-- More leave requests (HR workflow = 1)
DECLARE
    v_id NUMBER;
BEGIN
    -- Additional leave requests from various employees
    v_id := employee_pkg.submit_request(1,  1, 'Sick leave - 2 days');
    v_id := employee_pkg.submit_request(2,  1, 'Annual leave - 10 days');
    v_id := employee_pkg.submit_request(6,  1, 'Paternity leave request');
    v_id := employee_pkg.submit_request(7,  1, 'Annual leave - 3 days');
    v_id := employee_pkg.submit_request(12, 1, 'Compassionate leave - 5 days');
    v_id := employee_pkg.submit_request(13, 1, 'Annual leave - 7 days');
    v_id := employee_pkg.submit_request(16, 1, 'Sick leave - 1 day');
    v_id := employee_pkg.submit_request(17, 1, 'Annual leave - 4 days');
    v_id := employee_pkg.submit_request(21, 1, 'Annual leave - 2 days');
    v_id := employee_pkg.submit_request(22, 1, 'Unpaid leave - 3 days');

    -- More equipment requests (Equipment workflow = 2)
    v_id := employee_pkg.submit_request(1,  2, 'Standing desk request');
    v_id := employee_pkg.submit_request(2,  2, 'External keyboard and mouse');
    v_id := employee_pkg.submit_request(6,  2, 'Server rack upgrade');
    v_id := employee_pkg.submit_request(7,  2, 'Additional monitors x2');
    v_id := employee_pkg.submit_request(11, 2, 'Laptop battery replacement');
    v_id := employee_pkg.submit_request(12, 2, 'USB-C docking station');
    v_id := employee_pkg.submit_request(13, 2, 'Accounting software license');
    v_id := employee_pkg.submit_request(16, 2, 'Label printer');
    v_id := employee_pkg.submit_request(17, 2, 'Wireless headset');
    v_id := employee_pkg.submit_request(21, 2, 'Document scanner');

    -- More overtime requests (Overtime workflow = 3)
    v_id := employee_pkg.submit_request(1,  3, 'Year-end payroll processing');
    v_id := employee_pkg.submit_request(2,  3, 'Q2 audit preparation');
    v_id := employee_pkg.submit_request(6,  3, 'Network migration overtime');
    v_id := employee_pkg.submit_request(7,  3, 'Server maintenance window');
    v_id := employee_pkg.submit_request(8,  3, 'Firewall upgrade overtime');
    v_id := employee_pkg.submit_request(12, 3, 'Month-end close overtime');
    v_id := employee_pkg.submit_request(13, 3, 'Tax filing deadline overtime');
    v_id := employee_pkg.submit_request(16, 3, 'Vendor negotiation prep');
    v_id := employee_pkg.submit_request(17, 3, 'Procurement audit overtime');
    v_id := employee_pkg.submit_request(21, 3, 'Compliance report overtime');

    -- Incident report workflow requests (Incident Report workflow = 4)
    v_id := employee_pkg.submit_request(1,  4, 'Data breach attempt - reported');
    v_id := employee_pkg.submit_request(6,  4, 'Unauthorized access attempt');
    v_id := employee_pkg.submit_request(12, 4, 'Financial discrepancy report');
    v_id := employee_pkg.submit_request(21, 4, 'Supplier contract violation');

    DBMS_OUTPUT.PUT_LINE('Additional requests seeded.');
END;
/

-- =============================================================
-- ADVANCE SOME REQUESTS THROUGH STAGES
-- Approve stage 1 on a batch of requests so they move to IN_REVIEW
-- These reference the request_ids generated above — check your
-- actual IDs and adjust decider_ids to match dept supervisors
-- =============================================================

-- Leave requests: stage 1 approved by HR supervisor (emp 3 = HR supervisor)
BEGIN
    -- Approve stage 1 on requests 8 through 17 (the new leave requests)
    -- Adjust request_ids to match what was generated in your environment
    supervisor_pkg.decide_stage(8,  3, 'APPROVED', 'Approved - HR review complete');
    supervisor_pkg.decide_stage(9,  3, 'APPROVED', 'Approved - dates confirmed');
    supervisor_pkg.decide_stage(10, 3, 'APPROVED', 'Approved - coverage arranged');
    supervisor_pkg.decide_stage(11, 3, 'APPROVED', 'Approved');
    supervisor_pkg.decide_stage(12, 3, 'APPROVED', 'Compassionate leave approved');
END;
/

-- Approve stage 2 on some (fully complete them)
BEGIN
    supervisor_pkg.decide_stage(8,  4, 'APPROVED', 'Final HR sign-off complete');
    supervisor_pkg.decide_stage(9,  4, 'APPROVED', 'Final HR sign-off complete');
    supervisor_pkg.decide_stage(10, 4, 'APPROVED', 'Final HR sign-off complete');
END;
/

-- Reject some requests at stage 1
BEGIN
    supervisor_pkg.decide_stage(13, 3, 'REJECTED', 'Insufficient notice period');
    supervisor_pkg.decide_stage(14, 3, 'REJECTED', 'Team capacity too low during requested period');
    supervisor_pkg.decide_stage(16, 3, 'REJECTED', 'Sick leave requires medical certificate first');
END;
/

-- Equipment requests: stage 1 approved by Procurement supervisor (emp 19 = Procurement supervisor)
BEGIN
    supervisor_pkg.decide_stage(18, 19, 'APPROVED', 'Approved - forwarding to procurement');
    supervisor_pkg.decide_stage(19, 19, 'APPROVED', 'Approved');
    supervisor_pkg.decide_stage(20, 19, 'APPROVED', 'Approved - server upgrade prioritised');
    supervisor_pkg.decide_stage(21, 19, 'APPROVED', 'Approved');
END;
/

-- Procurement approval stage 2 on some equipment requests
BEGIN
    supervisor_pkg.decide_stage(18, 15, 'APPROVED', 'Budget confirmed - forwarding to Accounts');
    supervisor_pkg.decide_stage(19, 15, 'APPROVED', 'Budget confirmed');
END;
/

-- Accounts finance sign-off stage 3
BEGIN
    supervisor_pkg.decide_stage(18, 15, 'APPROVED', 'Finance approved - proceed to implementation');
END;
/

-- Overtime requests: approve several fully
BEGIN
    -- HR supervisor approves stage 1
    supervisor_pkg.decide_stage(28, 3, 'APPROVED', 'Approved - year end justified');
    supervisor_pkg.decide_stage(29, 3, 'APPROVED', 'Approved');
    supervisor_pkg.decide_stage(30, 3, 'APPROVED', 'Approved - network migration confirmed');
    supervisor_pkg.decide_stage(31, 3, 'APPROVED', 'Approved');
    supervisor_pkg.decide_stage(34, 3, 'APPROVED', 'Approved');
END;
/

-- HR ops manager approves stage 2 (fully completing overtime requests)
BEGIN
    supervisor_pkg.decide_stage(28, 4, 'APPROVED', 'HR sign-off complete');
    supervisor_pkg.decide_stage(29, 4, 'APPROVED', 'HR sign-off complete');
    supervisor_pkg.decide_stage(30, 4, 'APPROVED', 'HR sign-off complete');
END;
/

-- Reject some overtime requests
BEGIN
    supervisor_pkg.decide_stage(32, 3, 'REJECTED', 'Overtime budget exceeded for this period');
    supervisor_pkg.decide_stage(33, 3, 'REJECTED', 'Not justified - can be handled in hours');
END;
/


-- =============================================================
-- ADDITIONAL INCIDENTS
-- =============================================================

DECLARE
    v_id NUMBER;
BEGIN
    -- HR department incidents
    v_id := employee_pkg.log_incident(1, 1,  'HR portal login failure - multiple employees', 'HIGH');
    v_id := employee_pkg.log_incident(1, 2,  'Payroll export file corrupted', 'CRITICAL');
    v_id := employee_pkg.log_incident(1, 1,  'Employee records sync failure', 'MEDIUM');
    v_id := employee_pkg.log_incident(1, 2,  'Leave balance calculation error', 'LOW');

    -- IT department incidents
    v_id := employee_pkg.log_incident(2, 6,  'Database connection pool exhausted', 'CRITICAL');
    v_id := employee_pkg.log_incident(2, 7,  'SSL certificate expiry warning', 'HIGH');
    v_id := employee_pkg.log_incident(2, 6,  'Backup job failed - 3 consecutive nights', 'HIGH');
    v_id := employee_pkg.log_incident(2, 7,  'Disk space at 92 percent on app server', 'MEDIUM');
    v_id := employee_pkg.log_incident(2, 6,  'Email gateway intermittent failures', 'MEDIUM');
    v_id := employee_pkg.log_incident(2, 7,  'Print server unresponsive', 'LOW');
    v_id := employee_pkg.log_incident(2, 6,  'Remote desktop service crashed', 'HIGH');
    v_id := employee_pkg.log_incident(2, 7,  'DNS resolution failure - internal hosts', 'CRITICAL');

    -- Accounts department incidents
    v_id := employee_pkg.log_incident(3, 12, 'Payment run failed - duplicate entries', 'CRITICAL');
    v_id := employee_pkg.log_incident(3, 13, 'Reconciliation report missing transactions', 'HIGH');
    v_id := employee_pkg.log_incident(3, 12, 'Invoice approval queue stuck', 'MEDIUM');
    v_id := employee_pkg.log_incident(3, 13, 'Currency conversion rate not updating', 'LOW');
    v_id := employee_pkg.log_incident(3, 12, 'Budget report incorrect totals', 'HIGH');

    -- Procurement department incidents
    v_id := employee_pkg.log_incident(4, 16, 'Supplier portal access denied', 'HIGH');
    v_id := employee_pkg.log_incident(4, 17, 'Purchase order system timeout', 'MEDIUM');
    v_id := employee_pkg.log_incident(4, 16, 'Vendor payment overdue - system flag', 'HIGH');
    v_id := employee_pkg.log_incident(4, 17, 'Contract renewal alert not triggered', 'MEDIUM');
    v_id := employee_pkg.log_incident(4, 16, 'Goods received not matched to PO', 'LOW');

    -- Internal Audit department incidents
    v_id := employee_pkg.log_incident(5, 21, 'Audit trail export timeout', 'MEDIUM');
    v_id := employee_pkg.log_incident(5, 22, 'Compliance report generation failed', 'HIGH');
    v_id := employee_pkg.log_incident(5, 21, 'User access review overdue flag', 'MEDIUM');
    v_id := employee_pkg.log_incident(5, 22, 'Policy document version mismatch', 'LOW');

    DBMS_OUTPUT.PUT_LINE('Additional incidents seeded.');
END;
/

-- =============================================================
-- RESOLVE A LARGE BATCH OF INCIDENTS
-- Resolvers must be the assigned manager for each department
-- dept 1 manager = emp 4, dept 2 manager = emp 9,
-- dept 3 manager = emp 15, dept 4 manager = emp 20, dept 5 manager = emp 25
-- =============================================================

BEGIN
    -- Resolve HR incidents
    ops_manager_pkg.resolve_incident(7,  4, 'Portal cache cleared - all users able to log in');
    ops_manager_pkg.resolve_incident(8,  4, 'Payroll file regenerated from source - exported cleanly');
    ops_manager_pkg.resolve_incident(9,  4, 'Sync service restarted - records reconciled');

    -- Resolve IT incidents
    ops_manager_pkg.resolve_incident(11, 9, 'Connection pool size increased from 50 to 200');
    ops_manager_pkg.resolve_incident(12, 9, 'SSL certificates renewed for all services');
    ops_manager_pkg.resolve_incident(13, 9, 'Backup job fixed - storage path remapped');
    ops_manager_pkg.resolve_incident(15, 9, 'Email gateway failover activated - primary restored after 4 hours');
    ops_manager_pkg.resolve_incident(17, 9, 'Remote desktop service restarted and set to auto-recover');

    -- Resolve Accounts incidents
    ops_manager_pkg.resolve_incident(19, 15, 'Duplicate entries removed - payment run reprocessed');
    ops_manager_pkg.resolve_incident(20, 15, 'Missing transactions identified and posted manually');
    ops_manager_pkg.resolve_incident(23, 15, 'Budget report formula corrected - totals verified');

    -- Resolve Procurement incidents
    ops_manager_pkg.resolve_incident(24, 20, 'Supplier portal credentials reset and access restored');
    ops_manager_pkg.resolve_incident(26, 20, 'Vendor payment processed manually - system flag cleared');

    -- Resolve Internal Audit incidents
    ops_manager_pkg.resolve_incident(29, 25, 'Export query optimised - report now generates in under 30 seconds');
    ops_manager_pkg.resolve_incident(30, 25, 'Compliance report regenerated after log rotation fix');

    DBMS_OUTPUT.PUT_LINE('Incidents resolved.');
END;
/


-- =============================================================
-- ADDITIONAL TASKS
-- =============================================================

BEGIN
    -- HR tasks (supervisor emp 3 assigning to emp 1 and 2)
    supervisor_pkg.assign_task(3, 1, 'Update employee onboarding checklist',      'HIGH',   TO_DATE('2026-07-20', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(3, 2, 'Prepare Q3 headcount report',               'MEDIUM', TO_DATE('2026-07-31', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(3, 1, 'Review and update job descriptions - IT',   'LOW',    TO_DATE('2026-08-15', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(3, 2, 'Organise staff training calendar Q3',       'MEDIUM', TO_DATE('2026-08-01', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(3, 1, 'Process pending contract renewals',         'HIGH',   TO_DATE('2026-07-18', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(3, 2, 'Conduct probation review - 3 employees',    'HIGH',   TO_DATE('2026-07-22', 'YYYY-MM-DD'));

    -- IT tasks (supervisor emp 8 assigning to emp 6 and 7)
    supervisor_pkg.assign_task(8, 6, 'Rotate all service account passwords',      'HIGH',   TO_DATE('2026-07-16', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(8, 7, 'Migrate legacy file shares to SharePoint',  'MEDIUM', TO_DATE('2026-08-30', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(8, 6, 'Document network topology changes',         'LOW',    TO_DATE('2026-08-20', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(8, 7, 'Test disaster recovery failover procedure', 'HIGH',   TO_DATE('2026-07-25', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(8, 6, 'Upgrade endpoint antivirus - all machines', 'HIGH',   TO_DATE('2026-07-19', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(8, 7, 'Renew domain registration',                 'MEDIUM', TO_DATE('2026-07-30', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(8, 6, 'Archive Q1-Q2 server logs',                 'LOW',    TO_DATE('2026-08-10', 'YYYY-MM-DD'));

    -- Accounts tasks (supervisor emp 14 assigning to emp 12 and 13)
    supervisor_pkg.assign_task(14, 12, 'Reconcile June bank statements',          'HIGH',   TO_DATE('2026-07-15', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(14, 13, 'Prepare VAT return - Q2',                 'HIGH',   TO_DATE('2026-07-31', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(14, 12, 'Review aged debtors report',              'MEDIUM', TO_DATE('2026-07-20', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(14, 13, 'Update fixed asset register',             'LOW',    TO_DATE('2026-08-14', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(14, 12, 'Process staff expense claims - June',     'MEDIUM', TO_DATE('2026-07-17', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(14, 13, 'Prepare management accounts draft',       'HIGH',   TO_DATE('2026-07-25', 'YYYY-MM-DD'));

    -- Procurement tasks (supervisor emp 19 assigning to emp 16 and 17)
    supervisor_pkg.assign_task(19, 16, 'Review and renew 3 supplier contracts',   'HIGH',   TO_DATE('2026-07-18', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(19, 17, 'Obtain 3 quotes for office supplies',     'LOW',    TO_DATE('2026-07-25', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(19, 16, 'Update preferred supplier list',          'MEDIUM', TO_DATE('2026-08-01', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(19, 17, 'Process outstanding POs from June',       'HIGH',   TO_DATE('2026-07-16', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(19, 16, 'Prepare spend analysis report - H1',      'MEDIUM', TO_DATE('2026-07-31', 'YYYY-MM-DD'));

    -- Internal Audit tasks (supervisor emp 24 assigning to emp 21 and 22)
    supervisor_pkg.assign_task(24, 21, 'Complete Q2 compliance checklist',        'HIGH',   TO_DATE('2026-07-20', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(24, 22, 'Review user access rights - all systems', 'HIGH',   TO_DATE('2026-07-22', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(24, 21, 'Draft internal audit report - Accounts',  'MEDIUM', TO_DATE('2026-08-05', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(24, 22, 'Update risk register',                    'MEDIUM', TO_DATE('2026-07-31', 'YYYY-MM-DD'));
    supervisor_pkg.assign_task(24, 21, 'Prepare board pack - audit section',      'HIGH',   TO_DATE('2026-07-28', 'YYYY-MM-DD'));

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Additional tasks seeded.');
END;
/

-- =============================================================
-- COMPLETE AND CANCEL SOME TASKS
-- complete_task validates the assignee, cancel_task validates the creator
-- =============================================================

BEGIN
    -- Complete tasks (actor must be the assigned_to employee)

    -- HR completed tasks
    employee_pkg.complete_task(1, 9);    -- John completes task 9
    employee_pkg.complete_task(2, 10);   -- Sarah completes task 10
    employee_pkg.complete_task(1, 13);   -- John completes task 13
    employee_pkg.complete_task(2, 14);   -- Sarah completes task 14

    -- IT completed tasks
    employee_pkg.complete_task(6, 1);    -- David completes task 1 (from seed_all)
    employee_pkg.complete_task(6, 3);    -- David completes task 3 (from seed_all)
    employee_pkg.complete_task(7, 2);    -- Emma completes task 2 (from seed_all)
    employee_pkg.complete_task(6, 17);   -- David completes task 17
    employee_pkg.complete_task(7, 18);   -- Emma completes task 18
    employee_pkg.complete_task(6, 21);   -- David completes task 21

    -- Accounts completed tasks
    employee_pkg.complete_task(12, 25);  -- Benjamin completes task 25
    employee_pkg.complete_task(13, 26);  -- Mia completes task 26
    employee_pkg.complete_task(12, 29);  -- Benjamin completes task 29

    -- Procurement completed tasks
    employee_pkg.complete_task(17, 32);  -- Harper completes task 32
    employee_pkg.complete_task(16, 31);  -- Alexander completes task 31

    -- Internal Audit completed tasks
    employee_pkg.complete_task(21, 36);  -- Joseph completes task 36
    employee_pkg.complete_task(22, 37);  -- Ella completes task 37

    DBMS_OUTPUT.PUT_LINE('Tasks completed.');
END;
/

BEGIN
    -- Cancel tasks (actor must be the created_by employee)

    -- HR cancellations
    supervisor_pkg.cancel_task(3, 11);   -- HR supervisor cancels task 11
    supervisor_pkg.cancel_task(3, 12);   -- HR supervisor cancels task 12

    -- IT cancellations
    supervisor_pkg.cancel_task(9, 4);    -- IT supervisor cancels task 4 (from seed_all)
    supervisor_pkg.cancel_task(8, 20);   -- IT supervisor cancels task 20
    supervisor_pkg.cancel_task(8, 23);   -- IT supervisor cancels task 23

    -- Accounts cancellations
    supervisor_pkg.cancel_task(14, 27);  -- Accounts supervisor cancels task 27
    supervisor_pkg.cancel_task(14, 30);  -- Accounts supervisor cancels task 30

    -- Procurement cancellations
    supervisor_pkg.cancel_task(19, 33);  -- Procurement supervisor cancels task 33

    -- Internal Audit cancellations
    supervisor_pkg.cancel_task(24, 40);  -- Audit supervisor cancels task 40

    DBMS_OUTPUT.PUT_LINE('Tasks cancelled.');
END;
/

-- =============================================================
-- ADDITIONAL BUDGET SPEND
-- Keep running totals realistic relative to allocations
-- =============================================================

BEGIN
    ops_manager_pkg.department_spend(1, 4,  28000);   -- HR: recruitment costs
    ops_manager_pkg.department_spend(1, 4,  15500);   -- HR: training programme
    ops_manager_pkg.department_spend(2, 9,  142000);  -- IT: hardware refresh
    ops_manager_pkg.department_spend(2, 9,  63000);   -- IT: software licenses
    ops_manager_pkg.department_spend(2, 9,  37500);   -- IT: cloud infrastructure
    ops_manager_pkg.department_spend(3, 15, 22000);   -- Accounts: audit fees
    ops_manager_pkg.department_spend(3, 15, 18750);   -- Accounts: accounting software
    ops_manager_pkg.department_spend(4, 20, 31200);   -- Procurement: supplier onboarding
    ops_manager_pkg.department_spend(4, 20, 9800);    -- Procurement: travel
    ops_manager_pkg.department_spend(5, 25, 14300);   -- Audit: compliance tools
    ops_manager_pkg.department_spend(5, 25, 8600);    -- Audit: external review
    DBMS_OUTPUT.PUT_LINE('Budget spend seeded.');
END;
/

-- =============================================================
-- TAKE A KPI SNAPSHOT TO POPULATE kpi_logs
-- =============================================================

BEGIN
    take_kpi_snapshot;
    DBMS_OUTPUT.PUT_LINE('KPI snapshot taken.');
END;
/

-- =============================================================
-- REFRESH MATERIALIZED VIEW
-- =============================================================

BEGIN
    DBMS_MVIEW.REFRESH('MV_DEPT_DASHBOARD', 'C');
    DBMS_OUTPUT.PUT_LINE('Dashboard view refreshed.');
END;
/