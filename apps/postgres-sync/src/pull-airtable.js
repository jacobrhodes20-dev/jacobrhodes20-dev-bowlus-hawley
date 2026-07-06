import pg from "pg";
import { getDatabaseConfig } from "./config.js";

const { Client } = pg;

const AIRTABLE_API_BASE = "https://api.airtable.com/v0";

const TABLES = Object.freeze([
  {
    envKey: "HAWLEY_AIRTABLE_TASK_INSTANCES_TABLE",
    sourceName: "Task Instances Rev1",
    targetTable: "raw.airtable_task_instances"
  },
  {
    envKey: "HAWLEY_AIRTABLE_CYCLES_TABLE",
    sourceName: "Cycles",
    targetTable: "raw.airtable_cycles"
  },
  {
    envKey: "HAWLEY_AIRTABLE_WORK_FORCE_TABLE",
    sourceName: "Work Force",
    targetTable: "raw.airtable_work_force"
  },
  {
    envKey: "HAWLEY_AIRTABLE_PHASE_CYCLE_LOAD_TABLE",
    sourceName: "Phase Cycle Load Rev1",
    targetTable: "raw.airtable_phase_cycle_load"
  },
  {
    envKey: "HAWLEY_AIRTABLE_WORKER_CYCLE_BANK_TABLE",
    sourceName: "Worker Cycle Bank Rev1",
    targetTable: "raw.airtable_worker_cycle_bank"
  },
  {
    envKey: "HAWLEY_AIRTABLE_PHASES_TABLE",
    sourceName: "Phases",
    targetTable: "raw.airtable_phases"
  },
  {
    envKey: "HAWLEY_AIRTABLE_WORKER_PHASE_ALLOCATION_TABLE",
    sourceName: "Worker Phase Allocation Rev1",
    targetTable: "raw.airtable_worker_phase_allocation"
  }
]);

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env var ${name}.`);
  return value;
}

function airtableTableUrl(baseId, tableName, offset = "") {
  const url = new URL(`${AIRTABLE_API_BASE}/${encodeURIComponent(baseId)}/${encodeURIComponent(tableName)}`);
  url.searchParams.set("pageSize", "100");
  if (offset) url.searchParams.set("offset", offset);
  return url;
}

async function airtableRequest(url, token) {
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Airtable request failed ${response.status}: ${text.slice(0, 500)}`);
  }
  return JSON.parse(text);
}

async function fetchAllAirtableRecords({ baseId, token, tableName }) {
  const records = [];
  let offset = "";

  do {
    const payload = await airtableRequest(airtableTableUrl(baseId, tableName, offset), token);
    records.push(...(payload.records || []));
    offset = payload.offset || "";
  } while (offset);

  return records;
}

function modifiedAtFromFields(fields) {
  for (const key of ["Last Modified", "Last Modified Time", "Last Modified At", "Updated At", "Modified At"]) {
    if (fields[key]) return fields[key];
  }
  return null;
}

async function upsertRawRecords(client, table, records, sourceTableName) {
  const [schemaName, tableName] = table.split(".");
  const fullTable = `"${schemaName}"."${tableName}"`;

  for (const record of records) {
    await client.query(
      `
        insert into ${fullTable}
          (record_id, fields_json, airtable_created_at, modified_at, source_table_name, synced_at)
        values
          ($1, $2::jsonb, $3, $4, $5, now())
        on conflict (record_id) do update set
          fields_json = excluded.fields_json,
          airtable_created_at = excluded.airtable_created_at,
          modified_at = excluded.modified_at,
          source_table_name = excluded.source_table_name,
          synced_at = now()
      `,
      [
        record.id,
        JSON.stringify(record.fields || {}),
        record.createdTime || null,
        modifiedAtFromFields(record.fields || {}),
        sourceTableName
      ]
    );
  }

  const ids = records.map(record => record.id);
  if (ids.length) {
    await client.query(`delete from ${fullTable} where not (record_id = any($1::text[]))`, [ids]);
  }
}

async function startRun(client) {
  const result = await client.query(
    `
      insert into sync.run_log (job_name, mode, status)
      values ('pull_airtable', 'live-readonly', 'running')
      returning id
    `
  );
  return result.rows[0].id;
}

async function finishRun(client, id, status, summary) {
  await client.query(
    `
      update sync.run_log
      set status = $2,
          ended_at = now(),
          records_read = $3,
          records_written = $4,
          error_count = $5,
          summary = $6::jsonb
      where id = $1
    `,
    [
      id,
      status,
      summary.recordsRead || 0,
      summary.recordsWritten || 0,
      summary.errorCount || 0,
      JSON.stringify(summary)
    ]
  );
}

async function main() {
  const baseId = requiredEnv("AIRTABLE_BASE");
  const token = requiredEnv("AIRTABLE_PAT");
  const client = new Client(getDatabaseConfig());
  await client.connect();

  const runId = await startRun(client);
  const summary = {
    tables: {},
    recordsRead: 0,
    recordsWritten: 0,
    errorCount: 0
  };

  try {
    for (const tableConfig of TABLES) {
      const sourceName = process.env[tableConfig.envKey] || tableConfig.sourceName;
      const records = await fetchAllAirtableRecords({ baseId, token, tableName: sourceName });
      await upsertRawRecords(client, tableConfig.targetTable, records, sourceName);
      summary.tables[sourceName] = {
        targetTable: tableConfig.targetTable,
        records: records.length
      };
      summary.recordsRead += records.length;
      summary.recordsWritten += records.length;
      console.log(`${sourceName}: ${records.length} record(s) mirrored to ${tableConfig.targetTable}`);
    }

    await finishRun(client, runId, "success", summary);
  } catch (error) {
    summary.errorCount += 1;
    summary.errorMessage = error.message;
    await client.query(
      `
        insert into sync.errors (run_log_id, source_system, error_type, error_message)
        values ($1, 'airtable', 'pull_airtable', $2)
      `,
      [runId, error.message]
    );
    await finishRun(client, runId, "failed", summary);
    throw error;
  } finally {
    await client.end();
  }
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
