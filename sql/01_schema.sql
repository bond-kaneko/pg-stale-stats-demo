-- 6-table chain: projects -> tasks -> comments -> attachments -> reviews -> audit_logs
-- All tables have tenant_id for multi-tenant isolation via RLS.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE projects (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id  UUID NOT NULL,
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tasks (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id  UUID NOT NULL,
    project_id UUID NOT NULL REFERENCES projects(id),
    title      TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'open',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE comments (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id  UUID NOT NULL,
    task_id    UUID NOT NULL REFERENCES tasks(id),
    body       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE attachments (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id  UUID NOT NULL,
    comment_id UUID NOT NULL REFERENCES comments(id),
    file_name  TEXT NOT NULL,
    file_size  INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE reviews (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id     UUID NOT NULL,
    attachment_id UUID NOT NULL REFERENCES attachments(id),
    reviewer      TEXT NOT NULL,
    verdict       TEXT NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_logs (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id  UUID NOT NULL,
    review_id  UUID NOT NULL REFERENCES reviews(id),
    action     TEXT NOT NULL,
    detail     TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes on tenant_id + foreign key (mimics real-world multi-tenant schema)
CREATE INDEX idx_projects_tenant          ON projects(tenant_id);
CREATE INDEX idx_tasks_tenant_proj        ON tasks(tenant_id, project_id);
CREATE INDEX idx_comments_tenant_task     ON comments(tenant_id, task_id);
CREATE INDEX idx_attachments_tenant_comment ON attachments(tenant_id, comment_id);
CREATE INDEX idx_reviews_tenant_attach    ON reviews(tenant_id, attachment_id);
CREATE INDEX idx_audit_logs_tenant_review ON audit_logs(tenant_id, review_id);
