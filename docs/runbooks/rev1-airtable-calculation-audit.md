# Rev1 Airtable Field And Calculation Migration Audit

Date: 2026-07-08

Purpose: document the Airtable Rev1 fields and the Shop Ops script calculations that Hawley must preserve before Airtable can become a legacy overnight mirror instead of the live calculation layer.

This audit is read-only. It uses Hawley's mirrored Airtable schema catalog plus local Shop Ops source scripts. No Airtable or Asana writes were performed.

2026-07-08 implementation update: Hawley now preserves the Airtable Rev1 raw payload, including hidden/metadata-discovered fields, as the legacy bootstrap while overlaying fresh Asana portfolio task truth into `hb.rev1_task_instances`. The cloned worker page reads HB first, so Airtable is no longer in the fast worker-page refresh path.

## Sources Reviewed

- Hawley live schema mirror: `raw.airtable_schema_fields`, `raw.airtable_*` tables.
- Shop Ops schema doc: `docs/airtable-schema/airtable-architecture-latest.md`.
- Shop Ops scripts:
  - `apps/airsync/AirSync.js`
  - `apps/airsync/AsanaAirtablePollSync.js`
  - `apps/airsync/ReconcileAsanaToTaskInstances.js`
  - `apps/airsync/MigrateTaskInstancesToDirectFields.js`
  - `apps/airsync/DownstreamRebuildSync.js`
  - `apps/rev1/rev1-rebuild-downstream.mjs`
  - `apps/airsync/DailyAssignmentSync.js`
  - `apps/daily-worker-app/server.js`
  - `apps/plh-engine/config.js`
  - `apps/plh-engine/engine.js`
- Hawley current Postgres layer:
  - `apps/postgres-sync/src/pull-airtable.js`
  - `apps/postgres-sync/src/normalize-airtable.js`
  - `db/migrations/001_init.sql`
  - `db/migrations/003_airtable_raw_support_tables.sql`
  - `db/migrations/008_worker_daily_actuals.sql`
  - `db/views/001_reporting_daily_worker_assignments.sql`
  - `db/views/003_hawley_worker_page.sql`
  - `db/views/004_hawley_cycle_calendar.sql`

## Current Airtable Mirror Coverage

Hawley currently mirrors the raw Airtable records and the full Airtable metadata schema for the tables below, including empty fields exposed by Airtable's metadata API.

| Table | Hawley raw table | Rows mirrored | Fields in schema | Role |
| --- | --- | ---: | ---: | --- |
| Task Instances Rev1 | `raw.airtable_task_instances` | 8324 | 90 | Operational Rev1 ledger |
| Phase Cycle Load Rev1 | `raw.airtable_phase_cycle_load` | 161 | 17 | Derived phase/cycle load table |
| Worker Phase Allocation Rev1 | `raw.airtable_worker_phase_allocation` | 258 | 20 | Derived worker/cycle/phase allocation table |
| Worker Cycle Bank Rev1 | `raw.airtable_worker_cycle_bank` | 178 | 11 | Derived worker/cycle capacity bank |
| Worker Daily Task Actuals | `raw.airtable_worker_daily_actuals` | 211 | 30 | Worker timer and daily efficiency ledger |
| Work Force | `raw.airtable_work_force` | 18 | 33 | Worker identity, active state, skill levels, efficiency |
| Cycles | `raw.airtable_cycles` | 25 | 21 | Cycle dates, workdays, capacity, cycle progress |
| Phases | `raw.airtable_phases` | 20 | 20 | Phase labels, order, aliases, grouping metadata |

Important finding: the current Rev1 tables themselves do not expose Airtable `formula`, `rollup`, or `lookup` field types in the live schema mirror. The calculations are materialized into ordinary fields by scripts. The migration work is therefore to port the script logic and validate output parity, not just translate Airtable formulas.

## Task Instances Rev1 Field Inventory

The current live schema has 90 fields. `Load Type` is present in Hawley's live schema and was not in the older ordered architecture doc, so it is included here.

