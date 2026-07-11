from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class SubmitRequestBody(BaseModel):
    emp_id: int
    workflow_id: int
    notes: Optional[str] = None

class DecideStageBody(BaseModel):
    decider_id: int
    decision: str
    comments: Optional[str] = None

class LogIncidentBody(BaseModel):
    dept_id: int
    reported_by: int
    title: str
    severity: str
    description: Optional[str] = None

class ResolveIncidentBody(BaseModel):
    resolved_by: int
    resolution: str

class AssignTaskBody(BaseModel):
    created_by: int
    assigned_to: int
    title: str
    priority: str
    due_date: Optional[str] = None

class TaskActionBody(BaseModel):
    actor_id: int

class DepartmentSpendBody(BaseModel):
    dept_id: int
    user_id: int
    amount: float