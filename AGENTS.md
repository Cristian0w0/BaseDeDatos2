# Repository Guidelines for Agents

## Project Context
PostgreSQL database schema for a Food Store application (UTN Base de Datos 2 course).

## Repository Structure & Key Locations
- `db/schema.sql`: Source of truth for database DDL (custom types, tables, constraints, indexes).
- `db/backups/`: Reserved directory for database dumps (`*.dump`, `*.sql`), ignored by git.

## Schema & Architecture Conventions
- **Database Engine**: PostgreSQL.
- **Primary Keys**: `BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY`.
- **Foreign Keys**: Defined with explicit constraint names and `ON DELETE RESTRICT`.
- **Timestamps**: `TIMESTAMPTZ NOT NULL DEFAULT now()`.
- **Derived Attributes**: Do not store calculated columns (e.g. line item subtotal is calculated as `cantidad * precio_unitario` in queries, not stored in `detalle_pedido`).
- **Domain Enums**: Defined via PostgreSQL `CREATE TYPE ... AS ENUM` (e.g., `forma_pago`).

## Verification & Execution
To apply or verify the schema on a PostgreSQL instance:
```bash
psql -U <user> -d <dbname> -f db/schema.sql
```

## Security

- Follow `.kiro/steering/security-policies.md` for all security-related work.
- Review and validate any database change before execution.
- Never expose or commit credentials, secrets, or sensitive database information.
