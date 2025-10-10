# GnoSwap Upgradeable Architecture

## Overview

GnoSwap is built on a **three-layer architecture** that enables **seamless upgrades**, **independent contract version management**, and **centralized data management without data migration**.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 2: Versioned Business Logic                          │
│  Independent contract versions (v1, v2, v3...)              │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ Uses
                          │
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: Domain Storage & Core Services                    │
│  Domain-specific storage access + Core services             │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ Uses
                          │
┌─────────────────────────────────────────────────────────────┐
│  LAYER 0: System Infrastructure                             │
│  Core infrastructure + Pure KV storage                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Layer 0: System Infrastructure

### Purpose

Provides immutable core infrastructure and pure key-value storage.

### Components

| Component      | Role                  | Characteristics                               |
| -------------- | --------------------- | --------------------------------------------- |
| **storage**    | Pure KV storage       | Type-agnostic, namespace-based access control |
| **access**     | Access control        | Role → Address mapping management             |
| **rbac**       | Role management       | Role registration/updates, version management |
| **halt**       | Emergency halt        | Per-version emergency stop mechanism          |
| **dependency** | Dependency management | Contract dependency tracking and validation   |

### Key Features

- **Immutable** - No upgrades after deployment
- **Generic** - No domain knowledge required
- **Infrastructure only** - Foundation for all upper layers

### Directory Structure

```
sys/
├── storage/                    # Pure KV Storage
│   ├── kv_store.gno           # Generic key-value store
│   ├── namespace.gno          # Namespace constants
│   ├── authorization.gno      # Namespace access control
│   └── doc.gno
│
├── access/                     # Access Control
│   ├── registry.gno           # Role → Address mapping
│   ├── assertions.gno         # Access assertions
│   ├── getters.gno            # Role address getters
│   └── doc.gno
│
├── rbac/                       # Role-Based Access Control
│   ├── rbac.gno                # Role management
│   ├── roles.gno              # Role constants
│   ├── events.gno             # RBAC events
│   └── doc.gno
│
├── halt/                       # Emergency Halt
│   ├── halt.gno                # Halt state management
│   ├── assertions.gno         # Halt checks
│   ├── config.gno             # Halt configuration
│   └── doc.gno
│
└── dependency/                 # Dependency Manager
    ├── registry.gno           # Dependency registration
    ├── resolver.gno           # Dependency resolution
    └── doc.gno
```

---

## Layer 1: Domain Storage & Core Services

### Purpose

Provides domain-specific storage access interfaces and immutable core services.

### Components

| Domain             | Role                                        | Key Files                    |
| ------------------ | ------------------------------------------- | ---------------------------- |
| **gns**            | GNS token contract                          | `token.gno`                  |
| **xgns**           | xGNS token contract                         | `token.gno`                  |
| **gnft**           | Gnoswap NFT contract                        | `token.gno`                  |
| **emission**       | Emission service + Central storage access   | `storage.gno`                |
| **referral**       | Referral service + Central storage access   | `storage.gno`                |
| **common**         | Common utilities + Storage access + Upgrade | `storage.gno`, `upgrade.gno` |
| **pool**           | Pool storage access + Upgrade               | `storage.gno`, `upgrade.gno` |
| **position**       | Position storage access + Upgrade           | `storage.gno`, `upgrade.gno` |
| **router**         | Router storage access + Upgrade             | `storage.gno`, `upgrade.gno` |
| **staker**         | Staker storage access + Upgrade             | `storage.gno`, `upgrade.gno` |
| **gov/governance** | Governance storage access + Upgrade         | `storage.gno`, `upgrade.gno` |
| **gov/staker**     | Gov staker storage access + Upgrade         | `storage.gno`, `upgrade.gno` |
| **launchpad**      | Launchpad storage access + Upgrade          | `storage.gno`, `upgrade.gno` |
| **protocol_fee**   | Protocol fee storage access + Upgrade       | `storage.gno`, `upgrade.gno` |
| **community_pool** | Community pool storage access + Upgrade     | `storage.gno`, `upgrade.gno` |

### Key Features

- **Immutable** - No modifications after deployment
- **Namespace-based storage** - Each domain has isolated storage namespace
- **Upgrade functions** - Manages contract version transitions
- **Extensible** - New domains can be added

### Directory Structure

