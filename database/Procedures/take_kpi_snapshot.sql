create or replace PROCEDURE take_kpi_snapshot AS
    CURSOR c_depts IS 
        SELECT dept_id 
        FROM departments;
        
    v_open_inc NUMBER;
    v_resolved NUMBER;
    v_avg_res_h NUMBER;
    v_open_req NUMBER;
    v_breaches NUMBER;
    v_budget_pct NUMBER;
BEGIN
    FOR dept IN c_depts LOOP
        SELECT COUNT(*) 
        INTO v_open_inc
        FROM incidents
        WHERE dept_id = dept.dept_id
        AND status IN ('OPEN','IN_PROGRESS');

        SELECT COUNT(*) 
        INTO v_resolved
        FROM incidents
        WHERE dept_id = dept.dept_id
        AND status = 'RESOLVED'
        AND TRUNC(resolved_at) = TRUNC(SYSDATE);

        SELECT ROUND(AVG(resolution_min) / 60, 2)
        INTO v_avg_res_h
        FROM incidents
        WHERE dept_id = dept.dept_id
        AND resolution_min IS NOT NULL;

        SELECT COUNT(*) 
        INTO v_open_req
        FROM requests r
        JOIN workflow_stages ws ON ws.stage_id = r.current_stage
        WHERE ws.dept_id  = dept.dept_id
        AND r.status NOT IN ('COMPLETED','CANCELLED','REJECTED');

        SELECT COUNT(*) 
        INTO v_breaches
        FROM requests r
        JOIN workflow_stages ws ON ws.stage_id = r.current_stage
        WHERE ws.dept_id = dept.dept_id
        AND r.status  = 'ESCALATED'
        AND TRUNC(r.submitted_at, 'MM') = TRUNC(SYSDATE, 'MM');

        SELECT ROUND((spent / NULLIF(allocated,0)) * 100, 2)
        INTO v_budget_pct
        FROM budgets
        WHERE dept_id = dept.dept_id
        AND fiscal_year = TO_NUMBER(TO_CHAR(SYSDATE,'YYYY'));

        -- Upsert — update today's snapshot if it exists, else insert
        MERGE INTO kpi_logs k
        USING (SELECT dept.dept_id AS dept_id, TRUNC(SYSDATE) AS snap_date
                FROM dual) src
        ON (k.dept_id = src.dept_id AND k.snapshot_date = src.snap_date)
        WHEN MATCHED THEN UPDATE SET
            open_incidents  = v_open_inc,
            resolved_today  = v_resolved,
            avg_resolution_h = v_avg_res_h,
            open_requests   = v_open_req,
            sla_breaches    = v_breaches,
            budget_pct_used = v_budget_pct
        WHEN NOT MATCHED THEN INSERT (
            dept_id, snapshot_date, open_incidents, resolved_today,
            avg_resolution_h, open_requests, sla_breaches, budget_pct_used
        ) VALUES (
            dept.dept_id, TRUNC(SYSDATE), v_open_inc, v_resolved,
            v_avg_res_h, v_open_req, v_breaches, v_budget_pct
        );

    END LOOP;
    COMMIT;
END take_kpi_snapshot;