| Field | Type | Populated rows | Primary owner |
| --- | --- | ---: | --- |
| Active In Production? | checkbox | 7903 | Rev1 clean/align |
| Actual Efficiency | number | 1591 | AirSync/Reconcile calculated |
| Actual time | duration | 3213 | Asana actual time mirror |
| AirTableKey | singleLineText | 8317 | Rev1/Airtable identity |
| Allocated Hours | number | 8307 | Asana planning calculation |
| Asana AirTableKey | singleLineText | 4144 | Asana custom field mirror |
| Asana Due Date | singleLineText | 7119 | Asana due date mirror or schedule alias |
| Asana Portfolio GID | singleLineText | 2748 | Asana import |
| Asana Portfolio Name | singleLineText | 2748 | Asana import |
| Asana Project GID | singleLineText | 8324 | Asana import |
| Asana Project Name | singleLineText | 8317 | Asana import |
| Asana Push Result | multilineText | 0 | Scheduler proposal output |
| Asana Push Status | singleSelect | 0 | Scheduler proposal output |
| Asana Pushed At | singleLineText | 0 | Scheduler proposal output |
| Asana Section | singleLineText | 8317 | Asana import/clean |
| Asana Task GID | singleLineText | 8324 | Asana identity |
| Assigned On | date | 5173 | DAT visibility date |
| Assigned Worker | multipleRecordLinks | 7445 | Asana assignee mapped to Work Force |
| Assignee Email | email | 7837 | Asana import |
| Assignee Name | singleLineText | 7837 | Asana import |
| Attachment summary | multilineText | 80 | Task/document import |
| Competed Est. Hours | number | 6114 | Asana planning calculation |
| Completed On | date | 6255 | Asana completion mirror |
| Current Skill Level (Scheduler) | number | 0 | Scheduler proposal output |
| Cycle | multipleRecordLinks | 7912 | Production/Asana schedule link |
| Cycle Label | singleLineText | 8005 | Asana/custom label |
| Days in Cycle | number | 4303 | Cycle context |
| Diagrams & Utilities | multipleAttachments | 80 | Task/document import |
| Document Link | url | 1075 | Task/document import |
| Email | email | 7845 | Cleaned assignee alias |
| End Date | date | 7902 | Production schedule context |
| Est Time Remaining (Project) | duration | 6113 | Asana/custom project field |
| Estimated Batch Task Time | duration | 8308 | Asana planning calculation |
| Estimated Task Time | duration | 7387 | Asana planning calculation |
| Inherited From Parent? | checkbox | 965 | Rev1 clean/structure |
| Is Subtask | checkbox | 2336 | Asana import |
| Last Synced At | singleLineText | 8302 | Sync bookkeeping |
| Line Schedule | multipleRecordLinks | 7906 | Production schedule link |
| Load Delta Hours (Scheduler) | number | 0 | Scheduler proposal output |
| Load Type | singleLineText | 8 | Load/schedule classification |
| Model | singleLineText | 2406 | Production/Asana import |
| Model Type | singleLineText | 3848 | Cleaned model alias |
| Open Est. Hours | number | 6120 | Asana planning calculation |
| Overskill (Scheduler) | number | 0 | Scheduler proposal output |
| Parent Asana Task GID | singleLineText | 2348 | Asana hierarchy |
| Parent Task | singleLineText | 2348 | Cleaned parent alias |
| Parent Task Name | singleLineText | 2348 | Asana hierarchy |
| Phase | multipleRecordLinks | 7912 | Production/phase link |
| Phase Cycle Load | multipleRecordLinks | 7912 | Derived support link |
| Phase Cycle Load Rev1 | multipleRecordLinks | 7912 | Derived support link |
| Phase Label | singleLineText | 8310 | Asana/custom phase label |
| PhaseCycleBucketKey | singleLineText | 7911 | Phase/cycle grouping key |
| PhaseCycleKey | singleLineText | 7911 | Cleaned alias of PhaseCycleBucketKey |
| Production Match Status | singleSelect | 8309 | Rev1 align/clean |
| Proposed End Date | date | 0 | Scheduler proposal output |
| Proposed Skill Level (Scheduler) | number | 0 | Scheduler proposal output |
| Proposed Start Date | date | 0 | Scheduler proposal output |
| Proposed Worker | singleLineText | 0 | Scheduler proposal output |
| Proposed Worker Record ID | singleLineText | 0 | Scheduler proposal output |
| Push To Asana? | checkbox | 0 | Scheduler proposal output |
| Quantity | number | 7669 | Asana planning mirror |
| Required Skill (Scheduler) | number | 0 | Scheduler proposal output |
| Rev1 Import Notes | multilineText | 8309 | Rev1 import/align notes |
| Scheduler Baseline Snapshot ID | singleLineText | 0 | Scheduler proposal output |
| Scheduler Locked? | checkbox | 0 | Scheduler proposal output |
| Scheduler Mode | singleLineText | 0 | Scheduler proposal output |
| Scheduler Notes | multilineText | 0 | Scheduler proposal output |
| Scheduler Score | number | 0 | Scheduler proposal output |
| Scheduler Snapshot ID | singleLineText | 0 | Scheduler proposal output |
| Scheduler Status | singleSelect | 0 | Scheduler proposal output |
| Scheduling Evaluated At | singleLineText | 0 | Scheduler proposal output |
| Scheduling Scope | singleLineText | 0 | Scheduler proposal output |
| Section/Column | singleLineText | 8317 | Normalized phase/work-area label |
| Skill Gap (Scheduler) | number | 0 | Scheduler proposal output |
| Start Date | date | 7902 | Production schedule context |
| Status | singleSelect | 8321 | UI/status alias |
| Sync Status | checkbox | 8308 | Sync bookkeeping |
| Task Completed? | checkbox | 6255 | Asana completion mirror |
| Task Description | multilineText | 270 | Asana/task definition import |
| Task Instance Rev1 Key | singleLineText | 8317 | Rev1 identity key |
| Task Name | singleLineText | 8313 | Asana/task definition import |
| Task Order | number | 8308 | Production/task ordering |
| Task Status | singleLineText | 8324 | Status alias |
| Task Type | singleLineText | 8316 | Asana/task classification |
| Tasks | multipleRecordLinks | 6614 | Task definition link |
| TasksKey | singleLineText | 6646 | Task definition identity |
| VIN | number | 5364 | VIN/schedule context |
| VIN Record | multipleRecordLinks | 5589 | VIN table link |
| Worker Phase Allocation | multipleRecordLinks | 5857 | Derived support link |
| Worker Phase Allocation Rev1 | multipleRecordLinks | 5857 | Derived support link |