```
r/
├── gns/                           # GNS Token
├── xgns/                          # xGNS Token
├── gnft/                          # Gnoswap NFT
│
├── emission/                      # Emission Service
│   └── storage.gno                # Central storage access
│
├── referral/                      # Referral Service
│   └── storage.gno                # Central storage access
│
├── common/                        # Common Utilities
│   ├── upgrade.gno                # Contract upgrade/downgrade
│   └── storage.gno                # Central storage access
│
├── pool/                          # Pool Domain
│   ├── upgrade.gno                # Contract upgrade/downgrade
│   └── storage.gno                # Central storage access
│
├── position/                      # Position Domain
│   ├── upgrade.gno                # Contract upgrade/downgrade
│   └── storage.gno                # Central storage access
│
├── router/                        # Router Domain
│   ├── upgrade.gno                # Contract upgrade/downgrade
│   └── storage.gno                # Central storage access
│
├── staker/                        # Staker Domain
│   ├── upgrade.gno                # Contract upgrade/downgrade
│   └── storage.gno                # Central storage access
│
├── gov/
│   ├── governance/                # Governance Domain
│   │   ├── upgrade.gno            # Contract upgrade/downgrade
│   │   └── storage.gno            # Central storage access
│   │
│   └── staker/                    # Gov Staker Domain
│       ├── upgrade.gno            # Contract upgrade/downgrade
│       └── storage.gno            # Central storage access
│
├── launchpad/                     # Launchpad Domain
│   ├── upgrade.gno                # Contract upgrade/downgrade
│   └── storage.gno                # Central storage access
│
├── protocol_fee/                  # Protocol Fee Domain
│   ├── upgrade.gno                # Contract upgrade/downgrade
│   └── storage.gno                # Central storage access
│
└── community_pool/                # Community Pool Domain
    ├── upgrade.gno                # Contract upgrade/downgrade
    └── storage.gno                # Central storage access
```

---

## Layer 2: Versioned Business Logic

### Purpose

Implements versioned business logic with independent upgrade capability.

### Common Structure

Each domain contract follows this structure:

```
{domain}/
├── v1/
│   ├── accessor.gno           # Storage accessor to domain storage
│   ├── register.gno           # Dependency registration
│   └── ...                   # Business logic files
│
└── v2/
    ├── accessor.gno           # Storage accessor to domain storage
    ├── register.gno           # Dependency registration
    └── ...                   # Business logic files + new features
```

### Domains

| Domain             | v1 Features                                |
| ------------------ | ------------------------------------------ |
| **common**         | Basic utilities                            |
| **pool**           | Swap, Liquidity, Fee                       |
| **position**       | Mint, Burn, Increase, Decrease, CollectFee |
| **router**         | Exact In/Out, Multi-hop                    |
| **staker**         | Stake, Unstake, Rewards                    |
| **gov/governance** | Proposal, Voting, Execution                |
| **gov/staker**     | Delegation, Rewards                        |
| **launchpad**      | Project, Deposit, Rewards                  |
| **protocol_fee**   | Collection                                 |
| **community_pool** | Transfer                                   |

### Key Features

- **Independent versioning** - Each domain upgrades independently
- **Business logic only** - Focus on domain rules
- **Dependency management** - Inter-contract calls via sys/dependency

### Directory Structure

```
common/
├── v1/                        # Common contract v1
│   ├── accessor.gno           # Storage accessor
│   └── register.gno           # Dependency registration
└── v2/                        # Common contract v2

pool/
├── v1/                        # Pool contract v1
│   ├── accessor.gno           # Storage accessor
│   └── register.gno           # Dependency registration
└── v2/                        # Pool contract v2

position/
├── v1/                        # Position contract v1
│   ├── accessor.gno           # Storage accessor
│   └── register.gno           # Dependency registration
└── v2/                        # Position contract v2

router/
├── v1/                        # Router contract v1
│   ├── accessor.gno           # Storage accessor
│   └── register.gno           # Dependency registration
└── v2/                        # Router contract v2

staker/
├── v1/                        # Staker contract v1
│   ├── accessor.gno           # Storage accessor
│   └── register.gno           # Dependency registration
└── v2/                        # Staker contract v2

gov/
├── governance/
│   ├── v1/                    # Governance contract v1
│   │   ├── accessor.gno       # Storage accessor
│   │   └── register.gno       # Dependency registration
│   └── v2/                    # Governance contract v2
│
├── staker/
│   ├── v1/                    # Gov Staker contract v1
│   │   ├── accessor.gno       # Storage accessor
│   │   └── register.gno       # Dependency registration
│   └── v2/                    # Gov Staker contract v2
│
└── xgns/
    ├── v1/                    # xGNS contract v1
    │   ├── accessor.gno       # Storage accessor
    │   └── register.gno       # Dependency registration
    └── v2/                    # xGNS contract v2

launchpad/
├── v1/                        # Launchpad contract v1
│   ├── accessor.gno           # Storage accessor
│   └── register.gno           # Dependency registration
└── v2/                        # Launchpad contract v2

protocol_fee/
├── v1/                        # Protocol Fee contract v1
│   ├── accessor.gno           # Storage accessor
│   └── register.gno           # Dependency registration
└── v2/                        # Protocol Fee contract v2

community_pool/
├── v1/                        # Community Pool contract v1
│   ├── accessor.gno           # Storage accessor
│   └── register.gno           # Dependency registration
└── v2/                        # Community Pool contract v2
```

