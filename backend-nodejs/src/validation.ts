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

