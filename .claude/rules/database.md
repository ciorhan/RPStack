# Database Rules

## Driver

oxmysql only. Async via `MySQL.Async` or promise-based `MySQL.query`. Never raw `exports.oxmysql` calls scattered in business logic — always go through a repository function.

## Repository pattern

```
server/repositories/account_repo.lua   -- owns accounts table queries
server/repositories/character_repo.lua -- owns characters table queries
```

Business logic calls repo functions. Repo functions call oxmysql. Nothing else touches the DB directly.

## Migrations

- Migrations live in `migrations/` inside each resource.
- Named `001_create_accounts.sql`, `002_add_column.sql` — sequential, never renamed after merge.
- Migration runner (in rpstack-persistence) tracks applied migrations in a `_migrations` table.
- Migrations must be idempotent (`CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`).

## Schema rules

- Every table has `created_at DATETIME DEFAULT CURRENT_TIMESTAMP`.
- State-change tables (transactions, audit) also have `updated_at`.
- Use `VARCHAR` lengths that match validation (e.g. firstName max 24 → `VARCHAR(24)`).
- `account_id` is the FK used everywhere. Never store Cfx identifier strings as FKs.

## Query safety

- Always use parameterized queries: `MySQL.query("SELECT * FROM accounts WHERE id = ?", {id})`.
- Never concatenate user input into SQL strings.
- Log slow queries (> 50ms) with category and params (no PII).
