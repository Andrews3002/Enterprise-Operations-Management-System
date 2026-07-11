from fastapi import APIRouter, HTTPException
from database import get_connection
from schemas import DepartmentSpendBody
import oracledb

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

@router.get("/")
def get_dashboard():
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute("""
                    SELECT dept_id, dept_name, total_incidents, open_incidents,
                           resolved_incidents, avg_resolution_h, total_requests,
                           open_requests, escalated_requests, budget_allocated,
                           budget_spent, budget_pct_used, efficiency_rank,
                           TO_CHAR(last_refreshed, 'YYYY-MM-DD HH24:MI') AS last_refreshed
                    FROM mv_dept_dashboard
                    ORDER BY efficiency_rank
                """)
                columns = [col[0].lower() for col in cur.description]
                return [dict(zip(columns, row)) for row in cur.fetchall()]
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=500, detail=str(e))

@router.post("/refresh")
def refresh_dashboard():
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("DBMS_MVIEW.REFRESH",
                             ["MV_DEPT_DASHBOARD", "C"])
                return {"message": "Dashboard refreshed"}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=500, detail=str(e))

@router.post("/snapshot")
def take_snapshot():
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("take_kpi_snapshot")
                conn.commit()
                return {"message": "KPI snapshot taken"}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=500, detail=str(e))
            
@router.post("/spend")
def record_spend(body: DepartmentSpendBody):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("ops_manager_pkg.department_spend", [
                    body.dept_id, body.user_id, body.amount
                ])
                conn.commit()
                return {"message": "Spend recorded"}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))