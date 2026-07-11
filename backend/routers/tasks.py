from fastapi import APIRouter, HTTPException
from database import get_connection
from schemas import AssignTaskBody, TaskActionBody
import oracledb
from datetime import datetime

router = APIRouter(prefix="/tasks", tags=["tasks"])

@router.post("/")
def assign_task(body: AssignTaskBody):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                due = datetime.strptime(body.due_date, "%Y-%m-%d").date() \
                      if body.due_date else None
                cur.callproc("supervisor_pkg.assign_task", [
                    body.created_by, body.assigned_to,
                    body.title, body.priority, due
                ])
                conn.commit()
                return {"message": "Task assigned"}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))

@router.patch("/{task_id}/complete")
def complete_task(task_id: int, body: TaskActionBody):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("employee_pkg.complete_task",
                             [body.actor_id, task_id])
                conn.commit()
                return {"message": "Task completed"}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))

@router.patch("/{task_id}/cancel")
def cancel_task(task_id: int, body: TaskActionBody):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("supervisor_pkg.cancel_task",
                             [body.actor_id, task_id])
                conn.commit()
                return {"message": "Task cancelled"}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))

@router.patch("/{task_id}/reopen")
def reopen_task(task_id: int, body: TaskActionBody):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("supervisor_pkg.reopen_task",
                             [body.actor_id, task_id])
                conn.commit()
                return {"message": "Task reopened"}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))