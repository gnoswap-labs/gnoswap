# AGENTS.md - AI Agent Guide for GnoSwap

This is the canonical agent guide for this repository. `CLAUDE.md` is kept as a symlink to this file for tools that still look for the legacy name.

## Project Overview

GnoSwap is a concentrated liquidity AMM (Uniswap V3 fork) running on GnoVM. Pools, positions, router, staker, governance, launchpad, protocol fee, and support modules are deployed as Gno realms on gno.land. Pool state lives in a singleton pool realm.

## Tech Stack

- **Language**: Gno (`.gno`) - Go-like, deterministic, runs on GnoVM
- **AMM**: Uniswap V3 concentrated liquidity (Q64.96 sqrt price, tick-based)
- **Math**: `uint256`/`int256`, `gnsmath` (AMM calculations)
- **Storage**: Permission-based KV store, proxy/implementation pattern
- **Access**: RBAC with 2-step ownership
- **Tests**: Gno unit/file tests plus Docker-backed integration txtar tests

## Project Structure

```
contract/
├── p/gnoswap/
│   ├── gnsmath/         # AMM math: tick, liquidity, sqrt price, swap
│   ├── int256/          # 256-bit signed integers
│   ├── uint256/         # 256-bit unsigned integers + MulDiv
│   ├── rbac/            # Stateless RBAC infra
│   ├── store/           # Permission-based KV store
│   ├── version_manager/ # Upgrade registration/activation
│   ├── fuzz/            # Deterministic fuzz generators
│   ├── fuzzutils/       # Fuzz runner/result helpers
│   ├── utils/           # Shared formatting/util helpers
│   └── consts/          # Protocol-wide constants
├── r/gnoswap/
│   ├── {pool,position,router,staker,launchpad,protocol_fee}/
│   │   └── v1/          # Current implementation realms behind proxy layers
│   ├── gov/{governance,staker}/v1/ # Governance implementation realms
│   ├── {pool,position,router,staker,launchpad,protocol_fee}/
│   │                    # Proxy layers (permanent entry points)
│   ├── access/          # Role mirror, queried by all realms
│   ├── rbac/            # Authoritative role source
│   ├── emission/        # GNS minting/distribution
│   ├── gns/             # GNS token contract
│   ├── gnft/            # GnoSwap NFT helpers/metadata
│   ├── halt/            # Granular emergency pause
│   ├── referral/        # Referral tracking
│   ├── common/          # Realm utilities: GRC20 helpers, native coins
│   ├── mock/            # Shared realm mocks for tests
│   ├── test/            # Fuzz and test harness packages
│   └── test_token/      # Local test token realms
└── r/scenario/          # Scenario/filetest packages

tests/
├── integration/         # Docker/Gno integration txtar tests and bless tooling
├── deploy/              # Deployment code generation helpers
└── scripts/             # Test/deploy helper make fragments
```

**Proxy pattern**: `User -> Proxy (permanent) -> Implementation v1 -> Storage (KV, shared across versions)`

- Proxy holds write permission. Implementation does NOT.
- On `ChangeImplementation`: old write access is revoked. Dependent modules must manually re-register write access.
- `r/rbac/` = authoritative role map. `r/access/` = synchronized mirror.
- `r/halt/` pauses pool / staker / router / position / withdrawals independently.

## Commands

```bash
# One-time setup / linking into a Gno checkout
make setup
python3 setup.py -w <workdir>          # Links modules into <workdir>/gno/examples/gno.land
python3 setup.py --list-tests          # Lists integration txtar tests

# Format
make fmt                               # gofumpt over all .gno files

# Package tests (Makefile runs setup.py, then gno test under <workdir>/gno/examples)
make test PKG=gno.land/r/gnoswap/pool/v1
make test PKG=gno.land/r/gnoswap/pool/v1 RUN=TestCreatePool
make test WORKDIR=tmp PKG=gno.land/p/gnoswap/gnsmath

# Folder/filetest runner used by legacy scripts
make test-folder FOLDER=contract/r/gnoswap/pool/v1

# Integration tests
make integration-test
make integration-test-list
make integration-test-run TEST=pool_create_pool_and_mint
make integration-test-build
```

