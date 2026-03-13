# CLAUDE.md — AI Agent Guide for GnoSwap

## Project Overview

GnoSwap is a concentrated liquidity AMM (Uniswap V3 fork) running on GnoVM. Pools, positions, router, staker, and governance are deployed as Gno realms on gno.land. All pool state lives in a single singleton realm.

## Tech Stack

- **Language**: Gno (`.gno`) — Go-like, deterministic, runs on GnoVM
- **AMM**: Uniswap V3 concentrated liquidity (Q64.96 sqrt price, tick-based)
- **Math**: `uint256`/`int256`, `gnsmath` (AMM calculations)
- **Storage**: Permission-based KV store, proxy/implementation pattern
- **Access**: RBAC with 2-step ownership

## Project Structure

```
contract/
├── p/gnoswap/
│   ├── gnsmath/         # AMM math: sqrt_price_math, swap_math
│   ├── int256/          # 256-bit signed integers
│   ├── uint256/         # 256-bit unsigned integers + MulDiv
│   ├── rbac/            # Stateless RBAC infra
│   ├── store/           # Permission-based KV store
│   ├── version_manager/ # Upgrade registration/activation
│   └── consts/          # Protocol-wide constants
└── r/gnoswap/
    ├── v1/{pool,position,router,staker,gov,launchpad,protocol_fee,community_pool}/
    ├── {pool,position,router,staker}/  # Proxy layers (permanent entry points)
    ├── access/          # Role mirror, queried by all realms
    ├── rbac/            # Authoritative role source
    ├── emission/        # GNS minting/distribution
    ├── gns/             # GNS token contract
    ├── halt/            # Granular emergency pause
    ├── referral/        # Referral tracking
    └── common/          # tick_math, coins
```

**Proxy pattern**: `User → Proxy (permanent) → Implementation v1 → Storage (KV, shared across versions)`

- Proxy holds write permission. Implementation does NOT.
- On `ChangeImplementation`: old write revoked. Dependent modules must manually re-register write access.
- `r/rbac/` = authoritative role map. `r/access/` = synchronized mirror.
- `r/halt/` pauses pool / staker / router / position / withdrawals independently.

## Commands

```bash
# Format
gno fmt <path>                        # If fails: gofumpt -w -l <path>

# Test
cd contract/r/gnoswap/<module>/v1
gno test -v .                         # All tests (unit + filetest)
gno test -run TestFoo .               # Filter by name (regex)
gno test -run "TestMain/sub" .        # Filter subtests
gno test --update-golden-tests .      # Update filetest expectations
gno test -print-events .              # Print emitted events
gno test -print-runtime-metrics .     # Show gas/memory/cycles
```

- `gno build` does not exist. Use `gno test` for compilation + runtime checks.
- Filetests cannot be selectively run by function; always use `gno test -v .`.
- Review golden test diffs carefully — `--update-golden-tests` may write incorrect outputs.

## Conventions & Rules

### Gno Language

- Never use goroutines, channels, `os`, `net`, `unsafe`.
- Import paths: `gno.land/p/...` or `gno.land/r/...` only. Never `github.com/...`.
- Module config: `gnomod.toml`, not `go.mod`.
- **Realm** (`r/`) = stateful contract. **Package** (`p/`) = stateless library. **Ephemeral** (`e/`) = temporary user code.
- `std` package is **deprecated**:

| Old (`std`) | New | Import |
|------------|-----|--------|
| `std.PreviousRealm()` | `runtime.PreviousRealm()` | `chain/runtime` |
| `std.CurrentRealm()` | `runtime.CurrentRealm()` | `chain/runtime` |
| `std.Address` | `address` (builtin) | — |
| `std.GetOrigSend()` | `banker.OriginSend()` | `chain/banker` |
| `std.Coin` / `std.Coins` | `chain.Coin` / `chain.Coins` | `chain` |
| `std.DerivePkgAddr()` | `chain.PackageAddress()` | `chain` |

### Interrealm (Cross-Realm)

