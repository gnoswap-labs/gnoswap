# AGENTS.md - AI Agent Guide for GnoSwap

This is the canonical agent guide for this repository. `CLAUDE.md` is kept as a symlink to this file for tools that still look for the legacy name.

## Project Overview

GnoSwap is a concentrated liquidity AMM (Uniswap V3 fork) running on GnoVM. Pools, positions, router, staker, governance, launchpad, protocol fee, and support modules are deployed as Gno realms on gno.land. Pool state lives in a singleton pool realm.

## Tech Stack

- **Language**: Gno (`.gno`) - Go-like, deterministic, runs on GnoVM
- **AMM**: Uniswap V3 concentrated liquidity (Q64.96 sqrt price, tick-based)
- **Math**: `uint256`/`int256`, `gnsmath` (AMM calculations)
- **Storage**: Write-authorized KV stores, proxy/implementation pattern
- **Access**: RBAC with 2-step ownership
- **Tests**: Gno unit/file tests plus Docker-backed integration txtar tests

## Project Structure

```
contract/
├── p/gnoswap/
│   ├── gnsmath/         # AMM math: tick, liquidity, sqrt price, swap
│   ├── int256/          # 256-bit signed integers
│   ├── uint256/         # 256-bit unsigned integers + MulDiv
│   ├── rbac/            # Reusable RBAC data structures and helpers
│   ├── store/           # Permission-based KV store
│   ├── version_manager/ # Upgrade registration/activation
│   ├── fuzz/            # Deterministic fuzz generators
│   ├── fuzzutils/       # Fuzz runner/result helpers
│   ├── utils/           # Shared formatting/util helpers
│   └── consts/          # Protocol-wide constants
├── r/gnoswap/
│   ├── {pool,position,router,staker,launchpad,protocol_fee}/
│   │   └── v1/          # Current implementation realms behind proxy layers
│   ├── gov/{governance,staker}/ # Governance proxies with v1/ implementations
│   ├── gov/xgns/        # Governance voting-power token
│   ├── {pool,position,router,staker,launchpad,protocol_fee}/
│   │                    # Proxy layers (permanent entry points)
│   ├── access/          # Role mirror, queried by all realms
│   ├── rbac/            # Authoritative role source
│   ├── emission/        # GNS minting/distribution
│   ├── gns/             # GNS token contract
│   ├── gnft/            # GnoSwap NFT helpers/metadata
│   ├── community_pool/  # Governance-controlled treasury transfers
│   ├── halt/            # Granular emergency pause
│   ├── referral/        # Referral tracking
│   ├── common/          # Shared token/native-coin helpers, with a v1/ implementation
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

- The proxy/domain owns the initial KV write permission. Version-manager activation does not grant write permission to the implementation realm; cross-domain writer grants are explicit.
- `ChangeImplementation` reuses the domain store and existing ACLs. It does not revoke/re-register writers automatically. Initializers handle compatible state initialization or migration; update ACLs only when the required writer set changes.
- `contract/r/gnoswap/rbac/` is the authoritative role map; `contract/r/gnoswap/access/` is its synchronized mirror.
- `contract/r/gnoswap/halt/` has separate module/operation scopes, including pool, staker, router, position, withdrawals, protocol fees, community pool, and xGNS. Consult its scope definitions rather than assuming one global pause.

## Commands

```bash
# Run these commands from the repository/worktree root, not contract/.
# Prerequisites: Python 3 and a gno binary built from the matching
# gnoswap-labs/gno checkout. make test clones WORKDIR/gno if absent,
# but does not build/install the CLI.
python3 setup.py -w tmp                 # Relink an existing tmp/gno checkout
python3 setup.py --list-tests           # List integration txtar names

# Whole-repository formatting (includes temporary checkouts and fixtures).
# Do not run this for a documentation-only or otherwise narrowly scoped edit.
make fmt                               # gofumpt over all .gno files

