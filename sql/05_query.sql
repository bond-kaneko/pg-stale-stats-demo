-- Target query: 6-table JOIN chain filtered by RLS (tenant_id).
--
-- Usage: connect as app_user and run interactively.
--   make psql
--   \i sql/05_query.sql

SET app.tenant_id = '33333333-3333-3333-3333-333333333333';

\echo '=== Actual row counts for Tenant C ==='
SELECT 'projects' AS tbl, count(*) FROM projects
UNION ALL SELECT 'tasks', count(*) FROM tasks
UNION ALL SELECT 'comments', count(*) FROM comments
UNION ALL SELECT 'attachments', count(*) FROM attachments
UNION ALL SELECT 'reviews', count(*) FROM reviews
UNION ALL SELECT 'audit_logs', count(*) FROM audit_logs
ORDER BY tbl;

\echo ''
\echo '=== EXPLAIN ANALYZE ==='
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