- Crossing functions: `func Foo(cur realm, ...)` — `cur realm` must be first parameter.
- External cross-call: `realm.Foo(cross, ...)` — shifts both realm-context and storage-context.
- Same-realm call: `Foo(cur, ...)` — crossing but `CurrentRealm == PreviousRealm`.
- Non-crossing method on external object: borrows storage-context, does NOT change realm-context.
- External realm field/index access → **readonly-tainted**. Function returns are NOT tainted.
- `panic()` crossing realm boundary **aborts the machine** — `recover()` impossible. Use `revive(fn)` in tests only.
- Save deployer in `init()` via `runtime.PreviousRealm()` — only opportunity.

### Access Control

- Use `runtime.PreviousRealm().Address()` for caller checks. Never use `OriginCaller`.
- Every public state-changing function must have a role/permission assertion.
- `SwapCallback` must verify both: `access.AssertIsPool(caller)` + `assertIsRouterV1()`.
- Never accept arbitrary/variable functions as arguments for cross-calling.

### Token Handling

- Use `SafeGRC20Transfer` / `SafeGRC20TransferFrom` only. Panic on failure.
- Pools are GRC-20 only.
- **WUGNOT `Deposit`/`Withdraw` cannot be called cross-realm** (`runtime.AssertOriginCall()` enforced).
  - Deposit: user calls `wugnot.Deposit()` directly → `Approve()` → contract uses `TransferFrom(cross, ...)`.
  - Withdraw: contract sends via `wugnot.Transfer(cross, user, amt)` → user calls `Withdraw()` in separate tx.
- Unexpected GNOT in non-native path: revert.
- Transfer cap: `int64` max (`2^63 - 1`). Use `safeConvertToInt64` at all boundaries.

### Math & Precision

- `uint256`/`int256` `Mul` and `lsh` do NOT detect overflow. Add explicit range checks.
- Validate `feePips < 1_000_000` — equal causes division by zero.
- Rounding must favor the pool: `amountIn` rounds up, `amountOut` rounds down.
- Never mix Q64.96 and Q128.128 formats without explicit conversion.
- TWAP: negative `tickDelta` must floor toward −∞, not truncate toward zero.

### CEI & Reentrancy

- All state updates before token transfers (Checks-Effects-Interactions).
- Persist reentrancy lock via `SetSlot0(...)` before external calls. Local copy mutation has no effect.
- `CollectReward` / `DecreaseLiquidity` / `EndExternalIncentive` must follow CEI.

## Module Watchpoints

Each module's detailed rules, key files, and pitfalls are documented in `docs/`.

| Module | Doc | Key Rule |
|--------|-----|----------|
| pool | [`docs/pool.md`](docs/pool.md) | Persist `SetSlot0(...)` before external calls. Oracle uses pre-swap tick. |
| position | [`docs/position.md`](docs/position.md) | Slippage on actually-received amounts. `burned = true` blocks increase. |
| router | [`docs/router.md`](docs/router.md) | SwapCallback: both `AssertIsPool` + `assertIsRouterV1` required. |
| staker | [`docs/staker.md`](docs/staker.md) | Hooks execute mid-swap. Warmup final tier = `math.MaxInt64`. |
| emission | [`docs/emission.md`](docs/emission.md) | Always check `bool` return from `MintAndDistributeGns`. |
| protocol_fee | [`docs/protocol_fee.md`](docs/protocol_fee.md) | Every fee transfer must call `AddToProtocolFee`. |
| gov | [`docs/gov.md`](docs/gov.md) | Spend amount strictly positive. Snapshot at proposal creation. |
| launchpad | [`docs/launchpad.md`](docs/launchpad.md) | Vesting overflow check. Claimable must match balance. |
| KV store | [`docs/kv_store.md`](docs/kv_store.md) | `RemoveAuthorizedCaller` for `None`. Implementation gets no `Write`. |

## AMM Core (Uniswap V3 Fork)

| Primitive | Format | Detail |
|-----------|--------|--------|
| sqrtPriceX96 | Q64.96 | √price × 2^96 |
| feeGrowthGlobal | Q128.128 | Cumulative fee per unit liquidity |
| Tick range | int | `[-887272, 887272]` |
| Fee tiers | fixed | 0.01% / 0.05% / 0.3% / 1% — no new tiers post-deploy |

**Swap loop**: find next tick → `ComputeSwapStep` → accumulate fees → cross tick (`liquidityNet`) → repeat until amount exhausted or price limit hit.

