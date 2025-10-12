# GnoSwap Upgradeable Architecture

## Overview

GnoSwap is built on a **proxy pattern architecture** that enables **seamless upgrades**, **independent contract version management**, and **centralized data management without data migration**.

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

- **Stable Interface** - Public API never changes
- **Dynamic Routing** - Calls routed to current implementation
- **Upgrade Management** - Seamless implementation switching
- **Interface Contract** - Enforces implementation compatibility

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
│   ├── position.gno            # Position management (stub)
│   ├── swap.gno                # Swap functions (stub)
│   ├── getter.gno              # Getter functions (stub)
│   ├── errors.gno              # Error definitions
│   ├── assert.gno              # Assertion functions
│   ├── factory_param.gno       # Factory parameters
│   ├── pool_type.gno           # Pool type definitions
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
    IPoolGetter     // Data retrieval functions
}
```

### Key Features

- **Interface Compliance** - All versions implement IPool interface
- **Independent Development** - Each version developed separately
- **Backward Compatibility** - Interface ensures compatibility
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
- **No Data Migration** - All versions share same data

### Directory Structure

```
# IMMUTABLE CONTRACTS (Never upgraded)
p/gnoswap/store/                 # Core Storage Infrastructure
├── kv_store.gno                 # Generic key-value store
└── types.gno                    # Storage types

r/gnoswap/access/                # Access Control System
├── access.gno                   # Access assertions
├── assert.gno                   # Access validation
└── swap_whitelist.gno           # Swap whitelist management

r/gnoswap/rbac/                  # Role-Based Access Control
├── rbac.gno                     # Role management
├── role.gno                     # Role definitions
└── types.gno                    # RBAC types

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

r/gnoswap/emission/              # Emission Management
├── emission.gno                 # GNS emission logic
├── distribution.gno             # Distribution management
└── utils.gno                    # Emission utilities

r/gnoswap/gns/                   # GNS Token Management
├── gns.gno                      # GNS token contract
├── gns_emission.gno             # Emission logic
└── halving.gno                  # Halving mechanism

r/gnoswap/referral/              # Referral System
├── referral.gno                 # Referral logic
├── keeper.gno                   # Referral keeper
└── global_keeper.gno            # Global referral management

# VERSIONED CONTRACTS (Upgradeable business logic)
r/gnoswap/v1/                    # Version 1 implementations
├── pool/                        # Pool v1 implementation
├── position/                    # Position v1 implementation
├── router/                      # Router v1 implementation
├── staker/                      # Staker v1 implementation
├── gov/                         # Governance v1 implementations
│   ├── governance/              # Governance v1
│   ├── staker/                  # Gov staker v1
│   └── xgns/                    # xGNS v1
├── launchpad/                   # Launchpad v1
├── protocol_fee/                # Protocol fee v1
└── ...
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

- Deployed once and never modified
- Provide foundational services for all other contracts
- Critical for system security and stability

### 2. Upgrade Management Contracts (Manage Upgrades)

These contracts manage the upgrade process and coordinate between versions:

- **`r/gnoswap/pool`**: Pool domain management with proxy pattern
- **`r/gnoswap/emission`**: GNS emission and distribution management
- **`r/gnoswap/gns`**: GNS token management and halving mechanism
- **`r/gnoswap/referral`**: Referral system management

**Characteristics:**

- Manage upgrade processes for versioned contracts
- Coordinate between different contract versions
- Handle domain-specific business logic that doesn't change frequently

### 3. Versioned Contracts (Upgradeable Business Logic)

These contracts implement the actual business logic and can be upgraded:

- **`r/gnoswap/v1/pool`**: Pool implementation v1
- **`r/gnoswap/v1/position`**: Position management v1
- **`r/gnoswap/v1/router`**: Swap routing v1
- **`r/gnoswap/v1/staker`**: Staking and rewards v1
- **`r/gnoswap/v1/gov`**: Governance system v1
- **`r/gnoswap/v1/launchpad`**: Token launch platform v1
- **`r/gnoswap/v1/protocol_fee`**: Fee collection v1
- **`r/gnoswap/v1/community_pool`**: Community treasury v1

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
│ 1. getImpl() → Returns current impl      │
│ 2. Delegate to implementation           │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ IMPLEMENTATION: pool/v1/swap.gno         │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│ 1. halt.AssertIsNotHaltedPool()         │
│ 2. access.AssertIsAuthorized()          │
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
Interface ensures backward compatibility
```

### 3. Version Independence

```
pool/v1, pool/v2 → Use same pool/store
Deploying pool/v2 doesn't affect pool/v1
Data shared via centralized storage
```

### 4. Centralized Storage

```
Single storage system for all versions
Namespace-based isolation
No data migration required
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
│ - UpgradeImpl("pool/v2")                │
│ - Switches implementation pointer       │
│ - Updates storage permissions           │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Result:                                 │
│ - pool/v1 still registered              │
│ - pool/v2 now active                    │
│ - No data migration needed              │
│ - Zero downtime                         │
│ - v1 remains for rollback capability    │
└─────────────────────────────────────────┘
```

---

## Benefits

### 1. Zero-Downtime Upgrades

- Old and new versions coexist
- Instant implementation switching
- Instant rollback capability
- Previous versions remain registered for emergency rollback

### 2. No Data Migration

- Single centralized storage
- All versions share same data
- Interface ensures compatibility

### 3. Independent Contract Upgrades

- Upgrade pool without affecting other domains
- Interface validation ensures compatibility
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
- Interface prevents breaking changes
- Compile-time compatibility checking

### 2. Access Control

- Role-based storage permissions
- Namespace isolation
- Admin-only upgrade functions

### 3. Emergency Halt

- Per-domain halt capability
- Independent halt states
- Can halt specific implementations

### 4. Immutable Infrastructure

- Core storage cannot be upgraded
- Interface contracts are stable
- Predictable system behavior

---

## Implementation Details

### Registration Process

```go
// In pool/v1/init.gno
func init() {
    pool.RegisterInitializer(cross, func(poolStore pool.IPoolStore) pool.IPool {
        return NewPoolV1(poolStore)
    })
}
```

### Upgrade Process

```go
// In pool/upgrade.gno
func UpgradeImpl(cur realm, packagePath string) {
    caller := runtime.PreviousRealm().Address()
    access.AssertIsAdmin(caller)

    if _, ok := initializers[packagePath]; !ok {
        panic("Initializer not found")
    }

    poolImpl = initializers[packagePath](NewPoolStore(kvStore))
    // Update storage permissions...
}
```

### Proxy Routing

```go
// In pool/proxy.gno
func CreatePool(cur realm, token0Path, token1Path string, fee uint32, sqrtPriceX96 string) {
    getImpl().CreatePool(token0Path, token1Path, fee, sqrtPriceX96)
}

func getImpl() IPool {
    if poolImpl == nil {
        panic("pool implementation is not set")
    }
    return poolImpl
}
```

This proxy pattern architecture provides a robust, upgradeable foundation for GnoSwap while maintaining data consistency and enabling seamless feature evolution.
