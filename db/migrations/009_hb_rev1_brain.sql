create schema if not exists hb;

create table if not exists hb.work_force (
  workforce_record_id text primary key,
  worker_name text,
  worker_email text,
  actively_employed boolean not null default false,
  primary_phase_record_id text,
  home_section_column text,
  efficiency_factor numeric(10, 4) not null default 1,
  ideal_efficiency_factor numeric(10, 4),
  fab_skill_level numeric(10, 2),
  cnc_skill_level numeric(10, 2),
  frames_skill_level numeric(10, 2),
  phase_a_skill_level numeric(10, 2),
  phase_b_skill_level numeric(10, 2),
  phase_c_skill_level numeric(10, 2),
  phase_d_skill_level numeric(10, 2),
  phase_e_skill_level numeric(10, 2),
  phase_f_skill_level numeric(10, 2),
  phase_g_skill_level numeric(10, 2),
  phase_h_skill_level numeric(10, 2),
  qc_inventory_skill_level numeric(10, 2),
  hours_per_day numeric(10, 2),
  fields_json jsonb not null default '{}'::jsonb,
  source_system text not null default 'airtable_bootstrap',
  source_synced_at timestamptz,
  normalized_at timestamptz not null default now()
);

create table if not exists hb.cycles (
  cycle_record_id text primary key,
  cycle_number integer,
  cycle_label text,
  start_date date,
  end_date date,
  quarter text,
  days_in_cycle integer,
  cycle_capacity numeric(12, 2),
  hours_per_workday numeric(10, 2),
  holidays text,
  cycle_percent numeric(12, 6),
  sequence_number integer,
  fields_json jsonb not null default '{}'::jsonb,
  source_system text not null default 'airtable_bootstrap',
  source_synced_at timestamptz,
  normalized_at timestamptz not null default now()
);

create table if not exists hb.phases (
  phase_record_id text primary key,
  phase_name text,
  section_column text,
  process_order numeric(10, 2),
  installation_phase text,
  model_type text,
  frame_class text,
  task_offset integer,
  backfill_odd integer,
  backfill_even integer,
  group_size integer,
  parity_mode text,
  phase_skills text,
  fields_json jsonb not null default '{}'::jsonb,
  source_system text not null default 'airtable_bootstrap',
  source_synced_at timestamptz,
  normalized_at timestamptz not null default now()
);

create table if not exists hb.rev1_task_instances (
  rev1_task_instance_id bigserial primary key,
  airtable_record_id text unique,
  task_instance_rev1_key text,
  airtable_key text,
  asana_airtable_key text,
  asana_task_gid text,
  asana_project_gid text,
  asana_project_name text,
  asana_portfolio_gid text,
  asana_portfolio_name text,
  asana_section text,
  parent_asana_task_gid text,
  parent_task_name text,
  parent_task text,
  is_subtask boolean not null default false,
  inherited_from_parent boolean not null default false,
  task_name text,
  task_description text,
  task_type text,
  task_order numeric(12, 2),
  status text,
  task_status text,
  task_completed boolean not null default false,
  completed_on date,
  asana_due_date date,
  assigned_on date,
  worker_record_id text,
  worker_name text,
  worker_email text,
  assignee_name text,
  assignee_email text,
  phase_record_id text,
  phase_label text,
  section_column text,
  phase_cycle_bucket_key text,
  phase_cycle_key text,
  cycle_record_id text,
  cycle_label text,
  vin integer,
  vin_text text,
  vin_record_id text,
  line_schedule_record_id text,
  tasks_record_id text,
  tasks_key text,
  model text,
  model_type text,
  start_date date,
  end_date date,
  quantity numeric(12, 4),
  estimated_task_time_seconds integer,
  estimated_batch_task_time_seconds integer,
  actual_time_seconds integer,
  actual_time_minutes integer,
  allocated_hours numeric(12, 2),
  completed_est_hours numeric(12, 2),
  open_est_hours numeric(12, 2),
  actual_efficiency numeric(12, 4),
  days_in_cycle integer,
  est_time_remaining_project_seconds integer,
  document_link text,
  attachment_summary text,
  active_in_production boolean not null default false,
  production_match_status text,
  sync_status boolean not null default false,
  last_synced_at text,
  rev1_import_notes text,
  phase_cycle_load_record_id text,
  worker_phase_allocation_record_id text,
  load_type text,
  proposed_worker text,
  proposed_worker_record_id text,
  proposed_start_date date,
  proposed_end_date date,
  scheduler_score numeric(12, 4),
  scheduler_status text,
  scheduler_mode text,
  scheduler_notes text,
  scheduler_snapshot_id text,
  scheduler_baseline_snapshot_id text,
  required_skill_scheduler numeric(12, 4),
  current_skill_level_scheduler numeric(12, 4),
  proposed_skill_level_scheduler numeric(12, 4),
  skill_gap_scheduler numeric(12, 4),
  overskill_scheduler numeric(12, 4),
  load_delta_hours_scheduler numeric(12, 4),
  scheduler_locked boolean not null default false,
  push_to_asana boolean not null default false,
  scheduling_evaluated_at text,
  scheduling_scope text,
  asana_push_status text,
  asana_push_result text,
  asana_pushed_at text,
  fields_json jsonb not null default '{}'::jsonb,
  source_system text not null default 'airtable_bootstrap',
  source_synced_at timestamptz,
  normalized_at timestamptz not null default now()
);

