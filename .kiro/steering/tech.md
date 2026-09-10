# Tech Stack

## Database

- **Engine**: PostgreSQL
- **DDL file**: `db/schema.sql` — the single source of truth for the entire schema

## Schema Conventions

| Concern | Convention |
|---|---|
| Primary keys | `BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| Foreign keys | Named constraints (`fk_<table>_<ref>`), always `ON DELETE RESTRICT` |
| Check constraints | Named (`ck_<table>_<description>`) |
| Timestamps | `TIMESTAMPTZ NOT NULL DEFAULT now()` |
| Enums | `CREATE TYPE <name> AS ENUM (...)` defined before tables |
| Derived columns | Never stored — computed in queries instead |

## Naming Conventions

- Table and column names: `snake_case`, Spanish
- Constraint names follow the pattern: `pk_`, `fk_`, `ck_`, `idx_` prefixes
- Index names: `idx_<table>_<columns>`

## Common Commands

```bash
# Apply schema to a database
psql -U <user> -d <dbname> -f db/schema.sql

# Connect to the database
psql -U <user> -d <dbname>

# Create a backup
pg_dump -U <user> -Fc <dbname> > db/backups/<filename>.dump

# Restore from backup
pg_restore -U <user> -d <dbname> db/backups/<filename>.dump
```
