# Threat Model

## Trust boundaries

| Actor                      | Trust level                          |
| -------------------------- | ------------------------------------ |
| RedM server process        | Trusted                              |
| Server-side Lua resources  | Trusted (our code)                   |
| Client-side Lua            | **Untrusted**                        |
| Network events from client | **Untrusted**                        |
| oxmysql / DB               | Trusted (parameterized queries only) |

## Attack surfaces

### 1. Network events

**Risk:** Client sends crafted payload to trigger economy, inventory, or permission changes.
**Mitigation:** Rate limiting per source per route. Input validation (type, range, ownership) on every handler. Never mutate state from unvalidated payload.

### 2. Identifier spoofing

**Risk:** Client claims to be a different player.
**Mitigation:** Identifiers resolved server-side only via `GetPlayerIdentifier`. Never accept identifier strings from client payload.

### 3. Economy exploits

**Risk:** Client sends negative amounts, overflow values, or triggers duplicate transactions.
**Mitigation:** Economy owns every balance mutation. Character cash/bank adjustments use the ledger; generic owner movements use validated economy account operations. Cross-owner transfers debit and credit atomically with an insufficient-funds condition. Amounts are positive bounded integers, and reasons and owner tokens are validated. Audit inserts are attempted after successful owner transfers and failures are logged, but an audit failure does not roll back the balance update. The current transaction schema does not provide idempotency keys, so callers must not retry an uncertain mutation as though it were idempotent.

### 4. Character selection abuse

**Risk:** Client selects a character they don't own by sending a different charId.
**Mitigation:** Server verifies `character.account_id == session.account_id` before activating.

### 5. SQL injection

**Risk:** Malicious strings in payload reach DB queries.
**Mitigation:** Parameterized queries only. Repository layer enforces this.

### 6. Resource restart abuse

**Risk:** Attacker triggers resource restart to clear in-memory state (bans, rate limits).
**Mitigation:** Bans stored in DB. Rate limit state is ephemeral (acceptable — restart resets window).

### 7. Faction rank escalation

**Risk:** A faction officer edits their own rank, edits an equal or higher rank, assigns a rank at their own authority level, or grants permissions they do not possess.
**Mitigation:** Rank creation and updates require `can_promote`. Both the target rank and resulting level must be strictly below the actor. The actor cannot edit their own assigned rank. Permission fields are boolean and allowlisted, and every enabled permission on the resulting rank must be held by the actor. Authorization completes before repository or audit writes.

## Out of scope (v0)

- DDoS / network-level attacks (handled by server infrastructure)
- txAdmin / console access (physical security concern)
- Lua sandbox escapes (Cfx.re runtime concern)
