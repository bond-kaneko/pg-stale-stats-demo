-- Seed Tenant B and Tenant C WITHOUT running ANALYZE.
-- Matches the real-world scenario: n_distinct was 1, actually 3 tenants.
--
-- autoanalyze threshold for audit_logs (2,000,000 rows):
--   50 + 0.1 * 2,000,000 = 200,050 rows of change needed
-- Tenant B + C combined add ~23,000 rows → NO autoanalyze
--
-- Tenant C Nested Loop cascade (6 levels):
--   L1: 20 × 200 = 4,000
--   L2: 200 × 1,000 = 200,000
--   L3: 1,000 × 2,000 = 2,000,000
--   L4: 2,000 × 4,000 = 8,000,000
--   L5: 4,000 × 8,000 = 32,000,000
--   Total: ~42,000,000 comparisons

\timing on

\set tenant_b '22222222-2222-2222-2222-222222222222'
\set tenant_c '33333333-3333-3333-3333-333333333333'

-- ============================================================
-- Tenant B: small existing tenant
-- ============================================================
INSERT INTO projects (tenant_id, name)
SELECT :'tenant_b'::uuid, 'B-Project ' || i FROM generate_series(1, 5) AS i;

INSERT INTO tasks (tenant_id, project_id, title, status)
SELECT p.tenant_id, p.id, 'B-Task ' || t, 'open'
FROM projects p CROSS JOIN generate_series(1, 10) AS t
WHERE p.tenant_id = :'tenant_b'::uuid;

INSERT INTO comments (tenant_id, task_id, body)
SELECT t.tenant_id, t.id, 'B-Comment ' || c
FROM tasks t CROSS JOIN generate_series(1, 5) AS c
WHERE t.tenant_id = :'tenant_b'::uuid;

INSERT INTO attachments (tenant_id, comment_id, file_name, file_size)
SELECT c.tenant_id, c.id, 'b_file_' || g || '.pdf', (random() * 5000)::int
FROM comments c CROSS JOIN generate_series(1, 2) AS g
WHERE c.tenant_id = :'tenant_b'::uuid;

INSERT INTO reviews (tenant_id, attachment_id, reviewer, verdict)
SELECT a.tenant_id, a.id, 'reviewer_' || g, 'approved'
FROM attachments a CROSS JOIN generate_series(1, 2) AS g
WHERE a.tenant_id = :'tenant_b'::uuid;

INSERT INTO audit_logs (tenant_id, review_id, action, detail)
SELECT r.tenant_id, r.id, 'created', 'Audit ' || g
FROM reviews r CROSS JOIN generate_series(1, 2) AS g
WHERE r.tenant_id = :'tenant_b'::uuid;

-- ============================================================
-- Tenant C: the new problematic tenant (query target)
--   projects:    20
--   tasks:       200   (10 per project)
--   comments:    1,000 (5 per task)
--   attachments: 2,000 (2 per comment)
--   reviews:     4,000 (2 per attachment)
--   audit_logs:  8,000 (2 per review)
-- ============================================================
INSERT INTO projects (tenant_id, name)
SELECT :'tenant_c'::uuid, 'C-Project ' || i FROM generate_series(1, 20) AS i;

INSERT INTO tasks (tenant_id, project_id, title, status)
SELECT p.tenant_id, p.id, 'C-Task ' || t, 'open'
FROM projects p CROSS JOIN generate_series(1, 10) AS t
WHERE p.tenant_id = :'tenant_c'::uuid;

INSERT INTO comments (tenant_id, task_id, body)
SELECT t.tenant_id, t.id, 'C-Comment ' || c
FROM tasks t CROSS JOIN generate_series(1, 5) AS c
WHERE t.tenant_id = :'tenant_c'::uuid;

INSERT INTO attachments (tenant_id, comment_id, file_name, file_size)
SELECT c.tenant_id, c.id, 'c_file_' || g || '.png', (random() * 3000)::int
FROM comments c CROSS JOIN generate_series(1, 2) AS g
WHERE c.tenant_id = :'tenant_c'::uuid;

INSERT INTO reviews (tenant_id, attachment_id, reviewer, verdict)
SELECT a.tenant_id, a.id, 'reviewer_' || g, 'pending'
FROM attachments a CROSS JOIN generate_series(1, 2) AS g
WHERE a.tenant_id = :'tenant_c'::uuid;

INSERT INTO audit_logs (tenant_id, review_id, action, detail)
SELECT r.tenant_id, r.id,
       CASE WHEN g = 1 THEN 'created' ELSE 'submitted' END,
       'Audit ' || g
FROM reviews r CROSS JOIN generate_series(1, 2) AS g
WHERE r.tenant_id = :'tenant_c'::uuid;

-- Do NOT run ANALYZE.

\echo ''
\echo '=== Row counts after all tenants ==='
SELECT 'projects' AS tbl, count(*) AS rows FROM projects
UNION ALL SELECT 'tasks', count(*) FROM tasks
UNION ALL SELECT 'comments', count(*) FROM comments
UNION ALL SELECT 'attachments', count(*) FROM attachments
UNION ALL SELECT 'reviews', count(*) FROM reviews
UNION ALL SELECT 'audit_logs', count(*) FROM audit_logs
ORDER BY tbl;

\echo ''
\echo '=== n_distinct should still be 1 (STALE!) ==='
SELECT tablename, n_distinct
FROM pg_stats
WHERE tablename IN ('projects','tasks','comments','attachments','reviews','audit_logs')
  AND attname = 'tenant_id'
ORDER BY tablename;