**Swap callback**: Pool sends output → `SwapCallback` on router → router sends input to pool. Both `AssertIsPool` + `assertIsRouterV1` required.

## Common Pitfalls

| Pitfall | Impact |
|---------|--------|
| `OriginCaller` for access control | Intermediate contract impersonates user |
| Reentrancy lock on local `Slot0` copy | Lock never persists |
| Transfer before state update | CEI violated; re-entry with stale state |
| `Mul`/`lsh` without range check | Silent overflow corrupts AMM math |
| Finite final warmup tier | Panic when block time passes it |
| Upgrade without permission re-registration | Dependent modules lose write access |
| Halted emission not tolerated | Halt cascades to unrelated modules |
| Fee transfer without `AddToProtocolFee` | Fees permanently locked |
| Slippage on owed amounts (not received) | User receives less than minimum |
| `wugnot.Deposit(cross)` in contract | Panics — `AssertOriginCall` enforced |
| `TryRegister` return ignored | Inconsistent referral state |
| TWAP rounding truncates toward zero | Off-by-1 from Uniswap reference |

## Uniswap V3/V4 Divergences

| Area | Uniswap V3/V4 | GnoSwap |
|------|--------------|---------|
| Pool deployment | Factory (isolated) | Singleton realm — bug affects all pools |
| Transfer amounts | `uint256` | `int64` at boundary — high-supply tokens panic |
| Flash loans | Supported | Not supported |
| Position NFTs | Transferable | Non-transferable (except to/from staker) |
| Swap access | Permissionless | Permissioned — whitelist required |
| Protocol fee | Per-pool | Global across all pools |
| Router fee | None | On output tokens (default 0.1%, cap 10%) |
| Fee tiers | Governance adds new | Fixed 4 tiers post-deploy |
| Position key | Owner-derived | `positionPackagePath` + tick range (no owner) |

### Audit Findings (OpenZeppelin 2025)

- **Sandwich/MEV** (N-04): Router hardcodes `sqrtPriceLimitX96 = 0`. Only slippage tolerance as protection.
- **Pool Init Griefing** (N-03): No price-oracle check on `CreatePool`. Recovery: wide-range mint → corrective swap → remove.
- **Staker Hook Reentrancy** (C-02): Hooks execute inside swap loop. Lock prevents re-entering `Swap` but not inconsistent reads.
- **TWAP Oracle** (H-01, L-08): Pre-swap tick used. Negative rounding fixed. Oracle internals remain unaudited.
- **String Numbers** (N-05): `strconv.ParseInt` sites are potential panics/truncations. Verify `safeConvertToInt64`.
- **Protocol Fee Tracking** (M-06): Every `SafeGRC20Transfer` to protocol_fee must pair with `AddToProtocolFee`.
- **Router Fee Exact-Out** (C-07): User receives `amount - routerFee`. Not V3-compatible for exact-out.

## Navigation

| Need | Location |
|------|----------|
| AMM math | `contract/p/gnoswap/gnsmath/` |
| 256-bit arithmetic | `contract/p/gnoswap/uint256/`, `int256/` |
| Pool swap loop | `contract/r/gnoswap/pool/v1/swap.gno` |
| Pool state / Slot0 | `contract/r/gnoswap/pool/v1/pool.gno` |
| Position lifecycle | `contract/r/gnoswap/position/v1/` |
| Router paths | `contract/r/gnoswap/router/v1/` |
| Reward calculation | `contract/r/gnoswap/staker/v1/reward_calculation*.gno` |
| External incentives | `contract/r/gnoswap/staker/v1/external_incentive.gno` |
| Governance | `contract/r/gnoswap/gov/` |
| Protocol fee | `contract/r/gnoswap/protocol_fee/v1/` |
| Emission | `contract/r/gnoswap/emission/` |
| GNS token | `contract/r/gnoswap/gns/` |
| Access control | `contract/r/gnoswap/rbac/`, `contract/r/gnoswap/access/` |
| KV store | `contract/p/gnoswap/store/kv_store.gno` |
| Upgrade | `contract/p/gnoswap/version_manager/`, `*/upgrade.gno` |
| Emergency pause | `contract/r/gnoswap/halt/` |
| Tick math | `contract/r/gnoswap/common/tick_math.gno` |
