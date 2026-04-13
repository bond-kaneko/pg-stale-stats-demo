-- Row Level Security policies using session variable 'app.tenant_id'.
-- This mirrors the real-world pattern where the application sets
-- SET app.tenant_id = '<uuid>' per connection/transaction.

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'projects', 'tasks', 'comments',
        'attachments', 'reviews', 'audit_logs'
    ]
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', tbl);

        EXECUTE format(
            'CREATE POLICY tenant_select_policy ON %I
                FOR SELECT
                USING (tenant_id = NULLIF(current_setting(''app.tenant_id'', true), '''')::uuid)',
            tbl
        );
        EXECUTE format(
            'CREATE POLICY tenant_insert_policy ON %I
                FOR INSERT
                WITH CHECK (tenant_id = NULLIF(current_setting(''app.tenant_id'', true), '''')::uuid)',
            tbl
        );
    END LOOP;
END
$$;

-- Create a non-superuser role that is subject to RLS
CREATE ROLE app_user LOGIN PASSWORD 'app_user';
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA public TO app_user;
