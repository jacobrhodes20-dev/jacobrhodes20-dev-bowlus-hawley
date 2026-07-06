const command = process.argv[2] || "command";

console.log(`${command} is intentionally not implemented yet.`);
console.log("Phase 1 starts with Postgres install, schema migration, and health checks.");
process.exitCode = 1;
