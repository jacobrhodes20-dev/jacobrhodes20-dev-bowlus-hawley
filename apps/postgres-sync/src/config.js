import dotenv from "dotenv";

dotenv.config();

export function getDatabaseConfig() {
  if (process.env.DATABASE_URL) {
    return {
      connectionString: process.env.DATABASE_URL
    };
  }

  return {
    host: process.env.PGHOST || "localhost",
    port: Number(process.env.PGPORT || 5432),
    database: process.env.PGDATABASE || "bowlus_ops",
    user: process.env.PGUSER || "bowlus_app",
    password: process.env.PGPASSWORD || undefined
  };
}
