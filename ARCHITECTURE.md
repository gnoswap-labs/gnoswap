# GnoSwap Upgradeable Architecture

## Overview

GnoSwap uses permanent proxy realms, registered implementation versions, and proxy-owned storage. An implementation switch reuses that storage; it does not automatically migrate its schema or establish behavioral compatibility.

## Architecture Pattern

```
┌─────────────────────────────────────────────────────────────┐
│  PROXY LAYER: Public Interface                              │
│  - proxy.gno: Routes calls to current implementation        │
│  - upgrade.gno: Manages implementation upgrades             │
│  - types.gno: Defines IPool interface contract              │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ Delegates to
                          │
┌─────────────────────────────────────────────────────────────┐
│  IMPLEMENTATION LAYER: Versioned Business Logic             │
│  - v1/: Pool implementation v1                              │
│  - v2/: Pool implementation v2 (future)                     │
│  - Each version implements IPool interface                  │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ Uses
                          │
┌─────────────────────────────────────────────────────────────┐
│  STORAGE LAYER: Centralized Data Management                 │
│  - store.gno: Domain-specific storage access                │
│  - state.gno: Global state management                       │
│  - p/gnoswap/store: Core KV storage infrastructure          │
└─────────────────────────────────────────────────────────────┘
```

---

## Proxy Layer: Public Interface

### Purpose

Provides a stable public interface that routes calls to the current implementation version.

### Components

| Component       | Role                      | Key Features                               |
| --------------- | ------------------------- | ------------------------------------------ |
| **proxy.gno**   | Public API routing        | Routes all calls to current implementation |
| **upgrade.gno** | Implementation management | Registers and upgrades implementations     |
| **types.gno**   | Interface definition      | Defines IPool contract interface           |
| **state.gno**   | Global state management   | Manages implementation and initializers    |

### Key Features

- **Stable Entry Points** - Implementation switches retain the proxy's public API
- **Dynamic Routing** - Calls routed to current implementation
- **Upgrade Management** - Switches to a previously registered implementation
- **Interface Contract** - Checks the implementation's method interface; storage and behavior require separate compatibility review

### Directory Structure

```
pool/
├── proxy.gno                    # Public API functions
├── upgrade.gno                  # Implementation management
├── types.gno                    # IPool interface definition
├── state.gno                    # Global state management
└── store.gno                    # Domain storage access
```

---

## Implementation Layer: Versioned Business Logic

### Purpose

Implements versioned business logic with independent upgrade capability through interface compliance.

### Pool Implementation Structure

```
pool/
├── v1/                          # Pool implementation v1
│   ├── init.gno                # Registers v1 implementation
│   ├── manager.gno             # Pool management functions
│   ├── position.gno            # Position accounting
│   ├── swap.gno                # Swap execution
│   ├── getter.gno              # Read-only pool queries
│   ├── errors.gno              # Error definitions
│   ├── assert.gno              # Assertion functions
│   ├── factory_param.gno       # Factory parameters
│   ├── type.gno                # Swap state and cache types
│   ├── utils.gno               # Utility functions
│   └── gnomod.toml             # Module configuration
│
└── v2/                          # Pool implementation v2 (future)
    └── ...                      # Enhanced features
```

### Interface Compliance

Each implementation must implement the `IPool` interface:

```go
type IPool interface {
    IPoolManager    // Pool creation and management
    IPoolPosition   // Position operations (Mint, Burn, Collect)
    IPoolSwap       // Swap operations and protocol fees
    IPoolOracle     // Observation and cumulative-price queries
    IPoolGetter     // Data retrieval functions
}
```

### Key Features

- **Interface Compliance** - All versions implement IPool interface
- **Independent Development** - Each version developed separately
- **Interface Compatibility** - Versions must satisfy the same method interface; this does not prove storage or behavioral compatibility
- **Registration System** - Implementations register via initializers

---

## Storage Layer: Centralized Data Management

### Purpose

Provides centralized data storage with domain-specific access patterns.

### Components

| Component           | Role                           | Key Features                        |
| ------------------- | ------------------------------ | ----------------------------------- |
| **store.gno**       | Domain storage access          | Pool-specific storage operations    |
| **p/gnoswap/store** | Core KV storage infrastructure | Type-agnostic key-value storage     |
| **access**          | Access control                 | Role-based authorization            |
| **rbac**            | Role management                | Role registration and updates       |
| **halt**            | Emergency halt                 | Per-domain emergency stop mechanism |

### Key Features

- **Centralized Storage** - Single storage system for all versions
- **Namespace Isolation** - Domain-specific storage namespaces
- **Access Control** - Role-based storage permissions
- **Shared Storage** - Compatible versions reuse domain data; schema changes need explicit handling

### Directory Structure

