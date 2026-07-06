# Source Boundaries

Hawley starts as a mirror and reporting model.

## Asana

Asana remains the human execution source of truth for:

- task ownership
- due dates
- completion state
- comments
- subtasks
- final time tracking records

## Airtable

Airtable remains the human planning and control surface for:

- ECO intake and review
- cycle setup
- VIN and phase planning
- manual overrides
- high-level operational review

## Postgres

Postgres becomes the local authority for:

- mirrored source data
- cross-system joins
- heavy calculations
- historical snapshots
- worker-page reporting views
- sync logs and failure diagnosis

## Worker App Direction

The future worker app should read current assignments from Postgres and write
local timer/session events to Postgres first. A separate verified sync should
then push final time/completion records to Asana.
