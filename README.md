# pg-stale-stats-demo

Demonstrates how stale PostgreSQL statistics cause Nested Loop cascades
in multi-tenant RLS environments, and how `ANALYZE` fixes the query plan.

## Background

In a multi-tenant PostgreSQL setup with Row Level Security (RLS), adding
a new tenant to a large existing database can cause severe query performance
degradation. The root cause: `autoanalyze` never fires because the new
tenant's data is too small relative to the existing data.

## Data Model

```
projects → tasks → comments → attachments → reviews → audit_logs
```

| Tenant | projects | tasks  | comments | attachments | reviews   | audit_logs | share |
|--------|----------|--------|----------|-------------|-----------|------------|-------|
| A      | 500      | 50,000 | 250,000  | 500,000     | 1,000,000 | 2,000,000  | 99.4% |
| B      | 5        | 50     | 250      | 500         | 1,000     | 2,000      | 0.1%  |
| C      | 20       | 200    | 1,000    | 2,000       | 4,000     | 8,000      | 0.4%  |

## Prerequisites

- Docker / Docker Compose
- `psql` (PostgreSQL client)

## Quick Start

```bash
make setup      # Start PostgreSQL, create schema, seed data (~2 min)
make query      # Run query — BEFORE ANALYZE (slow, ~3.7s)
make analyze    # Refresh statistics
make query      # Run query — AFTER ANALYZE (fast, ~10ms)
make clean      # Tear down
```

## Available Commands

| Command          | Description                                    |
|------------------|------------------------------------------------|
| `make setup`     | Start PostgreSQL, create schema, seed all data |
| `make query`     | Run 6-table JOIN query (3 runs + EXPLAIN)      |
| `make analyze`   | Run ANALYZE on all tables                      |
| `make psql`      | Interactive psql as app_user (subject to RLS)  |
| `make psql-super`| Interactive psql as superuser (can run ANALYZE) |
| `make clean`     | Stop PostgreSQL and delete volume              |
| `make reset`     | Clean + setup from scratch                     |

## Expected Results

### Before ANALYZE (stale: n_distinct=1, actual=3)

```
  Run 1:  8000 rows,  3679 ms
  Run 2:  8000 rows,  3674 ms
  Run 3:  8000 rows,  3734 ms
```

- **Join Filter** scans all rows for tenant, then discards non-matching FKs
- ~42,000,000 rows removed by Join Filter across 5 join levels
- ~21,000,000 buffer hits

### After ANALYZE (correct: n_distinct=3)

```
  Run 1:  8000 rows,  15 ms
  Run 2:  8000 rows,  10 ms
  Run 3:  8000 rows,  9 ms
```

- **Index Cond** uses composite `(tenant_id, foreign_key)` lookup
- 0 rows removed by Join Filter
- ~29,000 buffer hits

### Summary

| Metric              | Before ANALYZE | After ANALYZE | Improvement |
|---------------------|----------------|---------------|-------------|
| Query time          | ~3,700 ms      | ~10 ms        | **370x**    |
| Buffer hits         | 21,140,362     | 28,913        | **731x**    |
| Rows discarded      | 42,188,800     | 0             | -           |

## Why autoanalyze Doesn't Help

PostgreSQL's autovacuum daemon periodically runs `ANALYZE` on tables
that have changed significantly since the last analysis. However, the
threshold for triggering autoanalyze is proportional to the table size:

```
threshold = autovacuum_analyze_threshold + autovacuum_analyze_scale_factor × n_live_tup
          = 50 + 0.1 × n_live_tup
```

For a table like `audit_logs` with 2,000,000 existing rows, the threshold
is **200,050 rows** — meaning over 200,000 rows must be inserted, updated,
or deleted before autoanalyze kicks in.

When a new tenant is onboarded, their data (e.g., 8,000 rows for Tenant C)
represents only **0.4%** of the table. This is far below the 10% threshold,
so autoanalyze never fires. The statistics remain frozen at the state when
only Tenant A existed (`n_distinct=1`), and the query planner has no idea
that new tenants have been added.

This is a fundamental limitation of the default autoanalyze configuration
in multi-tenant databases: the larger the existing data, the harder it
becomes for a small new tenant to trigger a statistics refresh.

## Project Structure

```
sql/
├── 01_schema.sql          # 6 tables with tenant_id + indexes
├── 02_rls.sql             # RLS policies using current_setting('app.tenant_id')
├── 03_seed_tenant_a.sql   # Large tenant (3.8M rows) + ANALYZE
├── 04_seed_tenant_b.sql   # Small tenants B+C (~15K rows, no ANALYZE)
└── 05_query.sql           # 6-table JOIN query (for interactive use)
scripts/
├── setup.sh               # Environment setup
├── query.sh               # Run query with timing + EXPLAIN ANALYZE
└── analyze.sh             # Run ANALYZE and show n_distinct change
```