```
# IMMUTABLE CONTRACTS (Never upgraded)
p/gnoswap/store/                 # Core Storage Infrastructure
├── kv_store.gno                 # Generic key-value store
└── types.gno                    # Storage types

r/gnoswap/access/                # Access Control System
├── access.gno                   # Role registry mirror
├── assert.gno                   # Access validation
└── errors.gno                   # Access errors

r/gnoswap/rbac/                  # Role-Based Access Control
├── rbac.gno                     # Role management
├── role.gno                     # Role definitions
└── consts.gno                   # Initial role addresses

r/gnoswap/halt/                  # Emergency Halt System
├── halt.gno                     # Halt management
├── config.gno                   # Halt configuration
└── types.gno                    # Halt types

# UPGRADE MANAGEMENT CONTRACTS (Manage upgrades)
r/gnoswap/pool/                  # Pool Domain Management
├── proxy.gno                    # Public API routing
├── upgrade.gno                  # Implementation management
├── types.gno                    # IPool interface definition
├── state.gno                    # Global state management
├── store.gno                    # Domain storage access
└── v1/                          # Pool implementation v1

r/gnoswap/position/              # Position Domain Management
├── proxy.gno                    # Public API routing
├── upgrade.gno                  # Implementation management
├── types.gno                    # IPosition interface definition
├── state.gno                    # Global state management
├── store.gno                    # Domain storage access
└── v1/                          # Position implementation v1

r/gnoswap/router/                # Router Domain Management
├── proxy.gno                    # Public API routing
├── upgrade.gno                  # Implementation management
├── types.gno                    # IRouter interface definition
├── state.gno                    # Global state management
├── store.gno                    # Domain storage access
└── v1/                          # Router implementation v1

r/gnoswap/staker/                # Staker Domain Management
├── proxy.gno                    # Public API routing
├── upgrade.gno                  # Implementation management
├── types.gno                    # IStaker interface definition
├── state.gno                    # Global state management
├── store.gno                    # Domain storage access
└── v1/                          # Staker implementation v1

...

# VERSIONED CONTRACTS (Upgradeable business logic)
r/gnoswap/pool/v1/               # Pool v1 implementation
r/gnoswap/position/v1/           # Position v1 implementation
r/gnoswap/router/v1/             # Router v1 implementation
r/gnoswap/staker/v1/             # Staker v1 implementation
...
```

---

## Contract Categories

### 1. Immutable Contracts (Never Upgraded)

These contracts form the core infrastructure and are never upgraded after deployment:

- **`p/gnoswap/store`**: Core storage infrastructure providing type-agnostic key-value storage
- **`r/gnoswap/access`**: Access control system managing role-based permissions
- **`r/gnoswap/rbac`**: Role-based access control for managing role addresses
- **`r/gnoswap/halt`**: Emergency halt system for protocol safety

**Characteristics:**

- No version-manager implementation switch; realm state can still change through its APIs
- Provide foundational services for all other contracts
- Critical for system security and stability

### 2. Upgrade Management Contracts (Manage Upgrades)

These contracts manage the upgrade process and coordinate between versions:

- **`r/gnoswap/pool`**: Pool domain management with proxy pattern
- **`r/gnoswap/position`**: Position domain management with proxy pattern
- **`r/gnoswap/router`**: Router domain management with proxy pattern
- **`r/gnoswap/staker`**: Staker domain management with proxy pattern
- Other domain contracts...

**Characteristics:**

- Manage upgrade processes for versioned contracts
- Coordinate between different contract versions
- Handle domain-specific business logic that doesn't change frequently

### 3. Versioned Contracts (Upgradeable Business Logic)

These contracts implement the actual business logic and can be upgraded:

- **`r/gnoswap/pool/v1`**: Pool implementation v1
- **`r/gnoswap/position/v1`**: Position management v1
- **`r/gnoswap/router/v1`**: Swap routing v1
- **`r/gnoswap/staker/v1`**: Staking and rewards v1
- Other versioned contracts...

**Characteristics:**

- Implement specific business logic
- Can be upgraded to new versions (v2, v3, etc.)
- Must implement defined interfaces for compatibility
- Share data through centralized storage

---

## Data Flow

### Complete Example: Pool Swap Operation

```
User Request
     │
     ▼
┌─────────────────────────────────────────┐
│ PROXY LAYER: pool/proxy.gno              │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│ 1. getImplementation()                 │
│ 2. Delegate to implementation           │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ IMPLEMENTATION: pool/v1/swap.gno         │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│ 1. Validate realm, lock, and halt state │
│ 2. Reject user call; validate swap      │
│ 3. Execute business logic               │
│ 4. store.Get/Set operations             │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ STORAGE LAYER: pool/store.gno            │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│ 1. kvStore.Get/Set with domain keys     │
│ 2. Type conversion and validation       │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ CORE STORAGE: p/gnoswap/store/kv_store.gno │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│ 1. Domain authorization check            │
│ 2. map[key]value storage                 │
│ 3. Type-agnostic (any type)              │
└─────────────────────────────────────────┘
```

---

## Key Design Principles

### 1. Clear Separation of Concerns

