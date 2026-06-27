# Lua Coding Standards

## Style

- 2-space indent. No tabs.
- `snake_case` for locals and module fields. `SCREAMING_SNAKE` for module-level globals.
- Module pattern: `MyModule = {}` at top, `return MyModule` only if not using globals.
- Keep functions under 40 lines. Extract helpers.

## Safety

- Always `pcall` external calls that can fail (DB, exports from other resources).
- Check return values. `local ok, err = pcall(fn)` — handle both branches.
- Validate all inputs at the top of public functions before any logic runs.
- Never use `unpack` on untrusted client data without length check.

## Globals

- Core modules (`RPSTACK_LOG`, `RPSTACK_CONFIG`, etc.) are intentional globals — document ownership.
- Local variables for everything else. `local x = ...` not `x = ...`.
- Never write to another module's global table.

## Patterns to use

```lua
-- Result shape (consistent across all exports)
return { ok = true, data = ... }
return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND }

-- Input validation guard
local function validate(payload)
  if type(payload) ~= "table" then return false, RPSTACK_ERRORS.VALIDATION_FAILED end
  -- ...
  return true, nil
end

-- Safe external call
local ok, result = pcall(exports['rpstack-identity'].getSession, src)
if not ok then
  RPSTACK_LOG.error("module", "export call failed", { err = tostring(result) })
  return { ok = false, error = RPSTACK_ERRORS.INTERNAL }
end
```

## Patterns to avoid

- `table.insert` in hot loops — pre-allocate or index directly
- String concatenation in loops — use `table.concat`
- `pairs` on arrays — use `ipairs` or numeric for
- Nested callbacks more than 2 levels deep — extract named functions
