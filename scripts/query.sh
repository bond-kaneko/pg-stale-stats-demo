#!/usr/bin/env bash
set -euo pipefail

PGHOST=localhost
PGPORT=15432
PGDATABASE=demo
export PGHOST PGPORT PGDATABASE

APP_USER="app_user"
APP_PASS="app_user"
SUPER_USER="demo"
SUPER_PASS="demo"

ALL_TABLES="'projects','tasks','comments','attachments','reviews','audit_logs'"

echo "=============================================="
echo " Current statistics"
echo "=============================================="
PGUSER="$SUPER_USER" PGPASSWORD="$SUPER_PASS" psql -c "
SELECT tablename, n_distinct,
       (SELECT count(DISTINCT tenant_id) FROM projects) AS actual
FROM pg_stats
WHERE tablename IN ($ALL_TABLES)
  AND attname = 'tenant_id'
ORDER BY tablename;
"

echo "=============================================="
echo " Query execution (Tenant C, 6-table JOIN, 3 runs)"
echo "=============================================="
for i in 1 2 3; do
    result=$(PGUSER="$APP_USER" PGPASSWORD="$APP_PASS" psql -q <<'SQL'
\timing on
SET app.tenant_id = '33333333-3333-3333-3333-333333333333';
SELECT count(*) AS rows FROM (
    SELECT p.id, t.id, c.id, a.id, r.id, l.id
    FROM projects p
    JOIN tasks t       ON t.project_id    = p.id AND t.tenant_id = p.tenant_id
    JOIN comments c    ON c.task_id       = t.id AND c.tenant_id = t.tenant_id
    JOIN attachments a ON a.comment_id    = c.id AND a.tenant_id = c.tenant_id
    JOIN reviews r     ON r.attachment_id = a.id AND r.tenant_id = a.tenant_id
    JOIN audit_logs l  ON l.review_id     = r.id AND l.tenant_id = r.tenant_id
) sub;
SQL
    )
    rows=$(echo "$result" | awk '/^ *[0-9]+$/{gsub(/ /,"",$0); print; exit}')
    time_ms=$(echo "$result" | grep 'Time:' | tail -1 | sed 's/.*Time: \([0-9.]*\).*/\1/')
    echo "  Run $i:  ${rows} rows,  ${time_ms} ms"
done

echo ""
echo "=============================================="
echo " Query plan (EXPLAIN ANALYZE)"
echo "=============================================="
PGUSER="$APP_USER" PGPASSWORD="$APP_PASS" psql <<'SQL'
SET app.tenant_id = '33333333-3333-3333-3333-333333333333';
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    p.id    AS project_id,
    p.name  AS project_name,
    t.id    AS task_id,
    t.title,
    c.id    AS comment_id,
    c.body,
    a.id    AS attachment_id,
    a.file_name,
    r.id    AS review_id,
    r.verdict,
    l.id    AS audit_log_id,
    l.action
FROM projects p
JOIN tasks t       ON t.project_id    = p.id AND t.tenant_id = p.tenant_id
JOIN comments c    ON c.task_id       = t.id AND c.tenant_id = t.tenant_id
JOIN attachments a ON a.comment_id    = c.id AND a.tenant_id = c.tenant_id
JOIN reviews r     ON r.attachment_id = a.id AND r.tenant_id = a.tenant_id
JOIN audit_logs l  ON l.review_id     = r.id AND l.tenant_id = r.tenant_id;
SQL
