from fastapi import APIRouter, HTTPException
from database import get_connection
import oracledb

router = APIRouter(prefix="/reports", tags=["reports"])

def fetch_refcursor(func_name: str, args: list = []) -> list[dict]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            ref = cur.callfunc(func_name, oracledb.CURSOR, args)
            columns = [col[0].lower() for col in ref.description]
            return [dict(zip(columns, row)) for row in ref]

@router.get("/efficiency")
def dept_efficiency():
    try:
        return fetch_refcursor("executive_pkg.dept_efficiency_report")
    except oracledb.DatabaseError as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/workload")
def employee_workload():
    try:
        return fetch_refcursor("executive_pkg.employee_workload_report")
    except oracledb.DatabaseError as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/incidents/trend")
def incident_trend():
    try:
        return fetch_refcursor("executive_pkg.incident_trend_report")
    except oracledb.DatabaseError as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/bottleneck")
def workflow_bottleneck():
    try:
        return fetch_refcursor("executive_pkg.workflow_bottleneck_report")
    except oracledb.DatabaseError as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/budget")
def budget_utilisation():
    try:
        return fetch_refcursor("executive_pkg.budget_utilisation_report")
    except oracledb.DatabaseError as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/aging")
def request_aging():
    try:
        return fetch_refcursor("executive_pkg.request_aging_report")
    except oracledb.DatabaseError as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/kpi-trend")
def kpi_trend():
    try:
        return fetch_refcursor("executive_pkg.dept_kpi_trend_report")
    except oracledb.DatabaseError as e:
        raise HTTPException(status_code=500, detail=str(e))