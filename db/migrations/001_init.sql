create schema if not exists raw;
create schema if not exists core;
create schema if not exists calc;
create schema if not exists reporting;
create schema if not exists sync;

create table if not exists sync.run_log (
  id bigserial primary key,
  job_name text not null,
  mode text not null default 'dry-run',
  status text not null default 'running',
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  records_read integer not null default 0,
  records_written integer not null default 0,
  error_count integer not null default 0,
  summary jsonb not null default '{}'::jsonb
);

create table if not exists sync.errors (
  id bigserial primary key,
  run_log_id bigint references sync.run_log(id),
  source_system text,
  source_id text,
  error_type text,
  error_message text not null,
  retry_state text not null default 'new',
  created_at timestamptz not null default now()
);

create table if not exists sync.source_watermarks (
  source_name text primary key,
  watermark_value text,
  updated_at timestamptz not null default now()
);

create table if not exists raw.asana_projects (
  gid text primary key,
  name text,
  archived boolean,
  modified_at timestamptz,
  raw_json jsonb not null,
  synced_at timestamptz not null default now()
);

create table if not exists raw.asana_tasks (
  gid text primary key,
  project_gid text,
  parent_gid text,
  name text,
  assignee_gid text,
  assignee_name text,
  completed boolean,
  completed_at timestamptz,
  due_on date,
  actual_time_minutes integer,
  custom_fields_json jsonb not null default '{}'::jsonb,
  modified_at timestamptz,
  raw_json jsonb not null,
  synced_at timestamptz not null default now()
);

create table if not exists raw.airtable_task_instances (
  record_id text primary key,
  fields_json jsonb not null,
  modified_at timestamptz,
  synced_at timestamptz not null default now()
);

create table if not exists raw.airtable_cycles (
  record_id text primary key,
  fields_json jsonb not null,
  synced_at timestamptz not null default now()
);

create table if not exists raw.airtable_work_force (
  record_id text primary key,
  fields_json jsonb not null,
  synced_at timestamptz not null default now()
);

create table if not exists raw.airtable_phase_cycle_load (
  record_id text primary key,
  fields_json jsonb not null,
  synced_at timestamptz not null default now()
);

create table if not exists raw.airtable_worker_cycle_bank (
  record_id text primary key,
  fields_json jsonb not null,
  synced_at timestamptz not null default now()
);

create table if not exists core.task_instances (
  id bigserial primary key,
  airtable_record_id text unique,
  asana_task_gid text,
  worker_name text,
  worker_email text,
  phase_name text,
  cycle_name text,
  vin text,
  assigned_on date,
  task_name text,
  task_status text,
  estimated_hours numeric(10, 2),
  actual_time_minutes integer,
  source_updated_at timestamptz,
  normalized_at timestamptz not null default now()
);

create table if not exists core.worker_task_sessions (
  id bigserial primary key,
  task_instance_id bigint references core.task_instances(id),
  worker_email text,
  started_at timestamptz not null,
  stopped_at timestamptz,
  elapsed_minutes integer,
  state text not null default 'running',
  asana_push_state text not null default 'not_ready',
  asana_pushed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sync.record_map (
  id bigserial primary key,
  asana_task_gid text,
  airtable_record_id text,
  core_task_instance_id bigint references core.task_instances(id),
  source_type text not null,
  last_seen_at timestamptz not null default now(),
  last_synced_at timestamptz
);

create index if not exists idx_task_instances_worker_date
  on core.task_instances(worker_email, assigned_on);

create index if not exists idx_task_instances_asana_gid
  on core.task_instances(asana_task_gid);
