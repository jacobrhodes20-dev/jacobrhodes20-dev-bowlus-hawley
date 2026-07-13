# H.A.W.L.E. ("Hawley")

Historical Asana/Airtable Workflow Layer for Engineering.

Hawley is the local production engineering brain for Bowlus shop operations. It
is named after Hawley Bowlus, the aircraft designer and original Bowlus inventor.

The first version is a Postgres-backed mirror, calculation, and reporting layer
between Asana, Airtable, the Daily Worker App, dashboards, and Codex/agent tools.

## System Boundaries

- Asana remains the human task execution source of truth.
- Airtable remains the legacy/human-readable planning mirror during migration.
- Postgres becomes the fast local mirror, calculation layer, historical memory,
  and app-readable reporting model.
- Hawley reads source systems first, calculates locally, and only pushes selected
  summaries or verified time/completion data back after explicit implementation.

Phase 1 is mirror/read-model only. It does not perform live Asana or Airtable
writes.

## Production Hosting

The active Hawley Admin application is hosted by DigitalOcean App Platform:

- Production URL: `https://bowlus-hawley-9s6iw.ondigitalocean.app/admin`
- Verified: 2026-07-13
- Verified model label: `hawley-true-phase-pacing-v1`
- HTTP behavior: HTTPS `200`, `Cache-Control: no-cache`, and DigitalOcean App
  Platform origin headers

The DigitalOcean droplet named `bowlus-tools` is a separate server and is not
the verified Hawley Admin web origin. `SW_Machine` was the original pilot host;
the scripts and runbook that reference it are retained only as historical/local
pilot tooling and must not be treated as the production deployment path.

See `docs/runbooks/digitalocean-app-hosting.md` for the verified application
behavior, refresh semantics, and deployment boundaries.

## Repo Layout

```text
apps/postgres-sync/   Node sync/import scripts
db/migrations/        Versioned Postgres schema migrations
db/views/             Reporting and calculation SQL views
db/seeds/             Safe bootstrap-only seed files
docs/runbooks/        Setup, operations, backup, and recovery notes
scripts/              Local setup and health helpers
```

## First Commands

```powershell
npm install
npm run pg:health
npm run pg:migrate
npm run pg:pull:asana
npm run pg:refresh-worker-read-model
```

`pg:health` only checks the database connection. It does not contact Asana or
Airtable.

`pg:pull:asana` reads the `Fabrication - 2026` and `VINs - 2026` portfolios
from Asana and mirrors portfolios, portfolio-project membership, projects,
tasks, subtasks, custom fields, and task project/section memberships into the
local Postgres `raw` schema.

`pg:refresh-worker-read-model` is the fast worker-page path. It pulls Asana,
rebuilds HB tables, then pulls Daily Assignment Tracker snapshots read-only for
comparison/fallback. It does not pull or write Airtable.

`pg:watch:asana-events` is the one-minute pilot updater. It reads Asana project
events for the VINs/Fabrication portfolio projects, fetches changed task rows,
updates HB/Postgres, and rebuilds HB only when changed tasks are found. It does
not write to Asana or Airtable.

Hawley's operational capability map lives in the `ops` schema and reporting
views. It combines Airtable `Work Force` skill levels, observed Rev1/Asana task
assignment history, and local-only owner hints for scheduling/routing support.
See `docs/runbooks/operational-capability-map.md`.

The Rev1 Airtable field and calculation migration audit is documented in
`docs/runbooks/rev1-airtable-calculation-audit.md`.

The Hawley Brain Rev1 build path and HB-owned tables are documented in
`docs/runbooks/hawley-brain-rev1-build.md`.

The Hawley worker-page pilot runs beside the current Daily Worker App and reads
Postgres only. By default it uses the HB read model; set
`HAWLEY_WORKER_USE_DAT_SNAPSHOTS=true` only when intentionally comparing against
the legacy Daily Assignment Tracker snapshot shape:

```powershell
npm run worker:hawley
```

## Secret Rules

Do not commit:

- `.env`
- database passwords
- Airtable tokens
- Asana tokens
- raw data exports
- local runtime output
- backups

Use `.env.example` for variable names only.