- `gno build` does not exist. Use `gno test` for compilation + runtime checks.
- For direct `gno test`, run `python3 setup.py -w <workdir>` first, then test from `<workdir>/gno/examples`.
- `RUN=` maps to `gno test -run`; use regexes for subtests.
- Filetests and integration txtar cases are coarse-grained. Do not update golden/bless outputs without reviewing diffs.
- CI clones `gnoswap-labs/gno`, runs `setup.py`, updates fuzz seeds, and executes package tests via `.github/scripts/run_tests.rb`.

## Conventions & Rules

### Gno Language

- Never use goroutines, channels, `os`, `net`, `unsafe` in contract code.
- Import paths: `gno.land/p/...` or `gno.land/r/...` only. Never `github.com/...`.
- Module config: `gnomod.toml`, not `go.mod`.
- **Realm** (`r/`) = stateful contract. **Package** (`p/`) = stateless library. **Ephemeral** (`e/`) = temporary user code.
- Public `MsgCall` entry points in `/r/` packages are crossing functions: `func Foo(cur realm, ...)`.
- `std` package is deprecated in production code:

| Old (`std`) | New | Import |
|------------|-----|--------|
| `std.PreviousRealm()` | `runtime.PreviousRealm()` | `chain/runtime` |
| `std.CurrentRealm()` | `runtime.CurrentRealm()` | `chain/runtime` |
| `std.Address` | `address` (builtin) | - |
| `std.GetOrigSend()` | `banker.OriginSend()` | `chain/banker` |
| `std.Coin` / `std.Coins` | `chain.Coin` / `chain.Coins` | `chain` |
| `std.DerivePkgAddr()` | `chain.PackageAddress()` | `chain` |

### Interrealm (Cross-Realm)

- Interrealm v2 source of truth: <https://docs.gno.land/resources/gno-interrealm-v2/>.
- Crossing functions: `func Foo(cur realm, ...)` - `cur realm` must be first parameter and only `/r/` packages may declare them.
- External cross-call: `realm.Foo(cross(cur), ...)` - shifts both realm-context and storage-context to the callee realm and finalizes on boundary return.
- Same-realm helper call: `Foo(cur, ...)` - no realm-context/storage-context shift, no realm boundary, no finalization.
- `cur` is an ephemeral capability token. Check `cur.IsCurrent()` before deriving caller identity from `cur`, `cur.Previous()`, or `cur.PkgPath()`.
- Never persist `realm` values; store `cur.Address()` or `cur.PkgPath()` instead.
- `/r/`-declared functions/methods borrow storage-context to their declaring realm. `/p/`/stdlib receiver methods borrow to the receiver's allocating realm. Borrows do NOT change realm-context.
- External realm field/index access is readonly-tainted. Function returns are NOT tainted.
- `panic()` crossing a realm boundary aborts the transaction; ordinary `recover()` cannot catch it. Use `revive(fn)` in tests only.
- Save deployer in `init()` via `runtime.PreviousRealm()` - only opportunity.

### Access Control

- In crossing entry points, validate `cur.IsCurrent()` and use `cur.Previous().Address()` for caller checks. Never use `OriginCaller` for production access control.
- `runtime.PreviousRealm()` is still valid for init-time deployer capture and low-level parity checks, but prefer threaded `cur realm` values in public APIs.
- Every public state-changing function must have a role/permission assertion.
- `SwapCallback` must verify both: `access.AssertIsPool(caller)` + `assertIsRouterV1()`.
- Never accept arbitrary/variable functions as arguments for cross-calling.

### Token Handling

- Use `SafeGRC20Transfer` / `SafeGRC20TransferFrom` only. Panic on failure.
- Pools are GRC-20 only.
- **WUGNOT `Deposit`/`Withdraw` cannot be called cross-realm** (`runtime.AssertOriginCall()` enforced).
  - Deposit: user calls `wugnot.Deposit()` directly -> `Approve()` -> contract uses `TransferFrom(cross(cur), ...)`.
  - Withdraw: contract sends via `wugnot.Transfer(cross(cur), user, amt)` -> user calls `Withdraw()` in separate tx.
