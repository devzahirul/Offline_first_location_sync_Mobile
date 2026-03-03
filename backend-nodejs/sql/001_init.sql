CREATE TABLE IF NOT EXISTS location_points (
  id uuid PRIMARY KEY,
  user_id text NOT NULL,
  device_id text NOT NULL,
  recorded_at timestamptz NOT NULL,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  horizontal_accuracy double precision,
  vertical_accuracy double precision,
  altitude double precision,
  speed double precision,
  course double precision,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_location_points_user_recorded_at
ON location_points(user_id, recorded_at DESC);

