# routers/requests.py
from fastapi import APIRouter, HTTPException
from database import get_connection
from schemas import SubmitRequestBody, DecideStageBody
import oracledb

router = APIRouter(prefix="/requests", tags=["requests"])

@router.post("/")
def submit_request(body: SubmitRequestBody):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                result = cur.var(oracledb.NUMBER)
                cur.callproc("employee_pkg.submit_request", [
                    body.emp_id,
                    body.workflow_id,
                    body.notes,
                    result
                ])
            except Exception:
                pass

    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                request_id = cur.callfunc(
                    "employee_pkg.submit_request",
                    oracledb.NUMBER,
                    [body.emp_id, body.workflow_id, body.notes]
                )
                return {"request_id": int(request_id)}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))

@router.post("/{request_id}/decide")
def decide_stage(request_id: int, body: DecideStageBody):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("supervisor_pkg.decide_stage", [
                    request_id,
                    body.decider_id,
                    body.decision,
                    body.comments
                ])
                conn.commit()
                return {"message": "Decision recorded"}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))

@router.get("/{request_id}/sla")
def get_sla_status(request_id: int):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                status = cur.callfunc(
                    "supervisor_pkg.get_sla_status",
                    oracledb.STRING,
                    [request_id]
                )
                return {"request_id": request_id, "sla_status": status}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))

@router.post("/escalate")
def escalate_overdue():
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("escalate_overdue")
                conn.commit()
                return {"message": "Escalation complete"}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))