- Unexpected GNOT in non-native path: revert.
- Transfer cap: `int64` max (`2^63 - 1`). Use `safeConvertToInt64` at all boundaries.

### Math & Precision

- `uint256`/`int256` `Mul` and `lsh` do NOT detect overflow. Add explicit range checks.
- Validate `feePips < 1_000_000` - equal causes division by zero.
- Rounding must favor the pool: `amountIn` rounds up, `amountOut` rounds down.
- Never mix Q64.96 and Q128.128 formats without explicit conversion.
- TWAP: negative `tickDelta` must floor toward -infinity, not truncate toward zero.

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
| sqrtPriceX96 | Q64.96 | sqrt(price) * 2^96 |
| feeGrowthGlobal | Q128.128 | Cumulative fee per unit liquidity |
| Tick range | int | `[-887272, 887272]` |
| Fee tiers | fixed | 0.01% / 0.05% / 0.3% / 1% - no new tiers post-deploy |

**Swap loop**: find next tick -> `ComputeSwapStep` -> accumulate fees -> cross tick (`liquidityNet`) -> repeat until amount exhausted or price limit hit.

**Swap callback**: Pool sends output -> `SwapCallback` on router -> router sends input to pool. Both `AssertIsPool` + `assertIsRouterV1` required.

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
| `wugnot.Deposit(cross(cur))` in contract | Panics - `AssertOriginCall` enforced |
| `TryRegister` return ignored | Inconsistent referral state |
| TWAP rounding truncates toward zero | Off-by-1 from Uniswap reference |

## Uniswap V3/V4 Divergences

| Area | Uniswap V3/V4 | GnoSwap |
|------|--------------|---------|
| Pool deployment | Factory (isolated) | Singleton realm - bug affects all pools |
| Transfer amounts | `uint256` | `int64` at boundary - high-supply tokens panic |
| Flash loans | Supported | Not supported |
| Position NFTs | Transferable | Non-transferable (except to/from staker) |
| Swap access | Permissionless | Permissioned - whitelist required |
| Protocol fee | Per-pool | Global across all pools |
| Router fee | None | On output tokens (default 0.1%, cap 10%) |
| Fee tiers | Governance adds new | Fixed 4 tiers post-deploy |
| Position key | Owner-derived | `positionPackagePath` + tick range (no owner) |

### Audit Findings (OpenZeppelin 2025)

- **Sandwich/MEV** (N-04): Router hardcodes `sqrtPriceLimitX96 = 0`. Only slippage tolerance as protection.
- **Pool Init Griefing** (N-03): No price-oracle check on `CreatePool`. Recovery: wide-range mint -> corrective swap -> remove.
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
| Fuzz helpers | `contract/p/gnoswap/fuzz/`, `contract/p/gnoswap/fuzzutils/`, `contract/r/gnoswap/test/fuzz/` |
| Pool swap loop | `contract/r/gnoswap/pool/v1/swap.gno` |
| Pool state / Slot0 | `contract/r/gnoswap/pool/v1/pool.gno` |
| Position lifecycle | `contract/r/gnoswap/position/v1/` |
| Router paths | `contract/r/gnoswap/router/v1/` |
| Reward calculation | `contract/r/gnoswap/staker/v1/reward_calculation*.gno` |
| External incentives | `contract/r/gnoswap/staker/v1/external_incentive.gno` |
| Governance | `contract/r/gnoswap/gov/governance/`, `contract/r/gnoswap/gov/staker/` |
| Protocol fee | `contract/r/gnoswap/protocol_fee/v1/` |
| Emission | `contract/r/gnoswap/emission/` |
| GNS token | `contract/r/gnoswap/gns/` |
| GNFT metadata | `contract/r/gnoswap/gnft/` |
| Access control | `contract/r/gnoswap/rbac/`, `contract/r/gnoswap/access/` |
| KV store | `contract/p/gnoswap/store/kv_store.gno` |
| Upgrade | `contract/p/gnoswap/version_manager/`, `*/upgrade.gno` |
| Emergency pause | `contract/r/gnoswap/halt/` |
| Scenario/file tests | `contract/r/scenario/`, `tests/integration/testdata/` |
