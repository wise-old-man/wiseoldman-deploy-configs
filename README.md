# wiseoldman-deploy-config

A collection of useful files for the Wise Old Man server configuration.

## Postgres Extensions that MUST be manually installed:
- pg_stat_statements: Tracks execution statistics of all SQL statements
- pg_trgm: Provides functions for trigram matching (useful for fuzzy text search)
- pgstattuple: Provides functions to obtain tuple-level statistics
- pg_repack: Removes bloat from tables and indexes without requiring an exclusive lock