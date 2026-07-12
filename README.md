# Enterprise Operations & Workflow Management System

A full-stack internal business platform built to demonstrate enterprise-grade Oracle SQL and PL/SQL skills. The system manages multi-stage approval workflows, operational incident tracking, task management, department budgets, and real-time KPI reporting — modelled after internal platforms like ServiceNow or Jira Service Management.

---

## Tech Stack

| Layer    | Technology                          |
|----------|-------------------------------------|
| Database | Oracle Database 19c                 |
| Backend  | Python 3.12 · FastAPI · oracledb    |
| Frontend | React 18 · Recharts · Lucide        |

---

## System Overview

<img width="4480" height="2231" alt="Blank diagram" src="https://github.com/user-attachments/assets/23648881-e64a-4c3f-967b-d9d800418e5c" />

The system is built around five business domains:

- **Workflows** — configurable multi-stage approval chains with SLA enforcement and automatic escalation
- **Incidents** — severity-tiered operational issue tracking with auto-assignment to department managers
- **Tasks** — supervisor-to-subordinate task delegation with lifecycle management
- **Budgets** — per-department fiscal year allocations with spend tracking and utilisation reporting
- **KPI Logs** — daily snapshots enabling trend analysis and delta reporting across all departments

---

## Database Architecture

### Schema Design

12 tables across three dependency layers. All tables use `GENERATED ALWAYS AS IDENTITY` primary keys and enforce business rules through `CHECK` constraints rather than relying on application-layer validation.

**Foundation layer** (no foreign key dependencies): `roles`, `departments`, `workflows`

**Core layer**: `employees`, `workflow_stages`, `budgets`

**Operational layer**: `requests`, `decisions`, `incidents`, `tasks`, `kpi_logs`, `audit_logs`

The circular dependency between `departments` (which references a manager) and `employees` (which references a department) is handled by creating `departments` first without the FK constraint, then adding it after `employees` is created via `ALTER TABLE`.

### Normalization

The schema is in Third Normal Form throughout. Status values are enforced via `CHECK` constraints with explicit allowed-value lists rather than lookup tables, keeping query complexity low while still preventing invalid data at the database level.

### Indexing Strategy

Indexes target the three most common query patterns:

- **Status + timestamp composites** on `requests` and `incidents` — used by `escalate_overdue`, `request_aging_report`, and the SLA breach queries in `take_kpi_snapshot`
- **Foreign key columns** on `requests(submitted_by)`, `incidents(dept_id)`, `employees(dept_id)` — prevents full table scans on every JOIN
- **Composite index** `idx_incidents_sla` on `(status, reported_at)` — specifically tuned for the SLA breach detection query which filters on both columns simultaneously

---

## PL/SQL Architecture

### Package Design

Business logic is organized into four role-scoped packages. Each package is granted exclusively to its corresponding Oracle database role — employees cannot call supervisor procedures at the database level, not just the application level.

employee_pkg      →  role_employee
supervisor_pkg    →  role_supervisor
ops_manager_pkg   →  role_ops_manager
executive_pkg     →  role_executive

Two standalone procedures (`escalate_overdue`, `take_kpi_snapshot`) handle system-level batch operations and are called directly by the backend on a schedule.

### Key PL/SQL Features Demonstrated

**Packages with specs and bodies** — all business logic encapsulated, private helper functions (`get_first_stage`, `get_next_stage`) hidden from public interface

**Stored functions returning values** — `submit_request` and `log_incident` use `RETURNING ... INTO` and return the generated primary key to the caller

**Cursor-based batch processing** — `escalate_overdue` uses an explicit cursor to iterate overdue requests and escalate each one within a single transaction

**SYS_REFCURSOR returns** — all seven reporting functions in `executive_pkg` return open cursors, consumed by the FastAPI backend using `oracledb.CURSOR`

**MERGE statement** — `take_kpi_snapshot` uses `MERGE INTO kpi_logs` for an upsert pattern, writing today's snapshot if absent or updating it if already present

