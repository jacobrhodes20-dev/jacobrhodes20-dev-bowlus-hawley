# Hawley DigitalOcean App Hosting

Last verified: 2026-07-13 (America/Los_Angeles)

## Verified Production Origin

Hawley Admin is served by DigitalOcean App Platform at:

```text
https://bowlus-hawley-9s6iw.ondigitalocean.app/admin
```

Read-only verification on 2026-07-13 established that:

- `/admin` returned HTTPS `200`.
- Responses included a DigitalOcean App Platform origin identifier.
- `Cache-Control: no-cache` prevents the browser from treating the admin HTML
  as a long-lived cached artifact.
- The authenticated page identified itself as `Hawley Admin` and displayed the
  `hawley-true-phase-pacing-v1` model.
- The dashboard rendered the current cycle, phase pace projections, shop pace,
  remaining/capacity/expected/delta values, phase-cycle burn-down, and recovery
  debt.
- The application-level **Reload** control completed without an error and moved
  the displayed `Checked` timestamp from 7:25:48 AM to 7:45:04 AM.

The DigitalOcean droplet named `bowlus-tools` is active, but it is not the
verified web origin for Hawley Admin. Do not route Hawley deployment work to
that droplet merely because it is the account's general tools server.

## Refresh Semantics

The `Checked <timestamp>` value is the user-visible proof that the pacing model
has been evaluated by the hosted application. The **Reload** control requests a
fresh evaluation and updates that timestamp.

Do not confuse these separate events:

1. Reloading or re-rendering the browser page.
2. Running the hosted pacing evaluation, reflected by `Checked`.
3. Refreshing an upstream Asana/Airtable/Postgres source.

The production admin interface currently exposes an explicit Reload control.
This repository does not contain the DigitalOcean App Platform deployment spec
or enough production telemetry to assert a scheduled background evaluation
cadence. Any claimed automatic cadence must therefore be verified in the App
Platform component configuration or runtime logs before it is documented.

Operational expectation for admin pacing is:

- Use **Reload** when an immediate pacing evaluation is required.
- Treat a `Checked` timestamp older than five minutes during active operations
  as stale until the production component's automatic cadence is verified.
- Display and monitor upstream-source freshness separately from the page's
  evaluation timestamp.

## Functional Review Checklist

Use the authenticated production page and confirm:

1. The header shows `Hawley Admin` and the expected signed-in admin account.
2. The model label is the expected production version.
3. Cycle number, workday position, remaining days, and progress are populated.
4. Shop and phase cards contain load, completed, open, capacity, expected,
   delta, true-target, and cycle-target values.
5. The phase-cycle burn-down table and recovery-debt total render.
6. Selecting **Reload** advances `Checked` and produces no visible error.
7. The production URL returns HTTPS `200` with `Cache-Control: no-cache`.

## Deployment Boundaries

- Production web hosting: DigitalOcean App Platform.
- Production admin route: `/admin` on the verified App Platform origin.
- Historical pilot host: `SW_Machine`; not the current production web host.
- General DigitalOcean tools droplet: `bowlus-tools`; not the verified Hawley
  Admin origin.
- Secrets, App Platform environment variables, database credentials, and access
  tokens must remain in approved secret storage and must never be committed.

## Documentation Maintenance

Update this runbook whenever the App Platform app name, public URL, model label,
source-refresh mechanism, or automatic evaluation cadence changes. A deployment
change is not complete until this runbook and the README production-hosting
section agree with the live application.

