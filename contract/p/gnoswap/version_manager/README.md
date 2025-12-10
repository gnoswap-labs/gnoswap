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

func init() {
    kvStore := store.NewKVStore("protocol_fee")

    manager = version_manager.NewVersionManager(
        "gno.land/r/gnoswap/protocol_fee",
        kvStore,
        func(kv store.KVStore) any {
            return NewProtocolFeeStore(kv)
        },
    )
}

func GetManager() version_manager.VersionManager {
    return manager
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

func init() {
    // Register this version during package initialization
    manager := protocol_fee.GetManager()
    manager.RegisterInitializer(func(store any) any {
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

func init() {
    // Register v2
    manager := protocol_fee.GetManager()
    manager.RegisterInitializer(func(store any) any {
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
// governance or admin function
func UpgradeToV2() error {
    manager := protocol_fee.GetManager()

    // Hot-swap to v2 - zero downtime
    return manager.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/v2")
}
```

## Workflow

### Registration Flow

```
1. Domain package initializes version manager with KVStore
   ↓
2. v1 package calls RegisterInitializer during init()
   → Becomes active implementation
   ↓
3. v2 package calls RegisterInitializer during init()
   → Registered (available for switching)
   ↓
4. v3 package calls RegisterInitializer during init()
   → Registered (available for switching)
```

### Version Switching Flow

```
1. Admin calls ChangeImplementation("path/to/v2")
   ↓
2. Version Manager retrieves v2's initializer
   ↓
3. Executes v2 initializer with shared KVStore
   ↓
4. Updates currentImplementation pointer to v2
   ↓
5. v2 is now the active implementation
```

### Storage Access Model

- **Domain Ownership**: The domain (proxy) realm owns the KVStore and has write permission
- **Realm Context Preservation**: When domain calls implementation, `runtime.CurrentRealm()` remains the domain realm
- **No Direct Permission Grants**: Implementation realms do not receive storage permissions directly
- **Security by Design**: External callers cannot invoke implementation realms to modify storage

### Best Practices

1. **Version Registration**: All versions should register during `init()`
2. **Interface Compliance**: Ensure all versions implement the same domain interface
3. **Storage Compatibility**: Design storage schema to be forward/backward compatible
4. **Testing**: Test version switching thoroughly before production use
5. **Rollback Support**: Keep previous versions registered for quick rollback capability

## Error Handling

The package returns errors for:

- Unauthorized caller attempting to register (not in domain path)
- Duplicate registration of the same package path
- Attempting to switch to an unregistered version
- Invalid initializer function type

## Use Cases

### Protocol Upgrades

Upgrade DeFi protocol logic without disrupting active users:

```go
// Upgrade fee calculation algorithm
manager.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/v2")
```

### A/B Testing

Test new implementations before full rollout:

```go
// Switch to experimental version
manager.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/experimental")

// Rollback if issues detected
manager.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/v1")
```

### Emergency Response

Quickly switch to a patched version during security incidents:

```go
// Deploy fixed version and immediately activate
manager.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/v1_hotfix")
```

## Implementation Notes

- Built on Strategy Pattern for runtime algorithm swapping
- Uses Plugin Architecture for dynamic version loading
- Storage access controlled via realm context (`runtime.CurrentRealm()`)
- No data migration required - all versions share the same storage
- Type assertions required when retrieving current implementation
- AVL tree used for efficient initializer storage and lookup

## Limitations

- **Type Safety**: Requires runtime type assertion to domain interface
- **Storage Schema**: Requires careful schema design for cross-version compatibility
- **Registration Order**: First registered version becomes the initial active implementation
- **Domain Call Requirement**: Implementation functions must be called through domain proxy for storage access

## Related Packages

- `gno.land/p/gnoswap/store`: KVStore with permission-based access control
- `gno.land/p/nt/avl`: AVL tree for initializer storage
