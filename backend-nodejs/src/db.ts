import { readFile } from "node:fs/promises";
import path from "node:path";
import { Pool } from "pg";
import type { LocationPoint } from "./types.js";

export type DB = {
  pool: Pool;
};

export async function createDB(): Promise<DB | null> {
  const url = process.env.DATABASE_URL;
  if (!url) return null;

  const pool = new Pool({ connectionString: url });
  await pool.query("SELECT 1");
  await ensureSchema(pool);
  return { pool };
}

async function ensureSchema(pool: Pool): Promise<void> {
  const sqlPath = path.join(process.cwd(), "sql", "001_init.sql");
  const ddl = await readFile(sqlPath, "utf8");
  await pool.query(ddl);
}

export async function insertPoints(db: DB, points: LocationPoint[]): Promise<void> {
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");
    for (const p of points) {
      await client.query(
        `
        INSERT INTO location_points(
          id, user_id, device_id, recorded_at, lat, lng,
          horizontal_accuracy, vertical_accuracy, altitude, speed, course
        )
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
        ON CONFLICT (id) DO NOTHING
        `,
        [
          p.id,
          p.userId,
          p.deviceId,
          new Date(p.recordedAt),
          p.lat,
          p.lng,
          p.horizontalAccuracy ?? null,
          p.verticalAccuracy ?? null,
          p.altitude ?? null,
          p.speed ?? null,
          p.course ?? null
        ]
      );
    }
    await client.query("COMMIT");
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}

export async function latestPointForUser(db: DB, userId: string): Promise<LocationPoint | null> {
  const result = await db.pool.query(
    `
    SELECT
      id::text as id,
      user_id as "userId",
      device_id as "deviceId",
      (extract(epoch from recorded_at) * 1000)::bigint as "recordedAt",
      lat,
      lng,
      horizontal_accuracy as "horizontalAccuracy",
      vertical_accuracy as "verticalAccuracy",
      altitude,
      speed,
      course
    FROM location_points
    WHERE user_id = $1
    ORDER BY recorded_at DESC
    LIMIT 1
    `,
    [userId]
  );

  return (result.rows[0] as LocationPoint | undefined) ?? null;
}