## Derived Rev1 Support Table Inventories

### Phase Cycle Load Rev1

| Field | Type | Populated rows | Calculation owner |
| --- | --- | ---: | --- |
| Completed Task Hours | number | 161 | Rev1 downstream rebuild |
| Completion % | percent | 161 | Rev1 downstream rebuild |
| Coverage % | percent | 161 | Rev1 downstream rebuild |
| Cycle | multipleRecordLinks | 161 | Rev1 downstream rebuild |
| Export Allocations | multipleRecordLinks | 59 | Rev1 downstream rebuild |
| Exported Hours | number | 161 | Rev1 downstream rebuild |
| Hours Per Day | number | 161 | Rev1 downstream rebuild |
| Import Allocations | multipleRecordLinks | 58 | Rev1 downstream rebuild |
| Imported Hours | number | 161 | Rev1 downstream rebuild |
| Phase | multipleRecordLinks | 161 | Rev1 downstream rebuild |
| PhaseCycleBucketKey | singleLineText | 161 | Rev1 downstream rebuild |
| Remaining Task Hours | number | 161 | Rev1 downstream rebuild |
| Status | singleLineText | 161 | Rev1 downstream rebuild |
| Task Instances Rev1 | multipleRecordLinks | 151 | Rev1 downstream rebuild |
| Tasks | multipleRecordLinks | 151 | Rev1 downstream rebuild |
| Total Load Hrs. | number | 161 | Rev1 downstream rebuild |
| Worker Phase Allocation Rev1 | multipleRecordLinks | 148 | Rev1 downstream rebuild |

### Worker Phase Allocation Rev1