# Package tests (Makefile runs setup.py, then gno test under <workdir>/gno/examples)
make test PKG=gno.land/r/gnoswap/pool/v1
make test PKG=gno.land/r/gnoswap/pool/v1 RUN=TestCreatePool
make test WORKDIR=tmp PKG=gno.land/p/gnoswap/gnsmath

# Integration tests
make integration-test
make integration-test-list
make integration-test-run TEST=pool_create_pool_and_mint
make integration-test-build
```

- The current `gno` CLI has no `build` subcommand. Use the repository's `make test` wrapper for compilation and runtime checks.
- `WORKDIR` defaults to `tmp`. Match the installed CLI to that checkout; `make -C tmp/gno install.gno` builds/installs it when needed.
- `setup.py -w <workdir>` replaces linked module directories under `<workdir>/gno/examples/gno.land` and links integration resources. Always specify the workdir; the script's standalone default is the home directory.
- `make setup`, `make clone`, and `make test-folder` use the legacy `scripts/test.sh` workflow, not the quick package-test wrapper. That workflow expects `tmp/gnoswap`, clones upstream `gnolang/gno`, patches a legacy stdlib path, and the folder runner temporarily renames test files. Do not use it as routine worktree setup or verification.
- `RUN=` maps to `gno test -run`; use regexes for subtests. Integration `TEST=` names come from `make integration-test-list`; the integration targets invoke `docker-compose`.
- Filetests and integration txtar cases are coarse-grained. Do not update golden/bless outputs without reviewing diffs.
- Package-test CI clones `gnoswap-labs/gno` master, builds the CLI, runs `setup.py`, updates fuzz seeds, and executes packages via `.github/scripts/run_tests.rb`. The workflow follows a branch, not a fixed toolchain revision.

## Conventions & Rules

### Gno Language

- Do not use goroutines, channels, or Go's OS/network/`unsafe` packages in Gno contracts. The Gno-specific `chain/runtime/unsafe` package is distinct and is intentionally used for limited transaction-envelope inspection.
- Contract imports use Gno stdlib paths (for example `errors`, `math`, and `chain/...`) or deployed `gno.land/p/...` / `gno.land/r/...` paths, not Go module paths such as `github.com/...`.
- Contract package configuration is `gnomod.toml`; the repository's Go tooling can separately use `go.mod`.
- **Realm** (`r/`) = stateful contract. **Package** (`p/`) = library with no independent persisted realm; library-created objects can hold data owned by their allocating realm. **Ephemeral** (`e/`) = temporary user execution, not a directory in this contract tree.
- Public transaction entry points use crossing signatures such as `func Foo(cur realm, ...)`. Exported helpers/getters are not automatically crossing functions.
- Do not introduce legacy `std` imports. Prefer the threaded realm token for identity:

| Old (`std`) | Preferred current API | Import |
|------------|-----------------------|--------|
| `std.PreviousRealm()` | `cur.Previous()` | builtin `realm` |
| `std.CurrentRealm()` | `cur.Address()` / `cur.PkgPath()` | builtin `realm` |
| `std.Address` | `address` (builtin) | - |
| `std.GetOrigSend()` | `unsafe.OriginSend()` for intentional transaction-envelope inspection | `chain/runtime/unsafe` |
| `std.Coin` / `std.Coins` | `chain.Coin` / `chain.Coins` | `chain` |
| `std.DerivePkgAddr()` | `chain.PackageAddress()` | `chain` |

Low-level `PreviousRealm()` / `CurrentRealm()` now live in `chain/runtime/unsafe`, not `chain/runtime`. They are not substitutes for a threaded realm token in authorization checks. `chain/runtime` still provides `AssertOriginCall()`.

### Interrealm (Cross-Realm)

- Ground VM behavior in the matching Gno checkout, especially `gnovm/adr/interrealm_v2.md` and `gnovm/adr/pr_cross_explicit.md`. The [published interrealm v2 guide](https://docs.gno.land/resources/gno-interrealm-v2/) is useful background but still contains older bare-`cross` examples.
- Production realm crossing functions have `realm` as their first parameter, for example `func Foo(cur realm, ...)`. Test functions and ephemeral `main` have VM-specific entrypoint exceptions; do not apply a blanket `/r/`-only rule to them.
- The current cross-call form is `callee.Foo(cross(cur), ...)` (or `cross(rlm)` in a helper), never bare `cross`. Its argument must be a realm-typed identifier; the VM checks that it is the current frame's token and creates the callee token.
- A same-realm noncrossing call such as `Foo(cur, ...)` does not introduce a crossing boundary. Implementation helpers commonly use `(_ int, rlm realm, ...)`, called as `(0, cur, ...)`, to receive the current context without declaring a crossing function.
- `cur` is an ephemeral capability token. Validate a forwarded token with `IsCurrent()` or the module's `AssertIsRlmCurrent` helper before using it for authorization.
- Never persist `realm` values; store `cur.Address()` or `cur.PkgPath()` instead.
- `/r/`-declared functions, methods, and closures borrow storage-context to their declaring realm. `/p/`/stdlib receiver methods borrow to the receiver's allocating realm when an object identity exists; `/p/` closures borrow to their construction realm. These storage borrows do not change realm-context.
- Direct external realm field/index access is readonly-tainted. Returning a value does not itself add that taint, but object ownership and mutation guards still apply; a returned reference is not unrestricted write authority.
- `panic()` crossing a realm boundary aborts the transaction; ordinary `recover()` cannot catch it. Use `revive(fn)` in tests only.
- If a module needs the deployment caller, capture `cur.Previous()` during `init(cur realm)`. Do not replace configured authority with an assumed deployer: RBAC, for example, initializes from its configured `ADMIN`.

### Access Control

- Use the current threaded realm token and `cur.Previous().Address()` for caller checks. Explicit crossings validate their source token in the VM; forwarded helper contexts still need their current-context checks. Never use `OriginCaller` as production authorization.
- Keep intentional `chain/runtime/unsafe` usage narrowly scoped. Reading the transaction's original coin envelope, as native-coin rejection does, is different from authenticating an immediate caller or attributing a payment.
- Privileged configuration/upgrades require the relevant role assertions. User-facing operations may instead enforce owner, approval, allowance, or other operation-specific checks; public router swaps do not require a user whitelist.
- On the router callback path, the pool-origin closure uses `access.AssertIsPool(caller)`, then delegated `SwapCallback` uses `assertIsRouterImplementation(caller)`. There is no `assertIsRouterV1` helper.
- Typed callback and initializer APIs are intentional. Preserve their fixed signatures, registration checks, caller checks, and settlement invariants rather than imposing a blanket ban on function arguments.

### Token Handling

- Use `SafeGRC20Transfer` / `SafeGRC20TransferFrom` when a transfer failure must abort. The common module also exposes error-returning `Transfer`, `TransferFrom`, and `Approve`; handle those errors explicitly.
- Pool-pair assets are GRC20 tokens. Router swaps reject native-coin handling and require token contract paths such as WUGNOT.
- In the matching Gno checkout, WUGNOT `Deposit(cur realm)` and `Withdraw(cur realm, amount int64)` enforce `runtime.AssertOriginCall()`. Do not add wrapping/unwrapping inside ordinary router/realm middleware.
  - Wrap through WUGNOT's permitted origin-call flow, approve spending separately, then let the router use token transfers.
  - To unwrap proceeds, return WUGNOT to the user for an origin-call withdrawal; the router does not unwrap it.
- Reject attached native coins on paths that do not handle them.
- Nonnegative token-transfer amounts must fit `int64` (`2^63 - 1`). Use checked conversions such as `gnsmath.SafeConvertToInt64` for `uint256` boundaries and `utils.SafeParseInt64` for decimal strings; do not rely on truncating low-word conversions.

### Math & Precision

- `uint256`/`int256` `Mul` and `Lsh` discard overflow. Use overflow-reporting arithmetic such as `AddOverflow` / `MulOverflow`, or prove and document bounds; shifts need explicit bounds when discarded bits would affect accounting.
- Validate `feePips < 1_000_000` - equal causes division by zero.
- Rounding must favor the pool: `amountIn` rounds up, `amountOut` rounds down.
- Never mix Q64.96 and Q128.128 formats without explicit conversion.
- TWAP: negative `tickDelta` must floor toward -infinity, not truncate toward zero.

### CEI & Reentrancy

- Persist affected accounting before exposing callbacks or transfers, and review each operation's actual settlement order. Do not assume every path completes all writes before external calls: swaps use optimistic callback settlement, and minting pulls tokens before its final pool save.
- The pool-wide reentrancy lock is the KV-store `Unlocked` key, managed by `pool/v1/lock.gno` through `SetUnlocked(0, rlm, false/true)`. Do not confuse it with the separate `Slot0.unlocked` field, which is not the live guard.
- Preserve the checks/effects/interaction ordering of reward collection, liquidity removal, and incentive finalization. A lock is not a substitute for correct accounting and callback validation.

## Module Watchpoints

Each module's detailed rules, key files, and pitfalls are documented in `docs/`.

| Module | Doc | Key Rule |
|--------|-----|----------|
| pool | [`docs/pool.md`](docs/pool.md) | Persist the global `Unlocked` store key before external interactions. Oracle uses the pre-swap tick. |
| position | [`docs/position.md`](docs/position.md) | Slippage uses actually received amounts. `IncreaseLiquidity` and `Reposition` can clear the `burned` marker. |
| router | [`docs/router.md`](docs/router.md) | The pool callback closure checks `AssertIsPool`; delegated `SwapCallback` checks `assertIsRouterImplementation`. |
| staker | [`docs/staker.md`](docs/staker.md) | Hooks execute mid-swap. Warmup final tier = `math.MaxInt64`. |
| emission | [`docs/emission.md`](docs/emission.md) | Emission-critical callers must handle `(amount, success)` from `MintAndDistributeGns`; optional callers may continue while emission is halted. |
| protocol_fee | [`docs/protocol_fee.md`](docs/protocol_fee.md) | Approve the protocol-fee realm, then call `AddToProtocolFee`; it reserves accounting and pulls tokens. Do not pre-transfer the same amount. |
| gov | [`docs/gov.md`](docs/gov.md) | Spend amounts are strictly positive. Voting weight uses timestamp smoothing anchored to proposal creation, not a block snapshot. Stake changes never fold protocol fees. |
| launchpad | [`docs/launchpad.md`](docs/launchpad.md) | Check vesting time arithmetic and funding assumptions; do not infer an overflow guard or a balance guarantee from a claimable-value calculation. |
| KV store | [`docs/kv_store.md`](docs/kv_store.md) | Add/Update accept `Write` only; use `RemoveAuthorizedCaller` to revoke. Implementation activation does not grant implementation realms `Write`. |

## AMM Core (Uniswap V3 Fork)

| Primitive | Format | Detail |
|-----------|--------|--------|
| sqrtPriceX96 | Q64.96 | sqrt(price) * 2^96 |
| feeGrowthGlobal | Q128.128 | Cumulative fee per unit liquidity |
| Tick range | int32 | `[-887272, 887272]` |
| Fee tiers | Fixed in current v1 | 0.01% / 0.05% / 0.3% / 1%; adding another tier requires an implementation change, not a configuration update |

**Swap loop**: find next tick -> `ComputeSwapStep` -> accumulate fees -> cross tick (`liquidityNet`) -> repeat until amount exhausted or price limit hit.

**Swap callback**: The pool sends output, invokes the supplied callback, and verifies payment. On the router path, the callback closure checks `access.AssertIsPool` before forwarding to `SwapCallback`, which checks `assertIsRouterImplementation`.

## Common Pitfalls

These are regression hazards and constraints, not a claim that every item is a current defect.

| Pitfall | Impact |
|---------|--------|
| `OriginCaller` for access control | Intermediate contract impersonates user |
| Treating `Slot0` as the reentrancy lock | Misses the pool-wide `Unlocked` KV-store guard |
| Assuming every operation has identical settlement ordering | Misses operation-specific callback, lock, and accounting requirements |
| Unchecked `Mul`/`Lsh` or critical `Add` | Silent overflow corrupts AMM math |
| Finite final warmup tier | Rejected when configuring the warmup template; the final duration must be `math.MaxInt64` |
| Assuming an implementation switch resets store ACLs | Proxy and writer permissions persist; update ACLs explicitly when the required writer set changes |
| Treating halted emission as successful minting | `MintAndDistributeGns` can return `(0, false)`; callers must handle it |
| Directly transferring centralized fees instead of approval + `AddToProtocolFee` | Bypasses accounting; `AddToProtocolFee` itself pulls the approved amount |
| Folding protocol fees inside a gov/staker stake change | Undelegate cost grows with the number of fee tokens |
| Checking slippage against owed rather than collected amounts | Can accept a payout below the user's minimum; preserve current actual-received checks |
| Wrapping/unwrapping WUGNOT inside ordinary realm middleware | Violates WUGNOT's `AssertOriginCall` restriction |
| Dropping the effective referrer returned by `TryRegister` | Loses the authoritative referral value; current router/position paths propagate it |
| Replacing negative TWAP floor with truncation toward zero | Reintroduces mean-tick rounding drift |

## Uniswap V3 Divergences

This comparison is with V3; V4's pool-manager architecture is different.

| Area | Uniswap V3 | GnoSwap |
|------|------------|---------|
| Pool deployment | Factory-deployed pool contracts | Singleton pool realm, shared store, and pool-wide lock |
| Transfer amounts | `uint256` | `int64` token-transfer boundaries; individual amounts must fit, irrespective of total token supply |
| Flash operations | Flash-loan entry point and callback-settled swaps | Callback-settled optimistic swaps; no separate flash-loan entry point |
| Position NFTs | Transferable | Unstaked NFTs use GRC721 ownership/approvals; staked positions move through the staker |
| Swap access | Permissionless | Public router swaps need no user whitelist; direct pool swaps require a contract caller |
| Protocol fee | Per-pool configuration | Global denominator configuration, per-pool swap fee balances; router, withdrawal, and staker fees use centralized token-path/epoch accounting |
| Router fee | No GnoSwap-style router output fee | On output tokens; initial default 15 bps (0.15%), configurable from 0 to 1000 bps (10%) |
| Fee tiers | Governance can enable additional tiers | Current v1 accepts four constant tiers; an implementation change is needed for more |
| Position key | Owner and tick range | Tick range within each pool's position tree; no owner or package-path component |

### Historical Audit Reports

Reports in [`audits/`](audits/) describe the revisions audited at their publication dates. They are not a current list of open findings or proof that later code is covered.

Recheck the present implementation and relevant tests before carrying a report conclusion forward. In particular, current single-hop router APIs accept price limits, exact-out targets are post-router-fee net amounts, and the pool lock is stored separately from `Slot0`. Do not retain historical claims to the contrary or label current modules "unaudited" without a revision-specific comparison.

## Navigation

| Need | Location |
|------|----------|
| AMM math | `contract/p/gnoswap/gnsmath/` |
| 256-bit arithmetic | `contract/p/gnoswap/uint256/`, `int256/` |
| Fuzz helpers | `contract/p/gnoswap/fuzz/`, `contract/p/gnoswap/fuzzutils/`, `contract/r/gnoswap/test/fuzz/` |
| Pool swap loop | `contract/r/gnoswap/pool/v1/swap.gno` |
| Pool state / Slot0 | `contract/r/gnoswap/pool/pool.gno` |
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
