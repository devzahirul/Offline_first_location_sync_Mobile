import { z } from "zod";

export const LocationPointSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().min(1),
  deviceId: z.string().min(1),
  recordedAt: z.number().int().nonnegative(),
  lat: z.number(),
  lng: z.number(),
  horizontalAccuracy: z.number().nullable().optional(),
  verticalAccuracy: z.number().nullable().optional(),
  altitude: z.number().nullable().optional(),
  speed: z.number().nullable().optional(),
  course: z.number().nullable().optional()
});

export const UploadBatchSchema = z.object({
  schemaVersion: z.number().int().min(1),
  points: z.array(LocationPointSchema).min(1)
});

export const WsSubscribeSchema = z.object({
  type: z.literal("subscribe"),
  userId: z.string().min(1)
});

export const WsClientMessageSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("auth"), token: z.string().min(1) }),
  z.object({ type: z.literal("location.push"), reqId: z.string().min(1), point: LocationPointSchema }),
  z.object({ type: z.literal("location.batch"), reqId: z.string().min(1), points: z.array(LocationPointSchema).min(1) }),
  z.object({ type: z.literal("subscribe"), userId: z.string().min(1) }),
  z.object({ type: z.literal("unsubscribe"), userId: z.string().min(1) }),
  z.object({ type: z.literal("sync.pull"), reqId: z.string().min(1), cursor: z.string().optional(), limit: z.number().int().min(1).max(500).optional() }),
  z.object({ type: z.literal("ping") }),
]);

export const PullQuerySchema = z.object({
  userId: z.string().min(1),
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(500).default(100),
});