| Field | Type | Populated rows | Calculation owner |
| --- | --- | ---: | --- |
| Assigned Hours | number | 258 | Rev1 downstream rebuild |
| Cross-Phase Support? | singleLineText | 258 | Rev1 downstream rebuild |
| Cycle | multipleRecordLinks | 258 | Rev1 downstream rebuild |
| Exported Hours | number | 258 | Rev1 downstream rebuild |
| Home Phase | singleLineText | 244 | Rev1 downstream rebuild |
| Home Phase Text | singleLineText | 244 | Rev1 downstream rebuild |
| Imported Hours | number | 258 | Rev1 downstream rebuild |
| Is Home Phase? | number | 258 | Rev1 downstream rebuild |
| Phase Cycle Load | multipleRecordLinks | 258 | Rev1 downstream rebuild |
| Phase Cycle Load Rev1 | multipleRecordLinks | 92 | Rev1 downstream rebuild |
| Phase Cycle Load Rev1 (2) | multipleRecordLinks | 92 | Rev1 downstream rebuild |
| PhaseCycleBucketKey | singleLineText | 258 | Rev1 downstream rebuild |
| Task Instances | multipleRecordLinks | 258 | Rev1 downstream rebuild |
| Task Instances Rev1 | multipleRecordLinks | 258 | Rev1 downstream rebuild |
| Worked Phase | multipleRecordLinks | 258 | Rev1 downstream rebuild |
| Worked Phase Text | singleLineText | 258 | Rev1 downstream rebuild |
| WorkedBucketKey | singleLineText | 258 | Rev1 downstream rebuild |
| Worker | multipleRecordLinks | 258 | Rev1 downstream rebuild |
| Worker Cycle Bank Rev1 | multipleRecordLinks | 258 | Rev1 downstream rebuild |
| WorkerCyclePhaseKey | singleLineText | 258 | Rev1 downstream rebuild |

### Worker Cycle Bank Rev1

| Field | Type | Populated rows | Calculation owner |
| --- | --- | ---: | --- |
| Actively Employed | checkbox | 178 | Rev1 downstream rebuild |
| Assigned Hours Total | number | 178 | Rev1 downstream rebuild |
| Cycle | multipleRecordLinks | 178 | Rev1 downstream rebuild |
| Cycle Capacity | number | 178 | Rev1 downstream rebuild |
| Days In Cycle | number | 178 | Rev1 downstream rebuild |
| Effective Hours Bank | number | 178 | Rev1 downstream rebuild |
| Efficiency Factor | number | 178 | Rev1 downstream rebuild |
| Remaining Hours | number | 178 | Rev1 downstream rebuild |
| Worker | multipleRecordLinks | 178 | Rev1 downstream rebuild |
| WorkerCycleKey | singleLineText | 178 | Rev1 downstream rebuild |
| WPA Records | multipleRecordLinks | 178 | Rev1 downstream rebuild |

### Worker Daily Task Actuals

| Field | Type | Populated rows | Calculation owner |
| --- | --- | ---: | --- |
| Actual Minutes | number | 211 | Worker page timer ledger |
| Allocated Hours | number | 209 | Worker page timer ledger |
| Asana Posted Minutes | number | 211 | Worker page timer ledger |
| Asana Task GID | singleLineText | 211 | Worker page timer ledger |
| Assigned Hours | number | 209 | Worker page timer ledger |
| Completed? | checkbox | 114 | Worker page timer ledger |
| Cycle | singleLineText | 209 | Worker page timer ledger |
| Daily Available Minutes | number | 197 | Worker page daily efficiency |
| Daily Efficiency Percent | number | 197 | Worker page daily efficiency |
| Daily Efficiency Under 75? | checkbox | 79 | Worker page daily efficiency |
| Daily Logged Minutes | number | 197 | Worker page daily efficiency |
| Daily Summary? | checkbox | 40 | Worker page daily efficiency |
| Efficiency Snapshot At | dateTime | 197 | Worker page daily efficiency |
| Last Seen At | dateTime | 211 | Worker page timer ledger |
| Ledger Key | singleLineText | 211 | Worker page timer ledger |
| Notes | multilineText | 211 | Worker page timer ledger |
| Phase | singleLineText | 209 | Worker page timer ledger |
| Review Month | singleLineText | 197 | Worker page daily efficiency |
| Review Year | number | 197 | Worker page daily efficiency |
| Source | singleLineText | 211 | Worker page timer ledger |
| Task Name | singleLineText | 211 | Worker page timer ledger |
| Task URL | url | 171 | Worker page timer ledger |
| Timer Minutes | number | 211 | Worker page timer ledger |
| VIN | singleLineText | 166 | Worker page timer ledger |
| Was Assigned In DAT? | checkbox | 211 | Worker page timer ledger |
| Was Recovered? | checkbox | 2 | Worker page recovery path |
| Work Date | date | 211 | Worker page timer ledger |
| Worker Email | email | 211 | Worker page timer ledger |
| Worker Key | singleLineText | 211 | Worker page timer ledger |
| Worker Name | singleLineText | 211 | Worker page timer ledger |