```
PROXY LAYER: "How to route calls to implementations?"
IMPLEMENTATION LAYER: "What business rules to apply?"
STORAGE LAYER: "Where to store and how to access data?"
```

### 2. Interface-Based Design

```
All implementations must implement IPool interface
Proxy routes calls to current implementation
Interface checks method compatibility, not storage schema or business semantics
```

### 3. Version Independence

```
pool/v1, pool/v2 → Use same pool/store
Registering a later version does not activate it while a current version exists
Data shared via centralized storage
```

### 4. Centralized Storage

```
Single storage system for all versions
Namespace-based isolation
Schema compatibility must be checked before switching versions
```

---

## Upgrade Process

### Example: Upgrading Pool from v1 to v2

```
┌─────────────────────────────────────────┐
│ Step 1: Deploy pool/v2                  │
│ - New contract with enhanced features   │
│ - Implements IPool interface            │
│ - Registers via RegisterInitializer()   │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Step 2: Call pool/upgrade.gno           │
│ - UpgradeImpl(cur, fullPackagePath)     │
│ - Switches implementation pointer       │
│ - Reuses proxy-owned storage access     │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Result:                                 │
│ - pool/v1 still registered              │
│ - pool/v2 now active                    │
│ - Shared data retained                  │
│ - Target initializer has run            │
│ - Prior version remains registered      │
└─────────────────────────────────────────┘
```

---

## Benefits

### 1. Registered Implementation Switching

- Old and new versions remain registered
- Switching executes the target initializer and updates the active instance
- A switch back also re-runs that version's initializer; it does not restore an earlier storage snapshot
- Rollback is safe only when the old code and initializer accept the current stored state

### 2. Shared Domain Storage

- Each domain owns its KV store
- Versions of that domain reuse its data
- The version manager supplies no automatic schema migration

### 3. Independent Contract Upgrades

- Each domain selects its own active implementation
- Cross-domain interfaces, hooks, and stored data still require compatibility review
- Version management via initializers

### 4. Strong Access Control

- Namespace-based isolation
- Role-based authorization
- Per-domain halt mechanism

### 5. Simplified Testing

- Each layer tested independently
- Clear boundaries and interfaces
- Easy to mock dependencies

---

## Security Considerations

### 1. Interface Compliance

- All implementations must implement IPool interface
- Proxy registration accepts the domain's typed initializer
- Updating the active instance type-asserts the result to the domain interface

### 2. Access Control

- Role-based storage permissions
- Namespace isolation
- Pool upgrades require admin or governance authorization and an unlocked pool
- Realm tokens are threaded explicitly into the version manager and validated via `rlm.IsCurrent()`, rejecting spoofed or stale crossing-frame tokens

### 3. Emergency Halt

- Per-domain halt capability
- Independent halt states
- Halt checks apply by operation/domain, not by registered implementation version

### 4. Immutable Infrastructure

- Core storage cannot be upgraded
- Interface contracts are stable
- State remains mutable through the infrastructure's authorized APIs

---

## Implementation Details

### Registration Process

The pool's initializer registers a realm-aware callback. The callback validates
the live token, initializes or validates existing store data, installs the
emission pool checker, and constructs the implementation:

```go
// In pool/v1/init.gno
func init(cur realm) {
    pool.RegisterInitializer(cross(cur), func(_ int, rlm realm, poolStore pool.IPoolStore) pool.IPool {
        access.AssertIsRlmCurrent(0, rlm)
        if err := initStoreData(0, rlm, poolStore); err != nil {
            panic(err)
        }
        emission.SetDefaultInitialPoolChecker(cross(rlm), func(poolPath string) bool {
            return pool.ExistsPoolPath(poolPath)
        })
        return NewPoolV1(poolStore)
    })
}
```

### Upgrade Process

```go
// In pool/upgrade.gno
func UpgradeImpl(cur realm, packagePath string) {
    caller := cur.Previous().Address()
    access.AssertIsAdminOrGovernance(caller)
    assertPoolUnlocked()

    // Thread the live crossing-frame token into the version manager. The
    // leading 0 is the v2 interrealm sentinel; the manager validates
    // rlm.IsCurrent() to reject spoofed/stale tokens before switching.
    if err := versionManager.ChangeImplementation(0, cur, packagePath); err != nil {
        panic(err)
    }

    if err := updateImplementation(); err != nil {
        panic(err)
    }
    // KVStore write access remains with the proxy realm.
}
```

### Proxy Routing

```go
// In pool/proxy.gno
func CreatePool(cur realm, token0Path, token1Path string, fee uint32, sqrtPriceX96 string) {
    getImplementation().CreatePool(0, cur, token0Path, token1Path, fee, sqrtPriceX96)
}

func getImplementation() IPool {
    if implementation == nil {
        panic("implementation is not initialized")
    }
    return implementation
}
```

See each domain's `upgrade.gno` and initializer for its authorization, validation, and initialization requirements before planning an implementation switch.
