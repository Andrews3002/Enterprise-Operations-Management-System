from fastapi import APIRouter, HTTPException
from database import get_connection
from schemas import LogIncidentBody, ResolveIncidentBody
import oracledb

router = APIRouter(prefix="/incidents", tags=["incidents"])

@router.post("/")
def log_incident(body: LogIncidentBody):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                incident_id = cur.callfunc(
                    "employee_pkg.log_incident",
                    oracledb.NUMBER,
                    [body.dept_id, body.reported_by, body.title,
                     body.severity, body.description]
                )
                return {"incident_id": int(incident_id)}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))

@router.patch("/{incident_id}/resolve")
def resolve_incident(incident_id: int, body: ResolveIncidentBody):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("ops_manager_pkg.resolve_incident", [
                    incident_id,
                    body.resolved_by,
                    body.resolution
                ])
                conn.commit()
                return {"message": "Incident resolved"}
            except oracledb.DatabaseError as e:
                raise HTTPException(status_code=400, detail=str(e))