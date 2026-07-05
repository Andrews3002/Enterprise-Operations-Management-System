CREATE OR REPLACE PACKAGE reporting_pkg AS
    PROCEDURE take_kpi_snapshot;

    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR;

    FUNCTION employee_workload_report RETURN SYS_REFCURSOR;

    FUNCTION incident_trend_report RETURN SYS_REFCURSOR;

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR;

END reporting_pkg;
/

CREATE OR REPLACE PACKAGE BODY reporting_pkg AS
    PROCEDURE take_kpi_snapshot AS
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

    ------------------------------------------------------------------ rank departments by efficiency
    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                COUNT(DISTINCT i.incident_id) AS total_incidents,
                ROUND(AVG(i.resolution_min) / 60, 2) AS avg_resolution_h,
                COUNT(CASE WHEN i.status IN ('OPEN','IN_PROGRESS') THEN 1 END) AS open_incidents,
                
                RANK() OVER (
                    ORDER BY AVG(i.resolution_min) ASC NULLS LAST
                ) AS efficiency_rank,

                ROUND(
                    AVG(i.resolution_min) - AVG(AVG(i.resolution_min))
                        OVER (), 2
                ) AS vs_company_avg_min
            FROM departments d
            LEFT JOIN incidents i ON i.dept_id = d.dept_id
            GROUP BY d.dept_id, d.dept_name
            ORDER BY efficiency_rank;

        RETURN v_cur;
    END dept_efficiency_report;

    ------------------------------------------------------------------- employee workload within dept
    FUNCTION employee_workload_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                e.first_name || ' ' || e.last_name   AS employee_name,
                COUNT(t.task_id) AS active_tasks,
                
                DENSE_RANK() OVER (
                    PARTITION BY e.dept_id
                    ORDER BY COUNT(t.task_id) DESC
                ) AS dept_workload_rank,
                
                ROUND(
                    COUNT(t.task_id) * 100.0 /
                    NULLIF(SUM(COUNT(t.task_id)) OVER (PARTITION BY e.dept_id), 0),
                2) AS pct_of_dept_load
            FROM employees e
            JOIN departments d ON d.dept_id = e.dept_id
            LEFT JOIN tasks  t ON t.assigned_to = e.emp_id
            AND t.status IN ('OPEN','IN_PROGRESS')
            WHERE e.is_active = 1
            GROUP BY e.emp_id, e.first_name, e.last_name, e.dept_id, d.dept_name
            ORDER BY d.dept_name, dept_workload_rank;

        RETURN v_cur;
    END employee_workload_report;

    -------------------------------------- Incident trend: weekly counts for last 8 weeks by severity
    FUNCTION incident_trend_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                TRUNC(reported_at, 'IW') AS week_start,
                severity,
                COUNT(*) AS incident_count,
                
                SUM(COUNT(*)) OVER (
                    PARTITION BY severity
                    ORDER BY TRUNC(reported_at, 'IW')
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ) AS running_total
            FROM incidents
            WHERE reported_at >= SYSDATE - 56
            GROUP BY TRUNC(reported_at, 'IW'), severity
            ORDER BY week_start, severity;

        RETURN v_cur;
    END incident_trend_report;

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            WITH stage_decisions AS (
                SELECT
                    d.request_id,
                    d.stage_id,
                    ws.stage_name,
                    ws.stage_seq,
                    w.workflow_name,
                    d.decision_at,
                    LAG(d.decision_at) OVER (
                        PARTITION BY d.request_id
                        ORDER BY ws.stage_seq
                    ) AS prev_decision_at
                FROM decisions d
                JOIN workflow_stages ws ON ws.stage_id  = d.stage_id
                JOIN requests r ON r.request_id = d.request_id
                JOIN workflows w ON w.workflow_id = r.workflow_id
            ),
            dwell_times AS (
                SELECT
                    sd.workflow_name,
                    sd.stage_name,
                    sd.stage_seq,
                    ROUND(
                        EXTRACT(DAY  FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) * 24
                        + EXTRACT(HOUR FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        )))
                        + EXTRACT(MINUTE FROM (sd.decision_at - NVL(sd.prev_decision_at,
                            (SELECT r.submitted_at FROM requests r
                             WHERE r.request_id = sd.request_id)
                        ))) / 60,
                    2) AS dwell_hours
                FROM stage_decisions sd
            )
            SELECT
                workflow_name,
                stage_name,
                stage_seq,
                COUNT(*) AS requests_through_stage,
                ROUND(AVG(dwell_hours), 2) AS avg_dwell_hours,
                ROUND(MAX(dwell_hours), 2) AS max_dwell_hours,
                
                RANK() OVER (
                    PARTITION BY workflow_name
                    ORDER BY AVG(dwell_hours) DESC
                )
            AS bottleneck_rank
            FROM dwell_times
            GROUP BY workflow_name, stage_name, stage_seq
            ORDER BY workflow_name, bottleneck_rank;

        RETURN v_cur;
    END workflow_bottleneck_report;

END reporting_pkg;
/