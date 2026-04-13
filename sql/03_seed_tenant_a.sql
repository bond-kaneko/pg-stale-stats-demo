-- Seed Tenant A (the original large tenant) and run ANALYZE.
-- After this step, pg_stats.n_distinct for tenant_id = 1 on all tables.
--
-- Target row counts:
--   projects:     500
--   tasks:        50,000   (100 per project)
--   comments:     250,000  (5 per task)
--   attachments:  500,000  (2 per comment)
--   reviews:      1,000,000 (2 per attachment)
--   audit_logs:   2,000,000 (2 per review)

\timing on

\set tenant_a '11111111-1111-1111-1111-111111111111'

INSERT INTO projects (tenant_id, name)
SELECT :'tenant_a'::uuid, 'Project ' || i
FROM generate_series(1, 500) AS i;

INSERT INTO tasks (tenant_id, project_id, title, status)
SELECT p.tenant_id, p.id, 'Task ' || t,
       CASE WHEN random() < 0.7 THEN 'closed' ELSE 'open' END
FROM projects p CROSS JOIN generate_series(1, 100) AS t
WHERE p.tenant_id = :'tenant_a'::uuid;

INSERT INTO comments (tenant_id, task_id, body)
SELECT t.tenant_id, t.id, 'Comment body ' || c
FROM tasks t CROSS JOIN generate_series(1, 5) AS c
WHERE t.tenant_id = :'tenant_a'::uuid;

INSERT INTO attachments (tenant_id, comment_id, file_name, file_size)
SELECT c.tenant_id, c.id,
       'file_' || g || '_' || left(md5(c.id::text || g::text), 8) || '.pdf',
       (random() * 10000)::int
FROM comments c CROSS JOIN generate_series(1, 2) AS g
WHERE c.tenant_id = :'tenant_a'::uuid;

INSERT INTO reviews (tenant_id, attachment_id, reviewer, verdict)
SELECT a.tenant_id, a.id,
       'reviewer_' || g,
       CASE WHEN random() < 0.8 THEN 'approved' ELSE 'rejected' END
FROM attachments a CROSS JOIN generate_series(1, 2) AS g
WHERE a.tenant_id = :'tenant_a'::uuid;

INSERT INTO audit_logs (tenant_id, review_id, action, detail)
SELECT r.tenant_id, r.id,
       CASE WHEN g = 1 THEN 'created' ELSE 'updated' END,
       'Audit entry ' || g
FROM reviews r CROSS JOIN generate_series(1, 2) AS g
WHERE r.tenant_id = :'tenant_a'::uuid;

-- Force ANALYZE → n_distinct = 1 for tenant_id on all tables
ANALYZE projects;
ANALYZE tasks;
ANALYZE comments;
ANALYZE attachments;
ANALYZE reviews;
ANALYZE audit_logs;

\echo ''
\echo '=== Tenant A seed complete ==='
SELECT 'projects' AS tbl, count(*) AS rows FROM projects
UNION ALL SELECT 'tasks', count(*) FROM tasks
UNION ALL SELECT 'comments', count(*) FROM comments
UNION ALL SELECT 'attachments', count(*) FROM attachments
UNION ALL SELECT 'reviews', count(*) FROM reviews
UNION ALL SELECT 'audit_logs', count(*) FROM audit_logs
ORDER BY tbl;

\echo ''
\echo '=== n_distinct should be 1 ==='
SELECT tablename, n_distinct
FROM pg_stats
WHERE tablename IN ('projects','tasks','comments','attachments','reviews','audit_logs')
  AND attname = 'tenant_id'
ORDER BY tablename;
