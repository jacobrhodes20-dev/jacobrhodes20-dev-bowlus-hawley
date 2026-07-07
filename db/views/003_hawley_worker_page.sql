create or replace view reporting.hawley_worker_page_assignments as
select
  dwa.task_instance_id,
  dwa.airtable_record_id,
  dwa.asana_task_gid,
  dwa.worker_name,
  dwa.worker_email,
  dwa.assigned_on,
  dwa.task_name,
  coalesce(asana_task.completed, lower(coalesce(dwa.task_status, '')) in ('true', 'complete', 'completed', 'done', 'yes')) as completed,
  dwa.task_status,
  dwa.phase_name,
  dwa.cycle_name,
  dwa.vin,
  dwa.estimated_hours,
  dwa.actual_time_minutes,
  asana_task.permalink_url as asana_permalink_url,
  ops.jsonb_display_text(airtable_task.fields_json->'SOP Link') as sop_link,
  ops.jsonb_display_text(airtable_task.fields_json->'Document Link') as document_link,
  ops.jsonb_display_text(airtable_task.fields_json->'Section/Column') as section_column,
  work_area.inferred_work_area_key,
  work_area.inferred_work_area_name,
  work_area.inference_source,
  dwa.normalized_at,
  greatest(
    coalesce(dwa.normalized_at, '-infinity'::timestamptz),
    coalesce(asana_task.synced_at, '-infinity'::timestamptz),
    coalesce(airtable_task.synced_at, '-infinity'::timestamptz)
  ) as source_synced_at
from reporting.daily_worker_assignments dwa
left join raw.asana_tasks asana_task on asana_task.gid = dwa.asana_task_gid
left join raw.airtable_task_instances airtable_task on airtable_task.record_id = dwa.airtable_record_id
left join reporting.task_work_area_inference work_area on work_area.task_instance_id = dwa.task_instance_id;
