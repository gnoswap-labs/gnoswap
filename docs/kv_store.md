# KV Store (`p/store/`) & Version Manager (`p/version_manager/`)

## KV Store

Permission model: unregistered callers have no write access; registered callers can only be granted `Write`.

### Rules

- `AddAuthorizedCaller` and `UpdateAuthorizedCaller` accept `Write` only. Any zero or unknown permission value returns `ErrInvalidPermission`.
- `Get` and typed getters do not enforce read permissions. Sensitive read restrictions must be implemented by the realm exposing the data.
- Use `RemoveAuthorizedCaller` to revoke write access completely.
- Implementation realms must NOT receive `Write` permission (proxy already holds it).
- After every upgrade, audit the full authorized-caller table for each domain store.

## Version Manager

### Rules

- `ChangeImplementation` swaps the active implementation instance. Storage write access remains with the domain proxy realm through preserved realm context.
- Same-version upgrade triggers re-initialization. Ensure initializer handles this without corrupting existing state.
- Rollback is possible (activate a previous registered version). Test rollback paths.
- On upgrade: dependent modules (e.g., staker → emission) must manually re-register write access.

## Pitfalls

- Granting implementation realms direct `Write` access → bypasses the proxy-mediated storage model.
- Upgrade without permission re-registration → dependent modules lose write access.
- Re-initialization on same-version upgrade → potential state corruption if not idempotent.
