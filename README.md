# wiseoldman-deploy-config

A collection of useful files for the Wise Old Man server configuration.

# Server Layout
WOM used to run on one server, but we had to split into two because it became hard and expensive to vertically scale that one server.

We've now split it into two:
- Core
  - Runs all the services, except the Job Runner server.
- Worker
  - Runs the Job Runner server, and a few metric collection services for it.
    - Those services send the metrics back to the Core server, which then aggregates everything into Prometheus.

You'll find that the root directory has two directories that directly correspond to those two servers, and contain the relevant configuration files for each.

We also have a `check-config-drift.sh` script that we can run on either server to check if any of the configuration files have been modified since the last deployment. This is useful to ensure that we don't accidentally make manual changes to the configuration files on the servers, which would cause drift from our source of truth in this repository. (We don't use any git syncs on the server, all changes to those configs are manual.)

```bash
./check-config-drift.sh core    # Check the core server
./check-config-drift.sh worker  # Check the worker server
```

## Postgres Extensions that MUST be manually installed:
- pg_stat_statements: Tracks execution statistics of all SQL statements
- pg_trgm: Provides functions for trigram matching (useful for fuzzy text search)
- pgstattuple: Provides functions to obtain tuple-level statistics
- pg_repack: Removes bloat from tables and indexes without requiring an exclusive lock
