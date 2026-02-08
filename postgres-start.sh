#!/bin/bash
# PostgreSQL startup script with custom configuration

exec postgres \
  -c max_connections=100 \
  -c shared_buffers=2GB \
  -c effective_cache_size=5GB \
  -c work_mem=16MB \
  -c maintenance_work_mem=512MB \
  -c idle_in_transaction_session_timeout=300s \
  -c autovacuum_max_workers=3 \
  -c autovacuum_vacuum_scale_factor=0.05 \
  -c autovacuum_analyze_scale_factor=0.02 \
  -c autovacuum_naptime=10s \
  -c shared_preload_libraries='pg_stat_statements' \
  -c pg_stat_statements.max=10000 \
  -c pg_stat_statements.track=all

# These are the extensions we use:
# - pg_stat_statements: Tracks execution statistics of all SQL statements
# - pg_trgm: Provides functions for trigram matching (useful for fuzzy text search)
# - pgstattuple: Provides functions to obtain tuple-level statistics
# - pg_repack: Removes bloat from tables and indexes without requiring an exclusive lock