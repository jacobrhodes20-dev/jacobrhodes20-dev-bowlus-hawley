alter table raw.airtable_task_instances
  add column if not exists airtable_created_at timestamptz,
  add column if not exists source_table_name text;

alter table raw.airtable_cycles
  add column if not exists airtable_created_at timestamptz,
  add column if not exists modified_at timestamptz,
  add column if not exists source_table_name text;

alter table raw.airtable_work_force
  add column if not exists airtable_created_at timestamptz,
  add column if not exists modified_at timestamptz,
  add column if not exists source_table_name text;

alter table raw.airtable_phase_cycle_load
  add column if not exists airtable_created_at timestamptz,
  add column if not exists modified_at timestamptz,
  add column if not exists source_table_name text;

alter table raw.airtable_worker_cycle_bank
  add column if not exists airtable_created_at timestamptz,
  add column if not exists modified_at timestamptz,
  add column if not exists source_table_name text;

create table if not exists raw.airtable_phases (
  record_id text primary key,
  fields_json jsonb not null,
  airtable_created_at timestamptz,
  modified_at timestamptz,
  source_table_name text,
  synced_at timestamptz not null default now()
);

create table if not exists raw.airtable_worker_phase_allocation (
  record_id text primary key,
  fields_json jsonb not null,
  airtable_created_at timestamptz,
  modified_at timestamptz,
  source_table_name text,
  synced_at timestamptz not null default now()
);

grant select, insert, update, delete on raw.airtable_task_instances to bowlus_sync;
grant select, insert, update, delete on raw.airtable_cycles to bowlus_sync;
grant select, insert, update, delete on raw.airtable_work_force to bowlus_sync;
grant select, insert, update, delete on raw.airtable_phase_cycle_load to bowlus_sync;
grant select, insert, update, delete on raw.airtable_worker_cycle_bank to bowlus_sync;
grant select, insert, update, delete on raw.airtable_phases to bowlus_sync;
grant select, insert, update, delete on raw.airtable_worker_phase_allocation to bowlus_sync;

create unique index if not exists idx_record_map_airtable_task_instance
  on sync.record_map (source_type, airtable_record_id, core_task_instance_id)
  where airtable_record_id is not null;
