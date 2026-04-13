#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PGHOST=localhost
PGPORT=15432
PGUSER=demo
PGPASSWORD=demo
PGDATABASE=demo
export PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE

echo "=== Starting PostgreSQL ==="
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d --wait

echo "=== Waiting for PostgreSQL to be ready ==="
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" > /dev/null 2>&1; do
    sleep 1
done

echo ""
echo "=== [1/4] Creating schema (4 tables) ==="
psql -f "$PROJECT_DIR/sql/01_schema.sql"

echo ""
echo "=== [2/4] Enabling RLS ==="
psql -f "$PROJECT_DIR/sql/02_rls.sql"

echo ""
echo "=== [3/4] Seeding Tenant A (1M+ rows) + ANALYZE ==="
echo "    This may take 1-2 minutes..."
psql -f "$PROJECT_DIR/sql/03_seed_tenant_a.sql"

echo ""
echo "=== [4/4] Seeding Tenant B + C (small, no ANALYZE) ==="
psql -f "$PROJECT_DIR/sql/04_seed_tenant_b.sql"

echo ""
echo "==========================================="
echo " Setup complete!"
echo "==========================================="
echo ""
echo " Statistics are now STALE (n_distinct=1, actual=3)."
echo ""
echo " Next steps:"
echo "   make benchmark   # Run automated before/after comparison"
echo "   make psql        # Connect as app_user (subject to RLS)"
echo "   make psql-super  # Connect as superuser (bypasses RLS)"
echo ""
