# Postgres Latency Clinic — API + Query Plan Optimization (p95/p99)

A small performance case study demonstrating how to identify and fix an API latency bottleneck caused by an inefficient Postgres access pattern. Includes **before/after benchmarks (p50/p95/p99)**, **EXPLAIN (ANALYZE, BUFFERS)** output, and the optimization implemented (index + query tweak).

## Why this exists (what it proves)
This repo is intentionally scoped to mirror real backend performance work:
- Find a production-like bottleneck (slow API endpoint due to DB access)
- Measure latency under load (focus on **p95/p99 tail latency**)
- Use Postgres query plans to diagnose the root cause
- Apply a targeted fix (index / schema change / query rewrite)
- Re-run benchmarks and document results

## Stack
- API: {FastAPI/Express}  
- Database: Postgres {version} (Docker)  
- Load testing: k6  
- Local orchestration: docker-compose  

## System under test
**Endpoint:** `GET /events/:user_id`  
**Query pattern:** fetch the latest 20 events for a user
```sql
SELECT id, user_id, created_at
FROM events
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT 20;
```

**Dataset:** ~{N} rows in `events`, ~{U} distinct users (seeded in `db/init.sql`)

## How to run
### 1) Start services
```bash
docker compose up --build
```

### 2) Confirm API is up
```bash
curl http://localhost:{PORT}/events/1
```

### 3) Run baseline benchmark (BEFORE)
```bash
k6 run loadtest/k6.js | tee results/before.txt
```

### 4) Capture baseline query plan (BEFORE)
Open a psql shell:
```bash
docker exec -it {db_container_name} psql -U postgres -d perf
```

Run:
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, user_id, created_at
FROM events
WHERE user_id = 123
ORDER BY created_at DESC
LIMIT 20;
```
Save output to: `results/explain_before.txt`

## Bottleneck analysis (BEFORE)
**Observed symptoms under load**
- Elevated tail latency (p95/p99)
- Higher DB time per request (dominant portion of request time)

**Root cause (from EXPLAIN ANALYZE)**
- {e.g., Sequential Scan / Sort / High buffer reads / Large rows filtered}
- {e.g., Missing index on (user_id, created_at) caused scan + sort}

> Key EXPLAIN evidence:
> - {line/summary: "Seq Scan on events" / "Sort Method" / "Rows Removed by Filter" / "Buffers: shared hit/read"}

## Optimization
### Fix implemented
1) Added a composite index to support the access pattern:
```sql
CREATE INDEX IF NOT EXISTS events_user_created_idx
ON events (user_id, created_at DESC);
```

2) [Optional, only if you did it] Query/serialization optimization:
- {e.g., selected only needed columns}
- {e.g., reduced payload size / avoided heavy JSON parsing}
- {e.g., connection pooling / reuse}

### Why this works
- The index allows Postgres to satisfy `WHERE user_id = ?` and `ORDER BY created_at DESC` efficiently,
  avoiding expensive scans/sorts and improving tail latency.

## Results (BEFORE vs AFTER)
### Load test configuration
- VUs: {X}
- Duration: {Y}s
- Random user_id distribution: {uniform 1..U}

### Benchmark output (k6)
| Metric | Before | After | Delta |
|---|---:|---:|---:|
| p50 latency | { } | { } | { } |
| p95 latency | { } | { } | { } |
| p99 latency | { } | { } | { } |
| req/s | { } | { } | { } |
| error rate | { } | { } | { } |

Artifacts:
- `results/before.txt`
- `results/after.txt`
- `results/explain_before.txt`
- `results/explain_after.txt`

### Query plan evidence (AFTER)
After applying the index, capture:
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, user_id, created_at
FROM events
WHERE user_id = 123
ORDER BY created_at DESC
LIMIT 20;
```

Expected improvements:
- {Index Scan / Index Only Scan}
- Lower total time
- Lower buffers read
- No large sort

## Notes on correctness + reliability
- This endpoint returns the latest 20 events for a user (ordered by created_at).
- The optimization preserves correctness; it changes only the execution plan, not the result set.

## What I would do next in production
- Add application-level metrics: request latency (p50/p95/p99), DB time per request, cache hit rate (if applicable)
- Add regression gates in CI (run k6 smoke + fail if p95 regresses by >{threshold}%)
- Evaluate partitioning / sharding strategy if the table grows to {large scale}:
  - time-based partitioning on `created_at` or tenant-based partitioning on `user_id`
- Add caching for hot users (Redis cache-aside) with TTL + stampede protection
- Tune connection pooling and timeouts to prevent cascading failures under load

## License
{MIT / Apache-2.0 / leave blank}