## Support Tables Required For Equivalent Calculations

`Work Force` must stay in Hawley because it drives worker identity, active employment, capacity, skill levels, and home phase logic.

Critical Work Force fields:

- Identity and status: `Name`, `Assignee`, `Actively Employed`.
- Capacity: `Hours Per Day`, `Efficiency Factor`, `Ideal Efficiency Factor`.
- Skill levels: `FAB SL`, `CNC SL`, `Frames SL`, `Phase A SL`, `Phase B SL`, `Phase C SL`, `Phase D SL`, `Phase E SL`, `Phase F SL`, `Phase G SL`, `Phase H SL`, `QC / Inventory SL`.
- Home/default work area: `Primary Phase (Legacy)`, `Home Section/Column`.
- Links: `Task Instances Rev1`, `Worker Phase Allocation Rev1`, `Worker Cycle Bank Rev1`.

`Cycles` must stay in Hawley because it drives cycle calendar, capacity, and cycle progress.

Critical Cycles fields:

- Identity/date: `Cycle Number`, `Start Date`, `End Date`, `Sequence`, `Quarter`.
- Capacity: `Days In Cycle`, `Hours Per Workday`, `Cycle Capacity`.
- Calendar/progress: `Holidays`, `Cycle %`.
- Links: `Task Instances Rev1`, `Phase Cycle Load Rev1`, `Worker Phase Allocation Rev1`, `Worker Cycle Bank Rev1`.

`Phases` must stay in Hawley because it drives grouping, work-area inference, and cross-phase support.

Critical Phases fields:

- Identity/grouping: `Name`, `Section/Column`, `Process Order`, `Installation Phase`.
- Scheduling offsets: `Task Offset`, `Backfill Odd`, `Backfill Even`, `Group Size`, `Parity Mode`.
- Links: `Work Force`, `Tasks`, `Task Instances Rev1`, `Phase Cycle Load Rev1`, `Worker Phase Allocation Rev1`.

## Script Calculation Ownership

### Asana To Task Instances Rev1

Primary scripts reviewed: `AirSync.js`, `AsanaAirtablePollSync.js`, `ReconcileAsanaToTaskInstances.js`.

Existing behavior:

- `Task Completed?` mirrors Asana `completed`, with parent completion inherited when the child is not directly completed but the parent is.
- `Completed On` mirrors `completed_at`, also inheriting parent completed date when parent completion is used.
- `Actual time` mirrors Asana `actual_time_minutes * 60`.
- `Asana Due Date` mirrors Asana `due_on`.
- `Assigned Worker` maps Asana assignee email through `Work Force.Assignee`.
- `Assigned On` is legacy bidirectional:
  - `AirSync.js` can push Airtable `Assigned On` into the Asana custom field.
  - `AsanaAirtablePollSync.js` can pull Asana `Assigned On` back into Airtable.
- `Quantity`, `Estimated Task Time`, `Estimated Batch Task Time`, `Allocated Hours`, `Competed Est. Hours`, `Open Est. Hours`, `Actual Efficiency`, `Phase Label`, `Cycle Label`, and `VIN` are planning/custom-field mirrors or calculations from Asana task custom fields.

Current AirSync planning formulas:

- `quantity = Asana custom field "Quantity"`.
- `estimated_seconds = Asana "Estimated time" minutes * 60`.
- `estimated_batch_seconds = Asana "Estimated Time (w/ Qty)" minutes * 60`, or `estimated_minutes * quantity * 60` when the w/quantity field is absent.
- `allocated_hours = estimated_batch_minutes / 60`, rounded to 2 decimals.
- `completed_est_hours = allocated_hours` when complete, otherwise `0`.
- `open_est_hours = 0` when complete, otherwise `allocated_hours`.
- `actual_time_seconds = Asana actual_time_minutes * 60`.
- `actual_efficiency = actual_time_seconds / estimated_batch_seconds`, rounded to 2 decimals.
- `PhaseCycleBucketKey = "C" + cycle_number + "-" + phase_section`.

Decision on 2026-07-08: keep `Actual Efficiency` as the current AirSync batch-based calculation for legacy compatibility: `actual_time_seconds / estimated_batch_task_time_seconds`. This field is expected to become secondary as worker timer and average-time models mature.

### Rev1 Clean And Structure

Primary script reviewed: `apps/rev1/rev1-clean-and-structure.mjs`.

Existing behavior:

- Subtasks inherit parent schedule context when missing: `Line Schedule`, `Phase`, `Cycle`, `VIN Record`, `VIN`, `Phase Label`, `Cycle Label`, `Start Date`, `End Date`, `PhaseCycleBucketKey`, `Asana Section`.
- Display aliases are backfilled:
  - `Status = Completed` or `Not Started`.
  - `Task Status = Completed` or `Open`.
  - `Model Type = Model`.
  - `Email = Assignee Email`.
  - `Section/Column = normalizePhaseAlias(Asana Section or Phase Label)`.
  - `Parent Task = Parent Task Name`.
  - `PhaseCycleKey = PhaseCycleBucketKey`.
  - `Asana Due Date = End Date`.
  - `Production Match Status = Matched` when active schedule links are present, otherwise `Out of Production Scope`.
  - `Active In Production? = true` when `Line Schedule`, `Phase`, and `Cycle` are all present.

### Phase Cycle Load Rev1

Primary script reviewed: `apps/rev1/rev1-rebuild-downstream.mjs`.

Recommended behavior to port into Hawley:

- Group all task instance rows by linked `Phase` plus linked `Cycle`.
- Use `Estimated Batch Task Time / 3600` as the task's load hours.
- `Total Load Hrs. = sum(batch_hours)`.
- `Completed Task Hours = sum(batch_hours where Task Completed? = true)`.
- `Remaining Task Hours = sum(batch_hours where Task Completed? = false)`.
- `Completion % = Completed Task Hours / Total Load Hrs.`, or 0 when total is 0.
- `Coverage %` is currently set equal to `Completion %` in the newer rebuild script.
- `Status = At Risk` when completion is below `Cycles.Cycle %`, otherwise `On Track`.
- `Hours Per Day = 7.17`.
- Create signal-only phase/cycle rows when import/export allocations exist without direct tasks.
- Link matching task rows back through `Phase Cycle Load` / `Phase Cycle Load Rev1`.

Older `DownstreamRebuildSync.js` used materialized task fields (`Allocated Hours`, `Competed Est. Hours`, `Open Est. Hours`) and grouped by `PhaseCycleBucketKey`. This remains useful as a compatibility reference, but the newer Rev1 rebuild is the better migration source.

### Worker Phase Allocation Rev1

Primary script reviewed: `apps/rev1/rev1-rebuild-downstream.mjs`.

Recommended behavior to port into Hawley:

- Group task instance rows by `Worker + Cycle + Worked Phase`.
- Skip rows without worker, phase, or cycle after phase/cycle load is counted.
- `Assigned Hours = sum(batch_hours)` for that worker/cycle/phase.
- Worker home phase comes from `Work Force.Home Section/Column`, normalized by the rebuild script.
- `Worked Phase Text` is the normalized phase name for the task's linked phase.
- `Home Phase Text` is the normalized worker home phase.
- `Is Home Phase? = 1` when worked phase equals home phase, otherwise 0.
- `Cross-Phase Support? = Yes` when a worker is doing work outside home phase.
- `Imported Hours = Assigned Hours` when cross-phase, otherwise 0.
- `Exported Hours = Assigned Hours` when cross-phase, otherwise 0.
- `PhaseCycleBucketKey` points to the home phase/cycle key for cross-phase support, otherwise the worked phase/cycle key.
- `WorkedBucketKey` points to the worked phase/cycle key.
- Link to `Phase Cycle Load` for the worked phase/cycle.

