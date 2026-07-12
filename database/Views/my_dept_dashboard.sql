CREATE MATERIALIZED VIEW mv_dept_dashboard
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    d.dept_id,
    d.dept_name,
    COUNT(DISTINCT i.incident_id) AS total_incidents,
    COUNT(DISTINCT CASE WHEN i.status IN ('OPEN','IN_PROGRESS') THEN i.incident_id END) AS open_incidents,
    COUNT(DISTINCT CASE WHEN i.status = 'RESOLVED' THEN i.incident_id END) AS resolved_incidents,
    ROUND(AVG(i.resolution_min) / 60, 2) AS avg_resolution_h,
    COUNT(DISTINCT r.request_id) AS total_requests,
    COUNT(DISTINCT CASE WHEN r.status NOT IN ('COMPLETED','REJECTED','CANCELLED') THEN r.request_id END) AS open_requests,
    COUNT(DISTINCT CASE WHEN r.status = 'ESCALATED' THEN r.request_id END) AS escalated_requests,
    MAX(b.allocated) AS budget_allocated,
    MAX(b.spent) AS budget_spent,
    ROUND(MAX(b.spent) / NULLIF(MAX(b.allocated),0) * 100, 2)  AS budget_pct_used,
    RANK() OVER (ORDER BY AVG(i.resolution_min) ASC NULLS LAST) AS efficiency_rank,
    SYSDATE AS last_refreshed
FROM departments d
LEFT JOIN incidents i ON i.dept_id = d.dept_id
LEFT JOIN employees e ON e.dept_id = d.dept_id AND e.is_active = 1
LEFT JOIN requests r ON r.submitted_by = e.emp_id
LEFT JOIN budgets b ON b.dept_id = d.dept_id
AND b.fiscal_year = TO_NUMBER(TO_CHAR(SYSDATE,'YYYY'))
GROUP BY d.dept_id, d.dept_name;