comment on column hb.rev1_task_instances.actual_efficiency is
  'Legacy efficiency signal. HB keeps current AirSync behavior: actual_time_seconds / estimated_batch_task_time_seconds. Future efficiency should move to worker timer/average-time models.';

create table if not exists hb.worker_daily_task_actuals (
  worker_daily_actual_id bigserial primary key,
  airtable_record_id text unique,
  ledger_key text unique,
  work_date date,
  worker_key text,
  worker_name text,
  worker_email text,
  asana_task_gid text,
  task_name text,
  task_url text,
  vin text,
  cycle_label text,
  phase_label text,
  assigned_hours numeric(12, 2),
  allocated_hours numeric(12, 2),
  actual_minutes integer,
  timer_minutes integer,
  asana_posted_minutes integer,
  source_label text,
  was_assigned_in_dat boolean not null default false,
  was_recovered boolean not null default false,
  completed boolean not null default false,
  last_seen_at timestamptz,
  notes text,
  daily_summary boolean not null default false,
  daily_available_minutes integer,
  daily_logged_minutes integer,
  daily_efficiency_percent numeric(12, 4),
  daily_efficiency_under_75 boolean not null default false,
  efficiency_snapshot_at timestamptz,
  review_month text,
  review_year integer,
  fields_json jsonb not null default '{}'::jsonb,
  source_system text not null default 'airtable_bootstrap',
  source_synced_at timestamptz,
  normalized_at timestamptz not null default now()
);

create table if not exists hb.phase_cycle_load_rev1 (
  phase_cycle_bucket_key text primary key,
  display_bucket_key text,
  phase_record_id text,
  phase_name text,
  cycle_record_id text,
  cycle_label text,
  total_load_hours numeric(12, 2) not null default 0,
  remaining_task_hours numeric(12, 2) not null default 0,
  completed_task_hours numeric(12, 2) not null default 0,
  coverage_percent numeric(12, 6) not null default 0,
  imported_hours numeric(12, 2) not null default 0,
  exported_hours numeric(12, 2) not null default 0,
  completion_percent numeric(12, 6) not null default 0,
  status text,
  hours_per_day numeric(10, 2) not null default 7.17,
  task_instance_ids bigint[] not null default '{}'::bigint[],
  task_airtable_record_ids text[] not null default '{}'::text[],
  import_allocation_keys text[] not null default '{}'::text[],
  export_allocation_keys text[] not null default '{}'::text[],
  calculation_version text not null default 'hb_rev1_batch_v1',
  rebuilt_at timestamptz not null default now()
);