The parity helper maps home phases into cycle-specific phase records:

- `Phase A` maps to `A1` on even cycles and `A2` on odd cycles.
- `CNC`, `FAB`, and `Frames` map to `CNC-A/B`, `FAB-A/B`, and `Frame-A/B` by cycle parity.

### Worker Cycle Bank Rev1

Primary script reviewed: `apps/rev1/rev1-rebuild-downstream.mjs`.

Recommended behavior to port into Hawley:

- Group task instance rows by `Worker + Cycle`.
- `Assigned Hours Total = sum(batch_hours)`.
- `Cycle Capacity = Cycles.Cycle Capacity`.
- `Days In Cycle = Cycles.Days In Cycle`.
- `Efficiency Factor = Work Force.Efficiency Factor`, defaulting to 1.
- `Actively Employed = Work Force.Actively Employed`.
- `Effective Hours Bank = Cycle Capacity * Efficiency Factor` when actively employed, otherwise 0.
- `Remaining Hours = Effective Hours Bank - Assigned Hours Total`.
- Link all matching WPA rows through `WPA Records`.

### Daily Assignment Tracker / Worker Page Source

Primary script reviewed: `apps/airsync/DailyAssignmentSync.js`.

Existing behavior:

- Direct Airtable inputs are `Cycles`, `Work Force`, `Task Instances Rev1`, `Phase Cycle Load Rev1`, `Worker Cycle Bank Rev1`, and `Phases`.
- Worker page visibility is driven by `Assigned On == tracker date`, plus an assigned worker and an Asana task GID.
- Current cycle is determined from `Cycles.Start Date`, `Cycles.End Date`, `Days In Cycle`, and `Holidays`.
- Cycle progress is computed from business days, holidays, and America/Los_Angeles date handling.
- Worker summaries use task `Estimated Task Time`, `Actual time`, `Task Completed?`, `Assigned On`, and worker bank capacity fields.
- Phase summaries use PCL `Total Load Hrs.`, `Completed Task Hours`, `Remaining Task Hours`, and `Completion %`.
- Worker snapshots use WCB `Remaining Hours`, `Effective Hours Bank`, `Cycle Capacity`, and per-task `Estimated Task Time`, `Task Order`, `VIN`, `Section/Column`, `PhaseCycleBucketKey`.

### Worker Daily Task Actuals

Primary script reviewed: `apps/daily-worker-app/server.js`.

Existing behavior:

- Ledger key is `worker/task/date`.
- On timer stop/complete, the app upserts `Worker Daily Task Actuals`.
- Task-level ledger writes include worker identity, Asana task GID, task URL, VIN, cycle, phase, assigned/allocated hours, actual minutes, timer minutes, Asana-posted minutes, completed flag, source, recovery flags, notes, and last-seen timestamp.
- Daily summary writes use task ID `__daily__`.
- Daily efficiency calculation:
  - `Daily Available Minutes = elapsedScheduledWorkMinutesForDate(date, now)`.
  - `Daily Logged Minutes = workerLoggedMinutesForDate(worker, date, now)`.
  - `Daily Efficiency Percent = round(logged / available * 100)`, or 0 when available is 0.
  - `Daily Efficiency Under 75? = available > 0 and percent < 75`.

### PLH / Reporting Consumers

Primary scripts reviewed: `apps/plh-engine/config.js`, `apps/plh-engine/engine.js`.

PLH and dashboard/reporting consumers depend on these fields remaining semantically identical:

- PCL: `Remaining Task Hours`, `Total Load Hrs.`, `Completed Task Hours`, `Coverage %`.
- Task Instances Rev1: `Actual Efficiency`, `Estimated Task Time`, `Actual time`, `Task Completed?`, `Completed On`, `PhaseCycleBucketKey`, `Phase`, `Cycle`.
- Worker assist metrics: `Worker Phase Allocation Rev1`, especially cross-phase/import/export fields.

## Current Hawley/Postgres Gaps

