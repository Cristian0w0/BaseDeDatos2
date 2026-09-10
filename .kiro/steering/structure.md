# Project Structure

```
BaseDeDatos2/
├── db/
│   ├── schema.sql          # DDL source of truth: types, tables, constraints, indexes
│   └── backups/            # Database dumps (*.dump, *.sql) — git-ignored
├── docs/                   # Documentation (diagrams, reports, etc.)
├── src/                    # Reserved for scripts or application code
├── .env.example            # Environment variable template
├── .gitignore
├── AGENTS.md               # AI agent guidelines
└── README.md
```

## Key Rules

- `db/schema.sql` is the only place where DDL lives. All schema changes go there.
- `db/backups/` is git-ignored — never commit dump files.
- `docs/` is for course deliverables and diagrams (ERD, relational model, etc.).
- `src/` is available for seed scripts or query files if needed.

## schema.sql Internal Structure

The file is organized in order of dependency:

1. **Custom types** (`CREATE TYPE`) — enums before tables
2. **Main tables** — independent tables first, then those with foreign keys
3. **Junction tables** — N:M relationships last (e.g., `detalle_pedido`)
4. **Indexes** — after all table definitions