---

## Data Flow

### Complete Example: Pool Swap Operation

```
User Request
     │
     ▼
┌─────────────────────────────────────────┐
│ LAYER 2: pool/v2/swap.gno               │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│ 1. sys/halt check                       │
│ 2. sys/access check                     │
│ 3. accessor.gno:                        │
│    pool/storage.Get("pools")  ────┐     │
│ 4. Execute business logic         │     │
│ 5. accessor.gno:                  │     │
│    pool/storage.Set("pools")  ────┤     │
└───────────────────────────────────│─────┘
                                    │
                                    ▼
┌─────────────────────────────────────────┐
│ LAYER 1: pool/storage.gno               │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│ sys/storage.Get("pool", key)  ────┐     │
│ sys/storage.Set("pool", key)  ────┤     │
└───────────────────────────────────│─────┘
                                    │
                                    ▼
┌─────────────────────────────────────────┐
│ LAYER 0: sys/storage/kv_store.gno       │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│ - Namespace authorization check         │
│ - map[namespace][key]value storage      │
│ - Type-agnostic (string only)           │
└─────────────────────────────────────────┘
```

---

## Key Design Principles

### 1. Clear Separation of Concerns

```
LAYER 0: "Where to store and who can access?"
LAYER 1: "What to store and how to access?"
LAYER 2: "What business rules to apply?"
```

### 2. Unidirectional Dependency

```
LAYER 2 → LAYER 1 → LAYER 0
(Lower layers are unaware of upper layers)
```

### 3. Version Independence

```
pool/v1, pool/v2 → Use same pool/storage
Deploying pool/v2 doesn't affect pool/v1
Data shared via sys/storage
```

### 4. Namespace Isolation

```
Each domain has isolated storage namespace
pool → "pool" namespace
position → "position" namespace
Prevents cross-domain data corruption
```

---

## Upgrade Process

### Example: Upgrading Pool from v1 to v2

```
┌─────────────────────────────────────────┐
│ Step 1: Deploy pool/v2                  │
│ - New contract with enhanced features   │
│ - TWAP Oracle added                     │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Step 2: Register in sys/rbac            │
│ - rbac.UpdateRoleAddressNextVersion()   │
│ - POOL role now points to v2 address    │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Step 3: Call pool/upgrade.gno           │
│ - Activates v2 as primary version       │
│ - Updates sys/dependency registry       │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Result:                                 │
│ - pool/v1 still operational             │
│ - pool/v2 now active                    │
│ - No data migration needed              │
│ - Zero downtime                         │
└─────────────────────────────────────────┘
```

---

## Benefits

### 1. Zero-Downtime Upgrades

- Old and new versions coexist
- Gradual traffic migration
- Instant rollback capability

### 2. No Data Migration

- Single centralized storage (sys/storage)
- All versions share same data
- Append-only schema evolution

### 3. Independent Contract Upgrades

- Upgrade pool without upgrading position
- Dependency validation ensures compatibility
- Version matrix managed by sys/dependency

### 4. Strong Access Control

- Namespace-based isolation
- Role-based authorization
- Per-version halt mechanism

### 5. Simplified Testing

- Each layer tested independently
- Clear boundaries and interfaces
- Easy to mock dependencies

---

## Security Considerations

### 1. Namespace Authorization

- Each namespace has authorized contract list
- sys/storage validates caller before write
- Prevents unauthorized data access

### 2. Version Validation

- sys/dependency tracks version compatibility
- Incompatible version calls are rejected
- Safe inter-contract communication

### 3. Emergency Halt

- Per-version halt capability
- Independent halt states
- Can halt v2 while keeping v1 operational

### 4. Immutable Infrastructure

- Layer 0 and Layer 1 cannot be upgraded
- Core security guarantees maintained
- Predictable system behavior
