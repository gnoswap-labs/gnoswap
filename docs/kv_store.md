# KV Store (`p/store/`) & Version Manager (`p/version_manager/`)

## KV Store

Permission model: `None(0)` → `ReadOnly(1)` → `Write(2)`.

### Rules

- `UpdateAuthorizedCaller` accepts `ReadOnly` and `Write` only. `None` must use `RemoveAuthorizedCaller` — passing `None` to update escalates `None` to `ReadOnly`.
- Implementation realms must NOT receive `Write` permission (proxy already holds it).
- After every upgrade, audit the full authorized-caller table for each domain store.

## Version Manager

### Rules

- `ChangeImplementation` revokes write from all previous callers, then grants write to new implementation. This is the single source of permission change — do not bypass it.
- Same-version upgrade triggers re-initialization. Ensure initializer handles this without corrupting existing state.
- Rollback is possible (activate a previous registered version). Test rollback paths.
- On upgrade: dependent modules (e.g., staker → emission) must manually re-register write access.

## Pitfalls

- `UpdateAuthorizedCaller` with `None` → silent permission escalation.
- Upgrade without permission re-registration → dependent modules lose write access.
- Re-initialization on same-version upgrade → potential state corruption if not idempotent.
