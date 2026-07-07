# Operational Capability Map

Hawley's operational capability map is not a company org chart. It is a
scheduling and routing model that helps Hawley understand where work usually
belongs, who is declared capable of the work, who has historically been assigned
to it, and who can act as a practical anchor when the model is uncertain.

## Sources

Hawley combines three signal types:

- Declared capability from Airtable `Work Force` skill-level fields.
- Observed assignment history from `Task Instances Rev1` normalized into
  `core.task_instances`.
- Manual operational owner hints loaded into
  `ops.manual_work_area_owner_hints`.

The model intentionally avoids formal HR reporting relationships. Use language
like "practical anchor", "routing candidate", "declared capability", and
"observed history" rather than "reports to".

## Work Force Level Fields

The first model reads these Airtable `Work Force` fields:

- `FAB SL`
- `CNC SL`
- `Frames SL`
- `Phase A SL`
- `Phase B SL`
- `Phase C SL`
- `Phase D SL`
- `Phase E SL`
- `Phase F SL`
- `Phase G SL`
- `Phase H SL`
- `QC / Inventory SL`

Hawley keeps the raw numeric level and assigns conservative routing bands:

- `primary_candidate`: level 4 or above
- `capable`: level 3
- `support`: level 1 through 2
- `not_declared`: blank or 0

These bands are deliberately lightweight until the Work Force level scheme is
defined more formally.

## Reporting Views

- `reporting.work_force_capability_levels`
- `reporting.task_work_area_inference`
- `reporting.assignee_work_history`
- `reporting.work_area_owner_hints`
- `reporting.worker_capability_map`
- `reporting.work_area_owners`

The two most useful first queries are:

```sql
select *
from reporting.worker_capability_map
where routing_signal <> 'unknown'
order by work_area_name, routing_confidence desc, worker_name;
```

```sql
select *
from reporting.work_area_owners
order by work_area_name, signal_score desc, worker_name;
```

## Manual Owner Hints

Manual hints belong in local data, not Git. The default loader path is:

```text
data/ops/work-area-owner-hints.csv
```

Expected CSV columns:

```csv
work_area_key,owner_person_name,owner_person_email,owner_role,confidence_label,source_label,notes,active
```

Load hints with:

```powershell
npm run pg:load:ops-hints
```

Use `--replace` when the local CSV should become the active manual-hint set.

```powershell
npm run pg:load:ops-hints -- --replace
```

## Current Work Areas

Initial work areas are:

- `installation_b_h`
- `frames_phase_a`
- `fab_1_3`
- `soqs`
- `inventory`
- `cnc`
- `management`
- `phase_a` through `phase_h`

The specific owner/person hints should be maintained in the local database or
ignored local CSV so private people data is not published in the repo.
