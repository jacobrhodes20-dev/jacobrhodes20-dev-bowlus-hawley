create or replace view reporting.hawley_cycle_calendar as
select
  cycle_number,
  cycle_label,
  start_date,
  end_date,
  days_in_cycle,
  to_jsonb(holidays) as holidays,
  source_synced_at as synced_at
from hb.cycles
where cycle_number is not null;
