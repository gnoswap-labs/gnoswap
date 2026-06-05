# Version Manager

Runtime version management system for dynamic implementation switching without data migration.

## Overview

Version Manager implements a Strategy Pattern-based system that enables hot-swapping between different versioned implementations of the same domain (e.g., v1, v2, v3) while maintaining a unified storage layer. This approach allows seamless upgrades without downtime or migration overhead.

## Features

- **Zero-Downtime Upgrades**: Switch implementations at runtime without service interruption
- **Unified Storage**: All versions share a single KVStore owned by the domain (proxy) realm
- **Domain-Scoped Security**: Only authorized packages within the domain path can register
- **Hot-Swapping**: Instant version switching through dynamic strategy replacement
- **Secure by Design**: Implementation realms cannot directly modify storage (see Storage Access Model below)

**Pattern**: Strategy + Plugin Architecture

## Usage

### Step 1: Define Domain Interface

```go
// protocol_fee/types.gno
package protocol_fee

type ProtocolFee interface {
    SetFeeRatio(ratio uint64) error
    GetFeeRatio() uint64
}
```

### Step 2: Create Version Manager

```go
// protocol_fee/protocol_fee.gno
package protocol_fee

import "gno.land/p/gnoswap/version_manager"
import "gno.land/p/gnoswap/store"

var manager version_manager.VersionManager

func init(cur realm) {
    kvStore := store.NewKVStore(cur.Address())

    manager = version_manager.NewVersionManager(
        cur.PkgPath(),
        kvStore,
        // initializeDomainStoreFn carries the v2 interrealm marker (`_ int, rlm realm`):
        // the leading 0 surfaces realm-threading at the call site.
        func(_ int, rlm realm, kv store.KVStore) any {
            return NewProtocolFeeStore(kv)
        },
    )
}

func GetManager() version_manager.VersionManager {
    return manager
}

// RegisterInitializer is the crossing entry point each version package calls.
// `cur` is the live crossing-frame realm token; it is threaded straight into the
// version manager (the leading 0 is the v2 sentinel) so the manager can reject
// spoofed/stale tokens via rlm.IsCurrent() and identify the caller via rlm.Previous().
func RegisterInitializer(cur realm, initializer func(_ int, rlm realm, store any) any) {
    if err := manager.RegisterInitializer(0, cur, initializer); err != nil {
        panic(err)
    }
}

// UpgradeImpl switches the active version. Authorization (admin / governance) is
// enforced here in the /r/ realm; version_manager only rejects spoofed tokens.
func UpgradeImpl(cur realm, packagePath string) {
    if err := manager.ChangeImplementation(0, cur, packagePath); err != nil {
        panic(err)
    }
}
```

### Step 3: Implement Versions

```go
// protocol_fee/v1/v1.gno
package v1

import "gno.land/r/gnoswap/protocol_fee"

type protocolFeeV1 struct {
    store any
}

func init(cur realm) {
    // Register this version during package initialization.
    // `cross(cur)` invokes the domain's crossing entry point, which threads the
    // live realm token into the version manager.
    protocol_fee.RegisterInitializer(cross(cur), func(_ int, rlm realm, store any) any {
        return &protocolFeeV1{store: store}
    })
}

func (pf *protocolFeeV1) SetFeeRatio(ratio uint64) error {
    // v1 implementation
}

func (pf *protocolFeeV1) GetFeeRatio() uint64 {
    // v1 implementation
}
```

```go
// protocol_fee/v2/v2.gno
package v2

type protocolFeeV2 struct {
    store any
}

func init(cur realm) {
    // Register v2 — inactive until explicitly activated.
    protocol_fee.RegisterInitializer(cross(cur), func(_ int, rlm realm, store any) any {
        return &protocolFeeV2{store: store}
    })
}

func (pf *protocolFeeV2) SetFeeRatio(ratio uint64) error {
    // v2 improved implementation
}

func (pf *protocolFeeV2) GetFeeRatio() uint64 {
    // v2 improved implementation
}
```

### Step 4: Use Active Implementation

```go
// client code
import "gno.land/r/gnoswap/protocol_fee"

func UseFee() {
    manager := protocol_fee.GetManager()
    impl := manager.GetCurrentImplementation().(protocol_fee.ProtocolFee)

    ratio := impl.GetFeeRatio()
    // Use the active version's implementation
}
```

### Step 5: Switch Versions at Runtime

