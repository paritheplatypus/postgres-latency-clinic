CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload TEXT NOT NULL
);

-- Seed a decent dataset fast (adjust 200000 -> 1000000 if your laptop can handle it)
INSERT INTO events (user_id, created_at, payload)
SELECT
  (random() * 5000)::bigint + 1,
  now() - (random() * interval '30 days'),
  repeat('x', 200)
FROM generate_series(1, 200000);

-- IMPORTANT: start with NO helpful index (this is the "before" state)
