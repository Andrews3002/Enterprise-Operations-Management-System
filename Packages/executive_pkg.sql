create or replace PACKAGE executive_pkg AS

    FUNCTION dept_efficiency_report RETURN SYS_REFCURSOR;

    FUNCTION employee_workload_report RETURN SYS_REFCURSOR;

    FUNCTION incident_trend_report RETURN SYS_REFCURSOR;

    FUNCTION workflow_bottleneck_report RETURN SYS_REFCURSOR;

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR;

    FUNCTION request_aging_report RETURN SYS_REFCURSOR;

    FUNCTION dept_kpi_trend_report RETURN SYS_REFCURSOR;

END executive_pkg;

create or replace PACKAGE BODY executive_pkg AS

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

    FUNCTION budget_utilisation_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                b.allocated,
                b.spent,
                b.allocated - b.spent AS remaining,
                ROUND((b.spent / NULLIF(b.allocated,0)) * 100, 2) AS pct_used,
                ROUND(RATIO_TO_REPORT(b.spent) OVER () * 100, 2) AS pct_of_company_spend,
                RANK() OVER (ORDER BY b.spent DESC) AS spend_rank,
                CASE
                    WHEN b.spent / NULLIF(b.allocated,0) >= 1.00 THEN 'OVERSPENT'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.85 THEN 'AT_RISK'
                    WHEN b.spent / NULLIF(b.allocated,0) >= 0.60 THEN 'ON_TRACK'
                    ELSE 'UNDERSPENT'
                END AS spend_status
            FROM budgets b
            JOIN departments d ON d.dept_id = b.dept_id
            WHERE b.fiscal_year = TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'))
            ORDER BY spend_rank;

        RETURN v_cur;
    END budget_utilisation_report;

    FUNCTION request_aging_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                r.request_id,
                w.workflow_name,
                e.first_name || ' ' || e.last_name AS submitted_by,
                d.dept_name,
                ws.stage_name AS waiting_at_stage,
                r.status,
                r.submitted_at,
                ROUND(
                    EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                    + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                    + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                    + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600,
                1) AS hours_open,
                CASE
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 24 THEN 'Under 1 day'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 72    THEN '1-3 days'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 168   THEN '3-7 days'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) < 336   THEN '1-2 weeks'
                    ELSE 'Over 2 weeks'
                END AS age_bucket,
                CASE
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) / w.sla_hours < 0.70 THEN 'ON_TRACK'
                    WHEN (
                        EXTRACT(DAY FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) * 24
                        + EXTRACT(HOUR FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC')))
                        + EXTRACT(MINUTE FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 60
                        + EXTRACT(SECOND FROM (SYSTIMESTAMP - FROM_TZ(r.submitted_at, 'UTC'))) / 3600
                    ) / w.sla_hours < 1.00 THEN 'AT_RISK'
                    ELSE 'BREACHED'
                END AS sla_status,
                RANK() OVER (
                    PARTITION BY d.dept_id
                    ORDER BY r.submitted_at ASC
                ) AS dept_age_rank
            FROM requests r
            JOIN workflows w ON w.workflow_id = r.workflow_id
            JOIN employees e ON e.emp_id = r.submitted_by
            JOIN departments d ON d.dept_id = e.dept_id
            LEFT JOIN workflow_stages ws ON ws.stage_id = r.current_stage
            WHERE r.status NOT IN ('COMPLETED','REJECTED','CANCELLED')
            ORDER BY hours_open DESC;

        RETURN v_cur;
    END request_aging_report;

    FUNCTION dept_kpi_trend_report RETURN SYS_REFCURSOR AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT
                d.dept_name,
                k.snapshot_date,
                k.open_incidents,
                k.open_requests,
                k.sla_breaches,
                k.budget_pct_used,
                k.open_incidents - LAG(k.open_incidents) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                ) AS incident_delta,
                k.open_requests - LAG(k.open_requests) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                ) AS request_delta,
                k.budget_pct_used - LAG(k.budget_pct_used) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                ) AS budget_delta,
                ROUND(AVG(k.open_incidents) OVER (
                    PARTITION BY k.dept_id
                    ORDER BY k.snapshot_date
                    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
                ), 2) AS inc_3day_avg
            FROM kpi_logs k
            JOIN departments d ON d.dept_id = k.dept_id
            ORDER BY d.dept_name, k.snapshot_date;

        RETURN v_cur;
    END dept_kpi_trend_report;


END executive_pkg;
