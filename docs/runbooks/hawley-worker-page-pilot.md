# Hawley Worker Page Pilot

The Hawley worker page is a read-only pilot clone of the Daily Worker App. It
uses Hawley/Postgres instead of live Airtable and Asana tracker reads.

## Boundary

This pilot does not start timers, complete tasks, create Asana time tracking
entries, or refresh Daily Assignment Tracker. It reads local Hawley reporting
views only.

Timer and completion writes should be added only after Hawley has a first-class
worker session ledger and an approved Asana push path.

## Read Model

The app reads:

```sql
reporting.hawley_worker_page_assignments
reporting.work_force_capability_levels
```

That view enriches `reporting.daily_worker_assignments` with:

- source Asana permalink
- Airtable SOP/document links
- Asana completion state
- inferred work area from the operational capability map
- source sync timestamp

Manager mode uses active records directly from Airtable `Work Force`, mirrored
in `raw.airtable_work_force`, as the strict employee roster. Dated assignment
rows are attached only to those Work Force workers. This keeps old assignment
history or capability-map rows from adding stale people to the employee rail.

The browser assets in `apps/hawley-worker-page/public` are intentionally copied
from the current Shop Ops `apps/daily-worker-app` UI so the pilot looks and
behaves like the existing worker page while the backend reads Hawley/Postgres.

## Commands

Apply database migrations/views first:

```powershell
npm run pg:migrate
```

Refresh the read model after Airtable changes:

```powershell
npm run pg:pull:airtable
npm run pg:normalize
```

Refresh Asana completion/permalink context:

```powershell
npm run pg:pull:asana
```

Start the pilot:

```powershell
npm run worker:hawley
```

Default URL:

```text
http://127.0.0.1:5273
```

Worker pages use the familiar pattern:

```text
http://127.0.0.1:5273?employee=<worker-slug>
```

## API

```text
GET /api/health
GET /api/daily-assignments?date=YYYY-MM-DD
GET /api/daily-assignments?date=YYYY-MM-DD&employee=<worker-slug>
GET /api/auth-status
GET /api/alert-status
GET /api/refresh-daily-tracker
POST /api/refresh-daily-tracker
POST /api/worker-task-action
```

The `POST` endpoints intentionally return read-only pilot errors.

## Configuration

```text
HAWLEY_WORKER_HOST=127.0.0.1
HAWLEY_WORKER_PORT=5273
```

The app uses the same Postgres environment variables as the Hawley sync scripts:

```text
PGHOST
PGPORT
PGDATABASE
PGUSER
PGPASSWORD
DATABASE_URL
```

## Blank Task Triage

If the employee list appears but workers are blank, first check whether Hawley's
Airtable mirror is stale. The worker page reads `Assigned On` from mirrored
`Task Instances Rev1`, so a fresh assignment in Airtable will not show until
`pg:pull:airtable` and `pg:normalize` have run.