create table if not exists hb.worker_phase_allocation_rev1 (
  worker_cycle_phase_key text primary key,
  worker_record_id text,
  worker_name text,
  worker_email text,
  cycle_record_id text,
  cycle_label text,
  worked_phase_record_id text,
  worked_phase_text text,
  home_phase_text text,
  is_home_phase boolean not null default false,
  assigned_hours numeric(12, 2) not null default 0,
  imported_hours numeric(12, 2) not null default 0,
  exported_hours numeric(12, 2) not null default 0,
  cross_phase_support boolean not null default false,
  phase_cycle_bucket_key text,
  worked_bucket_key text,
  phase_cycle_load_key text,
  worker_cycle_key text,
  task_instance_ids bigint[] not null default '{}'::bigint[],
  task_airtable_record_ids text[] not null default '{}'::text[],
  calculation_version text not null default 'hb_rev1_batch_v1',
  rebuilt_at timestamptz not null default now()
);

create table if not exists hb.worker_cycle_bank_rev1 (
  worker_cycle_key text primary key,
  worker_record_id text,
  worker_name text,
  worker_email text,
  cycle_record_id text,
  cycle_label text,
  assigned_hours_total numeric(12, 2) not null default 0,
  remaining_hours numeric(12, 2) not null default 0,
  cycle_capacity numeric(12, 2) not null default 0,
  effective_hours_bank numeric(12, 2) not null default 0,
  actively_employed boolean not null default false,
  days_in_cycle integer,
  efficiency_factor numeric(10, 4) not null default 1,
  wpa_record_keys text[] not null default '{}'::text[],
  calculation_version text not null default 'hb_rev1_batch_v1',
  rebuilt_at timestamptz not null default now()
);

create index if not exists idx_hb_rev1_task_instances_asana_gid
  on hb.rev1_task_instances(asana_task_gid);

create index if not exists idx_hb_rev1_task_instances_worker_date
  on hb.rev1_task_instances(worker_email, assigned_on);

create index if not exists idx_hb_rev1_task_instances_cycle_phase
  on hb.rev1_task_instances(cycle_record_id, phase_record_id);

create index if not exists idx_hb_rev1_task_instances_worker_cycle
  on hb.rev1_task_instances(worker_record_id, cycle_record_id);

create index if not exists idx_hb_worker_daily_actuals_work_date
  on hb.worker_daily_task_actuals(work_date);

create index if not exists idx_hb_worker_daily_actuals_worker_date
  on hb.worker_daily_task_actuals(worker_key, work_date);

create index if not exists idx_hb_phase_cycle_load_cycle_phase
  on hb.phase_cycle_load_rev1(cycle_record_id, phase_record_id);

create index if not exists idx_hb_worker_phase_allocation_worker_cycle
  on hb.worker_phase_allocation_rev1(worker_record_id, cycle_record_id);

create index if not exists idx_hb_worker_cycle_bank_worker_cycle
  on hb.worker_cycle_bank_rev1(worker_record_id, cycle_record_id);

grant usage on schema hb to bowlus_sync, bowlus_app, bowlus_readonly;

grant select, insert, update, delete on
  hb.work_force,
  hb.cycles,
  hb.phases,
  hb.rev1_task_instances,
  hb.worker_daily_task_actuals,
  hb.phase_cycle_load_rev1,
  hb.worker_phase_allocation_rev1,
  hb.worker_cycle_bank_rev1
to bowlus_sync;

grant usage, select, update on all sequences in schema hb to bowlus_sync;

grant select on
  hb.work_force,
  hb.cycles,
  hb.phases,
  hb.rev1_task_instances,
  hb.worker_daily_task_actuals,
  hb.phase_cycle_load_rev1,
  hb.worker_phase_allocation_rev1,
  hb.worker_cycle_bank_rev1
to bowlus_app, bowlus_readonly;