```go
// governance or admin entry point
func UpgradeToV2(cur realm) {
    // Hot-swap to v2 — zero downtime. `cross(cur)` enters UpgradeImpl's crossing
    // frame; UpgradeImpl threads the realm token into the version manager.
    protocol_fee.UpgradeImpl(cross(cur), "gno.land/r/gnoswap/protocol_fee/v2")
}
```

## Workflow

### Registration Flow

```
1. Domain package initializes version manager with KVStore
   ↓
2. v1 package calls RegisterInitializer (via the domain's crossing wrapper) during `init(cur realm)`
   → Manager validates the realm token (rlm.IsCurrent()) and caller domain path
   → Becomes active implementation
   ↓
3. v2 package calls RegisterInitializer during `init(cur realm)`
   → Registered for later activation
   ↓
4. v3 package calls RegisterInitializer during `init(cur realm)`
   → Registered
```

### Version Switching Flow

```
1. Admin/governance calls ChangeImplementation (via the domain's UpgradeImpl wrapper)
   → Authorization is enforced in the /r/ wrapper
   ↓
2. Version Manager validates the realm token (rlm.IsCurrent()), rejecting spoofed/stale tokens
   ↓
3. Version Manager retrieves v2's initializer
   ↓
4. Executes v2 initializer with shared KVStore
   ↓
5. Updates currentImplementation pointer to v2
   ↓
6. v2 is now the active implementation
```

### Storage Access Model

- **Domain Ownership**: The domain (proxy) realm owns the KVStore and has write permission
- **Explicit Realm Threading**: Registration/upgrade calls thread the live crossing-frame token (`rlm`) into the manager instead of relying on `runtime.CurrentRealm()`. The manager validates it with `rlm.IsCurrent()` (rejecting spoofed/stale tokens) and identifies the registering version package via `rlm.Previous()`
- **No Direct Permission Grants**: Implementation realms do not receive storage permissions directly; the proxy realm drives all storage access
- **Security by Design**: External callers cannot invoke implementation realms to modify storage

### Best Practices

1. **Version Registration**: All versions should register during `init(cur realm)`
2. **Interface Compliance**: Ensure all versions implement the same domain interface
3. **Storage Compatibility**: Design storage schema to be forward/backward compatible
4. **Testing**: Test version switching thoroughly before production use
5. **Rollback Support**: Keep previous versions registered for quick rollback capability

## Error Handling

The package returns errors for:

- A spoofed or stale realm token (`rlm.IsCurrent() == false` → `ErrSpoofedRealm`)
- Unauthorized caller attempting to register (not in domain path)
- Duplicate registration of the same package path
- Attempting to switch to an unregistered version
- Invalid initializer function type

## Use Cases

### Protocol Upgrades

Upgrade DeFi protocol logic without disrupting active users:

```go
// Upgrade fee calculation algorithm
protocol_fee.UpgradeImpl(cross(cur), "gno.land/r/gnoswap/protocol_fee/v2")
```

### A/B Testing

Test new implementations before full rollout:

```go
// Switch to experimental version
protocol_fee.UpgradeImpl(cross(cur), "gno.land/r/gnoswap/protocol_fee/experimental")

// Rollback if issues detected
protocol_fee.UpgradeImpl(cross(cur), "gno.land/r/gnoswap/protocol_fee/v1")
```

### Emergency Response

Quickly switch to a patched version during security incidents:

```go
// Deploy fixed version and immediately activate
protocol_fee.UpgradeImpl(cross(cur), "gno.land/r/gnoswap/protocol_fee/v1_hotfix")
```

## Implementation Notes

- Built on Strategy Pattern for runtime algorithm swapping
- Uses Plugin Architecture for dynamic version loading
- Storage access is driven by the proxy realm; the live realm token is threaded explicitly (the v2 `_ int, rlm realm` marker) and validated via `rlm.IsCurrent()`
- No data migration required - all versions share the same storage
- Type assertions required when retrieving current implementation
- Map used for efficient initializer storage and lookup

## Limitations

- **Type Safety**: Requires runtime type assertion to domain interface
- **Storage Schema**: Requires careful schema design for cross-version compatibility
- **Registration Order**: First registered version becomes the initial active implementation
- **Domain Call Requirement**: Implementation functions must be called through domain proxy for storage access

## Related Packages

- `gno.land/p/gnoswap/store`: KVStore with permission-based access control
