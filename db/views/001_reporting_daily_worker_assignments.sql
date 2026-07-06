create or replace view reporting.daily_worker_assignments as
select
  ti.id as task_instance_id,
  ti.worker_name,
  ti.worker_email,
  ti.assigned_on,
  ti.task_name,
  ti.task_status,
  ti.phase_name,
  ti.cycle_name,
  ti.vin,
  ti.estimated_hours,
  ti.actual_time_minutes,
  ti.asana_task_gid,
  ti.airtable_record_id,
  ti.normalized_at
from core.task_instances ti
where ti.assigned_on is not null;