**Exception handling** — every public procedure and function has a `WHEN OTHERS THEN ROLLBACK; RAISE` block ensuring no partial commits. Business rule violations use `RAISE_APPLICATION_ERROR` with specific error codes (-20001 through -20010) and messages that propagate cleanly through the API layer to the frontend

**Transaction ownership** — the `log_audit` utility procedure never commits, leaving transaction control entirely to the calling procedure

### Window Functions Used

| Function | Location | Purpose |
|---|---|---|
| `RANK() OVER (ORDER BY ...)` | `dept_efficiency_report` | Rank departments by avg resolution time |
| `DENSE_RANK() OVER (PARTITION BY ...)` | `employee_workload_report` | Rank employees by task load within each department |
| `SUM() OVER (PARTITION BY ... ORDER BY ...)` | `incident_trend_report` | Running total of incidents per severity |
| `LAG()` | `workflow_bottleneck_report` | Compute dwell time between approval stages |
| `LAG()` | `dept_kpi_trend_report` | Day-over-day delta on open incidents and requests |
| `AVG() OVER (ROWS BETWEEN 2 PRECEDING ...)` | `dept_kpi_trend_report` | 3-day rolling average of open incidents |
| `RATIO_TO_REPORT()` | `budget_utilisation_report` | Each department's share of total company spend |

### Triggers

| Trigger | Type | Purpose |
|---|---|---|
| `trg_update_dept_manager_on_insert` | AFTER INSERT | Auto-sets `departments.manager_id` when an Ops Manager is hired |
| `trg_update_dept_manager_on_update` | AFTER UPDATE | Handles promotions, demotions, transfers, and deactivations |
| `trg_update_dept_manager_on_delete` | AFTER DELETE | Nulls `manager_id` when a manager is removed |
| `trg_one_ops_manager_per_dept` | COMPOUND TRIGGER | Enforces max one active Ops Manager per department |
| `trg_one_executive_per_dept` | COMPOUND TRIGGER | Enforces max one active Executive per department |
| `trg_assign_tasks_to_subordinates` | BEFORE INSERT | Prevents task assignment to peers or superiors |
| `trg_task_complete_or_reopen` | BEFORE UPDATE | Auto-stamps `completed_at` on DONE, clears it on reopen |
| `trg_audit_immutable` | BEFORE UPDATE/DELETE | Raises an error on any attempt to modify `audit_logs` |
| `trg_incident_resolve` | BEFORE UPDATE | Auto-stamps `resolved_at` when incident status changes to RESOLVED |
| `trg_request_resolve` | BEFORE UPDATE | Auto-stamps `resolved_at` on terminal request statuses |

Compound triggers are used for the one-per-department constraints to avoid the ORA-04091 mutating table error that would occur with a standard row-level trigger querying the same table being modified.

### Security Model

No application user has direct table access. All data mutations go through the role-scoped packages. The permission matrix:

| Capability | Employee | Supervisor | Ops Manager | Executive |
|---|---|---|---|---|
| Submit requests | ✓ | ✓ | ✓ | ✓ |
| Log incidents | ✓ | ✓ | ✓ | ✓ |
| Approve/reject stages | — | ✓ | ✓ | ✓ |
| Assign/manage tasks | — | ✓ | ✓ | ✓ |
| Resolve incidents | — | — | ✓ | — |
| Record dept spend | — | — | ✓ | — |
| View all reports | — | — | — | ✓ |
| Direct table SELECT | ✗ | ✗ | ✗ | ✗ |

### Materialized View

`mv_dept_dashboard` pre-aggregates incident counts, request counts, budget utilisation, and efficiency rankings across all departments. The frontend dashboard reads exclusively from this view rather than running live aggregation queries, giving sub-10ms dashboard loads regardless of data volume. Refreshed on demand via `DBMS_MVIEW.REFRESH`.

---

## API Reference

Base URL: `http://localhost:8000`

