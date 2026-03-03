import jwt from "jsonwebtoken";
import type { Request } from "express";

export function requireAuth(req: Request): { sub?: string } {
  const secret = process.env.JWT_SECRET;
  if (!secret) return {};

  const header = req.headers["authorization"];
  if (!header) throw new Error("missing Authorization header");
  const [kind, token] = header.split(" ");
  if (kind !== "Bearer" || !token) throw new Error("invalid Authorization header");

  const payload = jwt.verify(token, secret);
  if (typeof payload === "string") return {};

  return { sub: typeof payload.sub === "string" ? payload.sub : undefined };
}

