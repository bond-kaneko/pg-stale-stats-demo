#!/usr/bin/env bash
set -euo pipefail

PGHOST=localhost
PGPORT=15432
PGUSER=demo
PGPASSWORD=demo
PGDATABASE=demo
export PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE

ALL_TABLES="'projects','tasks','comments','attachments','reviews','audit_logs'"

echo "=============================================="
echo " BEFORE: n_distinct for tenant_id"
echo "=============================================="
psql -c "
SELECT tablename, n_distinct
FROM pg_stats
WHERE tablename IN ($ALL_TABLES)
  AND attname = 'tenant_id'
ORDER BY tablename;
"

echo "=============================================="
echo " Running ANALYZE on all tables..."
echo "=============================================="
psql -c "
ANALYZE projects;
ANALYZE tasks;
ANALYZE comments;
ANALYZE attachments;
ANALYZE reviews;
ANALYZE audit_logs;
"

echo "=============================================="
echo " AFTER: n_distinct for tenant_id"
echo "=============================================="
psql -c "
SELECT tablename, n_distinct
FROM pg_stats
WHERE tablename IN ($ALL_TABLES)
  AND attname = 'tenant_id'
ORDER BY tablename;
"
