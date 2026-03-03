import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import path from "node:path";

// Minimal `.env` loader (no external dependency).
// - Ignores empty lines and lines starting with `#`
// - `KEY=VALUE` pairs
// - If VALUE is wrapped in single/double quotes, quotes are stripped
// - Does not override already-set environment variables
export async function loadDotEnvIfPresent(filename = ".env"): Promise<void> {
  const filePath = path.join(process.cwd(), filename);
  if (!existsSync(filePath)) return;

  const raw = await readFile(filePath, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;

    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();

    if (!key) continue;
    if (process.env[key] !== undefined) continue;

    if (
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    process.env[key] = value;
  }
}

