#!/usr/bin/env bash
# Usage: PGHOST=... PGUSER=... PGPASSWORD=... PGDATABASE=... bash scripts/load/run-load-test.sh [N]
# Seeds N clients (default 50000), runs EXPLAIN ANALYZE on critical queries,
# saves reports to reports/load/<timestamp>/.

set -euo pipefail

N="${1:-50000}"
TS="$(date -u +%Y%m%d-%H%M%S)"
OUT="reports/load/${TS}"
mkdir -p "$OUT"

echo "[1/4] Seeding $N TEST_ clients..."
psql -v ON_ERROR_STOP=1 -v n="$N" -f scripts/load/seed-clients.sql > "$OUT/seed.log" 2>&1

echo "[2/4] EXPLAIN ANALYZE — critical queries"

run_explain() {
  local name="$1" sql="$2"
  echo "  -> $name"
  {
    echo "== $name =="
    echo "-- SQL: $sql"
    psql -c "EXPLAIN (ANALYZE, BUFFERS, VERBOSE) $sql"
  } > "$OUT/explain-${name}.txt" 2>&1
}

run_explain "clients_list_actif"       "SELECT * FROM public.clients WHERE actif = true ORDER BY created_at DESC LIMIT 50"
run_explain "clients_search_prefix"    "SELECT * FROM public.clients WHERE lower(nom) LIKE 'test_client_1%' LIMIT 20"
run_explain "clients_search_trgm"      "SELECT * FROM public.clients WHERE nom ILIKE '%client_123%' LIMIT 20"
run_explain "clients_by_ref"           "SELECT * FROM public.clients WHERE reference = 'TEST_CLI_0012345'"
run_explain "clients_ville_commune"    "SELECT count(*) FROM public.clients WHERE ville = 'Abidjan' AND commune = 'Cocody'"

echo "[3/4] pg_stat_statements — top 20 by total time"
psql -c "SELECT round(total_exec_time::numeric,1) AS total_ms, calls, round(mean_exec_time::numeric,2) AS mean_ms, substring(query,1,120) AS query FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20" > "$OUT/top-queries.txt" 2>&1 || echo "pg_stat_statements unavailable" > "$OUT/top-queries.txt"

echo "[4/4] Report summary"
{
  echo "# Load test report — $TS"
  echo "N test clients seeded: $N"
  echo ""
  echo "## Files"
  ls -1 "$OUT"
} > "$OUT/README.md"

echo ""
echo "✅ Done. Reports: $OUT"
echo "   Purge with:  psql -f scripts/load/purge-test-data.sql"