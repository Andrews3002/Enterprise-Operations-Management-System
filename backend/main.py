# main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from routers import requests, incidents, tasks, reports, dashboard

app = FastAPI(title="Enterprise Operations Management System API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "https://enterprise-operations-management-system-1.onrender.com"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return RedirectResponse(url="/dashboard")

app.include_router(requests.router)
app.include_router(incidents.router)
app.include_router(tasks.router)
app.include_router(reports.router)
app.include_router(dashboard.router)

@app.get("/health")
def health():
    return {"status": "ok"}