| Method | Endpoint | Package Called |
|---|---|---|
| POST | `/requests/` | `employee_pkg.submit_request` |
| POST | `/requests/{id}/decide` | `supervisor_pkg.decide_stage` |
| GET | `/requests/{id}/sla` | `supervisor_pkg.get_sla_status` |
| POST | `/requests/escalate` | `escalate_overdue` |
| POST | `/incidents/` | `employee_pkg.log_incident` |
| PATCH | `/incidents/{id}/resolve` | `ops_manager_pkg.resolve_incident` |
| POST | `/tasks/` | `supervisor_pkg.assign_task` |
| PATCH | `/tasks/{id}/complete` | `employee_pkg.complete_task` |
| PATCH | `/tasks/{id}/cancel` | `supervisor_pkg.cancel_task` |
| PATCH | `/tasks/{id}/reopen` | `supervisor_pkg.reopen_task` |
| GET | `/dashboard/` | `mv_dept_dashboard` |
| POST | `/dashboard/refresh` | `DBMS_MVIEW.REFRESH` |
| POST | `/dashboard/snapshot` | `take_kpi_snapshot` |
| POST | `/dashboard/spend` | `ops_manager_pkg.department_spend` |
| GET | `/reports/efficiency` | `executive_pkg.dept_efficiency_report` |
| GET | `/reports/budget` | `executive_pkg.budget_utilisation_report` |
| GET | `/reports/aging` | `executive_pkg.request_aging_report` |
| GET | `/reports/bottleneck` | `executive_pkg.workflow_bottleneck_report` |
| GET | `/reports/incidents/trend` | `executive_pkg.incident_trend_report` |
| GET | `/reports/workload` | `executive_pkg.employee_workload_report` |
| GET | `/reports/kpi-trend` | `executive_pkg.dept_kpi_trend_report` |

---

## Running Locally

**Prerequisites:** Oracle Autonomous Database (wallet-based), Python 3.12+, Node 20+

### Database Connection

This project connects to Oracle Autonomous Database using a wallet. The connection layer supports two environments automatically:

**Local development** — place your unzipped wallet folder at `backend/oracle_wallet/`. It is excluded from version control via `.gitignore`. Set your `.env`:

```env
DB_USER=ADMIN
DB_PASSWORD=your_db_password
DB_DSN=eomsdb_high
WALLET_PASSWORD=your_wallet_password
```

**Cloud deployment** — base64-encode your wallet zip and set it as an environment variable. The app decodes and extracts it to `/tmp/oracle_wallet` at startup:

```bash
# Encode your wallet zip (run once locally)
base64 -w 0 wallet.zip > wallet_b64.txt
```

Then set these environment variables on your deployment platform:

```env
DB_USER=ADMIN
DB_PASSWORD=your_db_password
DB_DSN=eomsdb_high
WALLET_PASSWORD=your_wallet_password
BASE64_WALLET_ZIP=<contents of wallet_b64.txt>
```

The connection module checks for `BASE64_WALLET_ZIP` first. If absent, it falls back to `./oracle_wallet`. If neither exists, startup fails with a clear error.

### Starting the App

```bash
# Backend
cd backend
pip install -r requirements.txt
uvicorn main:app --reload

# Frontend (separate terminal)
cd frontend
npm install
npm run dev
```

API docs available at `http://localhost:8000/docs`

---

## What This Project Demonstrates

Built to learn and showcase enterprise Oracle database development. Key skills evidenced:

- Designing normalized relational schemas with circular FK resolution
- Enterprise PL/SQL — packages, functions, procedures, cursors, exception handling, transaction management
- Compound triggers for complex business rule enforcement
- Advanced SQL — seven distinct window functions across analytical reporting queries
- Role-based database security with package-level grant enforcement
- Materialized views for pre-aggregated dashboard performance
- Connecting Oracle to a REST API via `oracledb` and exposing `SYS_REFCURSOR` results as JSON
- Building a functional React dashboard that consumes and visualizes real operational data