Hawley is currently safe as a raw mirror but not yet equivalent to Airtable as the Rev1 calculation brain.

What is already covered:

- Raw Airtable JSON for all reviewed tables is stored in `raw.airtable_*`.
- Airtable metadata is stored in `raw.airtable_schema_tables` and `raw.airtable_schema_fields`.
- `core.task_instances` normalizes a small worker-page subset.
- `reporting.hawley_worker_page_assignments` supports the cloned worker page.
- `reporting.hawley_cycle_calendar` now supplies the worker page cycle chip rail from Hawley's DB.

What is missing:

- No full relational `Task Instances Rev1` model with all 90 fields.
- No DB-owned calculation model for `Phase Cycle Load Rev1`.
- No DB-owned calculation model for `Worker Phase Allocation Rev1`.
- No DB-owned calculation model for `Worker Cycle Bank Rev1`.
- `Worker Daily Task Actuals` is mirrored raw but not yet normalized into a first-class timer ledger.
- `Work Force`, `Cycles`, and `Phases` are raw JSON plus a few reporting views, not a complete calculation model.
- The cloned worker page still depends on fields that are sourced from Airtable mirror snapshots, not Hawley-computed outputs from fresh Asana task data.

## Recommended Hawley Migration Path

1. Create normalized relational tables or views for the source tables:
   - `core.rev1_task_instances`
   - `core.work_force`
   - `core.cycles`
   - `core.phases`
   - `core.worker_daily_task_actuals`

2. Create Hawley-owned calculation outputs:
   - `calc.phase_cycle_load_rev1`
   - `calc.worker_phase_allocation_rev1`
   - `calc.worker_cycle_bank_rev1`

3. Port calculation logic in this order:
   - Asana custom-field normalization into Task Instances Rev1 fields.
   - Rev1 clean/structure alias fields.
   - PCL rebuild.
   - WPA rebuild.
   - WCB rebuild.
   - Worker Daily Task Actuals normalization and daily efficiency calculation.
   - Daily Assignment worker snapshot/read model.

4. Keep Airtable as a validation target at first:
   - Compare Hawley `core.rev1_task_instances` against Airtable `Task Instances Rev1` by `Asana Task GID` and `Task Instance Rev1 Key`.
   - Compare Hawley PCL against Airtable PCL by `PhaseCycleBucketKey`.
   - Compare Hawley WPA against Airtable WPA by `WorkerCyclePhaseKey`.
   - Compare Hawley WCB against Airtable WCB by `WorkerCycleKey`.
   - Compare worker actuals by `Ledger Key`.
   - Use rounding tolerances for hours/percent fields.

5. Once parity is proven, switch runtime dependency order:
   - Asana feeds Hawley frequently.
   - Hawley computes the worker page and reporting views.
   - Airtable receives an overnight or low-priority legacy mirror.

## Validation Checklist

Before calling Hawley equivalent to Airtable for Rev1 calculations:

- `Task Instances Rev1` row count and active scope count match expected Asana portfolio scope.
- Every Asana-backed row has one canonical `Asana Task GID`.
- `Task Completed?`, `Completed On`, `Actual time`, `Asana Due Date`, `Assigned Worker`, and `Assigned On` match the chosen source-of-truth direction.
- `Allocated Hours`, `Competed Est. Hours`, `Open Est. Hours`, and `Actual Efficiency` match the selected formula definitions.
- PCL totals match by `PhaseCycleBucketKey`.
- WPA totals and cross-phase flags match by `WorkerCyclePhaseKey`.
- WCB capacity and remaining hours match by `WorkerCycleKey`.
- Worker page tasks match by `Assigned On`, worker, and task GID.
- Worker Daily Task Actuals match by `Ledger Key`.
- PLH outputs use Hawley views and produce the same high-priority outlier/carryover signals.

## Open Decisions

- Decide final source of truth for `Assigned On`. Existing scripts support both directions; the target architecture should make this explicit.
- Decide whether Scheduler proposal fields stay in Airtable only for now or become Hawley planning tables.

## Resolved Decisions

- PCL/WPA/WCB are now implemented as persisted HB calculation tables so they can be diffed against Airtable and later mirrored back to Airtable as a human-readable interface.
