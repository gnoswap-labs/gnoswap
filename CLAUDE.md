# CLAUDE.md — AI Agent Guide for GnoSwap

> Read alongside [README.md](./README.md) and [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## 1. Gnolang — What Differs From Go

`.gno` files look like Go but run in **GnoVM** deterministically.

- No goroutines, channels, `os`, `net`, `unsafe` — ever.
- Import paths: `gno.land/p/...` or `gno.land/r/...` only. Never `github.com/...`.
- Module config: `gnomod.toml`, not `go.mod`.
- Tests: `_test.gno` (unit), `_filetest.gno` (VM filetests with `// Output:`).
- Format: `gno fmt`.

**Realm** (`r/`) = stateful smart contract, persists state on-chain.  
**Package** (`p/`) = stateless library, no stored state, no realm imports.

---

## 2. Interrealm Semantics (Read Carefully)

This is the most security-relevant part of Gno for GnoSwap.

### 2.1 Realm Context vs Storage Context

Two independent contexts govern every function call:

| Context | What it tracks | When it changes |
|---------|---------------|-----------------|
| **Realm-context** | Identity / agency (`CurrentRealm`, `PreviousRealm`) | Only on explicit `fn(cross, ...)` |
| **Storage-context** | Where new objects are persisted | On `cross` calls AND implicit borrow-crosses |

```gno
runtime.CurrentRealm()   // realm last cross-called to
runtime.PreviousRealm()  // realm before the last cross-call
```

### 2.2 Cross vs Non-Cross Calls

```gno
fn(cross, ...)  // explicit cross-call: shifts BOTH realm-context AND storage-context
fn(nil, ...)    // non-crossing call: NO context change
fn(cur, ...)    // within same realm: technically crossing but current==previous
```

`fn(nil, ...)` on an external realm's function is a **type-check error** (runtime error if variable). You cannot non-cross-call into a different realm.

### 2.3 Implicit Borrow-Cross (Important for Methods)

Calling a **non-crossing method** on a real object residing in a different realm:
- Storage-context shifts to the receiver's realm ("borrow").
- Realm-context does NOT change — `CurrentRealm()` / `PreviousRealm()` stay the same.
- The method can only mutate objects stored in that receiver's realm.

### 2.4 Readonly Taint

Accessing an external realm's object via dot-selector or index-expression taints the result **read-only**. Taint propagates through chains (`ext.Field.Sub[0]` — all readonly).

- Global vars of external realms are protected from direct write.
- Objects returned by a **function** are **not** tainted — security gap.

```gno
// DANGEROUS: alice.GetBlacklist() returns untainted slice
// alice.FilterList(cross, alice.GetBlacklist()) → alice mutates its own blacklist
```

### 2.5 Panic Across Realm Boundaries

A `panic()` that crosses a realm boundary **aborts the machine** — caller cannot `recover()`. Use `revive(fn)` in tests to catch cross-realm aborts.

### 2.6 Access Control Pattern

```gno
// WRONG: intermediate contract can impersonate any user
if std.OriginCaller() != admin { panic(...) }

// CORRECT: checks immediate caller
if std.PreviousRealm().Addr() != admin { panic(...) }
```

`OriginCaller` = tx signer. `PreviousRealm` = direct caller. Never confuse them.

### 2.7 `init()` and Deployer

`runtime.PreviousRealm()` returns the deployer **only** inside `init()` and global var declarations. Save it there or lose it permanently.

---

## 3. GnoSwap Architecture

### 3.1 Full Directory Map

```
contract/
├── p/gnoswap/
│   ├── gnsmath/         # AMM math: sqrt_price_math.gno, swap_math.gno
│   ├── int256/          # 256-bit signed integers
│   ├── uint256/         # 256-bit unsigned integers + MulDiv (fullmath.gno)
│   ├── rbac/            # ownable.gno, rbac.gno, role.gno (stateless infra)
│   ├── store/           # kv_store.gno — permission-based KV store
│   ├── version_manager/ # version_manager.gno — upgrade registration/activation
│   └── consts/          # protocol-wide constants
│
└── r/gnoswap/
    ├── v1/                      # Versioned implementations
    │   ├── pool/                # Concentrated liquidity core
    │   │   ├── swap.gno         # Swap execution, reentrancy lock, oracle
    │   │   ├── pool.gno         # Pool data structures, Slot0
    │   │   ├── position.gno     # Per-pool position tracking
    │   │   ├── manager.gno      # Pool creation
    │   │   ├── liquidity_math.gno
    │   │   └── transfer.gno     # Token transfer helpers
    │   ├── position/            # LP position NFT management
    │   │   ├── mint.gno         # Position creation
    │   │   ├── burn.gno         # Position burning (sets burned flag)
    │   │   ├── liquidity_management.gno
    │   │   ├── reposition.gno   # Tick range change
    │   │   ├── manager.gno
    │   │   ├── position.gno
    │   │   └── native_token.gno # GNOT wrapping helpers (minimal — most in frontend)
    │   ├── router/              # Swap routing
    │   │   ├── exact_in.gno
    │   │   ├── exact_out.gno
    │   │   ├── swap_single.gno
    │   │   ├── swap_multi.gno   # Up to 3 hops
    │   │   ├── swap_inner.gno
    │   │   ├── router.gno
    │   │   └── base.gno
    │   ├── staker/              # Staking + GNS rewards + external incentives
    │   │   ├── staker.gno
    │   │   ├── external_incentive.gno
    │   │   ├── reward_calculation*.gno
    │   │   ├── calculate_pool_position_reward.gno
    │   │   ├── mint_stake.gno
    │   │   ├── type.gno
    │   │   └── wrap_unwrap.gno
    │   ├── gov/                 # Governance — proposals, voting, execution
    │   │   └── *.gno
    │   ├── launchpad/           # Token distribution / vesting
    │   │   └── *.gno
    │   ├── protocol_fee/        # Protocol fee collection and distribution
    │   │   └── *.gno
    │   └── community_pool/      # Treasury / community fund
    │       └── *.gno
    │
    ├── pool/            # Pool proxy layer
    │   ├── proxy.gno    # Stable public interface
    │   ├── state.gno
    │   ├── store.gno
    │   └── upgrade.gno
    ├── position/        # Position proxy layer (same structure)
    ├── router/          # Router proxy layer
    ├── staker/          # Staker proxy layer
    │   └── accessor.gno # Additional staker state accessors
    ├── access/          # access.gno — role mirror, queried by all realms
    ├── rbac/            # ownership.gno, rbac.gno — authoritative role source
    ├── emission/        # GNS minting and distribution schedule
    ├── gns/             # GNS token contract (minting authority)
    ├── halt/            # Granular emergency pause per module
    ├── referral/        # Referral tracking and registration
    └── common/          # tick_math.gno, coins.gno
```

### 3.2 Proxy / Implementation / Storage

```
User → Proxy (permanent) → Implementation v1 → Storage (KV, shared across versions)
```

- Proxy holds write permission. Implementation does **not** — `runtime.CurrentRealm()` does not change on proxy→implementation calls.
- On `ChangeImplementation`: write permission revoked from old implementation. Modules with side-write dependencies (e.g., staker → emission) must **manually re-register** write access in the upgrade procedure.
- Same-version re-upgrade is allowed (for re-initialization). Ensure initializer is idempotent or explicitly handles repeated calls.

### 3.3 RBAC / Access

- `r/rbac/` = authoritative role map, 2-step ownership via `std.PreviousRealm()`.
- `r/access/` = synchronized mirror queried by all other realms.
- Role registration must include the role's address at time of registration.
- Admin controls: fees, halt, emissions, token list, upgrades, swap whitelist — treat admin key as protocol-level secret.

### 3.4 Halt

`r/halt/` pauses pool / staker / router / position / withdrawals independently.

**Cascade risk**: `emission.MintAndDistributeGns` returns `(int64, bool)`. If emission is halted and callers don't check the bool, they also halt. Always wrap emission calls to tolerate halt. Hook-setting functions (`SetTickCrossHook`, `SetSwapStartHook`, `SetSwapEndHook`) must also check halt state.

---

## 4. Module Details and Watchpoints

### 4.1 pool (v1/pool/)

Core AMM. All pools live in a single realm (singleton pattern).

- **Slot0**: holds `sqrtPriceX96`, `tick`, `unlocked`. Reentrancy lock lives here — must be persisted via `SetSlot0(...)`, not on a local copy.
- **Oracle**: must be written with **pre-swap** tick and liquidity, before applying swap result.
- **feeGrowthOutside** on ticks: must be inverted correctly at every `tickCross`.
- **Protocol fee**: capped at 25% of swap fees (per token). If changed, validate upper bound.
- **Transfer**: `transfer.gno` uses `SafeGRC20Transfer`. Never add direct `tokenTeller` calls without panic-on-failure.
- Tick range valid: `[-887272, 887272]`. `MIN_SQRT_RATIO` / `MAX_SQRT_RATIO` are hard bounds.

### 4.2 position (v1/position/)

LP position NFT management. Positions are non-transferable except to/from the staker realm.

- `burned = true` flag must block `IncreaseLiquidity`. The NFT is not destroyed, only flagged.
- Slippage check in `DecreaseLiquidity` must compare against **actually received** amounts (from `Collect`), not amounts owed (from `Burn`).
- All position-altering operations (`Mint`, `IncreaseLiquidity`, `DecreaseLiquidity`, `Reposition`) must enforce a user-specified deadline via `assertIsNotExpired`.
- `native_token.gno`: minimal GNOT handling remains; most wrapping/unwrapping has moved to the frontend.

### 4.3 router (v1/router/)

Single-hop, multi-hop (max 3 hops), exact-in, exact-out, split routes.

- **SwapCallback** must verify: `access.AssertIsPool(caller)` + `assertIsRouterV1()`. Both checks required.
- Exact-out slippage: output tolerance is ±`swapCount` (one per hop) to account for rounding.
- Router fee charged on output tokens. Fee cap: 10%. Validate all fee-setting functions.
- Route format: `TOKEN0:TOKEN1:FEE*POOL*TOKEN1:TOKEN2:FEE*POOL*...` — verify any route-parsing changes against this.
- `DrySwapRoute` and live swap must behave consistently; discrepancy causes UX failures.

### 4.4 staker (v1/staker/)

Stakes LP NFTs, distributes GNS emissions and external incentives.

- Hook system: `SetTickCrossHook`, `SetSwapStartHook`, `SetSwapEndHook` keep staker synchronized with pool events in real-time. These must also check halt state.
- Tier system: Tier 1 (50%) / Tier 2 (30%) / Tier 3 (20%). Empty tier redistributes share. Pool removal from tier must not block unstake or past reward collection.
- External incentive active window: `startTimestamp <= now < endTimestamp`. Both bounds required.
- `refunded` flag prevents double-claim on `EndExternalIncentive`. Set atomically.
- `lastCollectTime` tracked **per incentive** (not a single shared timestamp). Updated only after successful transfer.
- Warmup final tier must be `math.MaxInt64`.
- `MintAndStake` must forward `referrer` to `StakeToken` — empty string loses referral attribution.

### 4.5 gov (v1/gov/)

Governance: proposals, voting, execution. **Not fully audited.**

- Community pool spend validation: amount must be **strictly positive** (`> 0`), not merely non-zero (`!= 0`). Negative amounts are semantically invalid and may cause downstream issues.
- Snapshot mechanism for voting power must be captured at proposal creation block — stale snapshots allow vote manipulation.
- Execution of passed proposals must be time-locked or guarded to prevent front-running.
- Any proposal that touches treasury, fee params, or emission rates is high-risk — validate all downstream effects.

### 4.6 launchpad (v1/launchpad/)

Token distribution and vesting. **Not audited.**

- Vesting schedule arithmetic: overflow on `totalAmount * vestingRate / denominator` for large supplies.
- Claimable amount calculations must match actual contract balance — accounting drift leads to irreversible fund lock.
- Access control: only authorized addresses should be able to create or modify campaigns.
- Any `collect` function must follow CEI pattern.

### 4.7 protocol_fee (v1/protocol_fee/)

Collects and distributes protocol fees from swaps, staking rewards, and withdrawals.

- **Every fee transfer must call `AddToProtocolFee`** to register the amount. Transfers that bypass this leave funds permanently locked (no record → no distribution path).
- `DistributeProtocolFee` only distributes what is registered in `tokenListWithAmount`. Direct transfers to the protocol fee address without registration are unrecoverable.
- Fee collection addresses must be validated — sending to `""` or an invalid address loses funds.
- All distribution functions must handle token transfer failures without corrupting the registered balance.

### 4.8 community_pool (v1/community_pool/)

Protocol treasury. Receives unclaimable internal rewards (zero-liquidity periods) and governance-directed funds.

- Spend proposals must be validated: positive amount, valid recipient address, registered token path.
- Token balance tracking must match actual held balance — any mismatch is an accounting bug.
- No direct sends from community pool without governance approval. Admin-only bypass is a centralization risk.

### 4.9 emission (r/emission/)

GNS minting and distribution schedule. **Not fully audited.**

- `MintAndDistributeGns` returns `(int64, bool)`. The `bool` indicates whether emission is active (not halted). **Every caller must check this bool** — ignoring it causes the calling module to halt when emission is paused.
- Emission rate changes must trigger a cache-invalidation callback in staker. Missing this causes stale reward calculations until the next user interaction.
- Minting authority: only `emission` should call `gns.Mint`. Any other realm gaining mint access is a critical vulnerability.
- Allocation percentages (stakers / devops / community pool / governance stakers) must sum to 100% after any change.

### 4.10 gns (r/gns/)

GNS token contract. **Not audited.**

- Mint function must be callable only by `emission`. Verify access control on every mint path.
- Total supply accounting must be consistent with all minting and burning events.
- GRC-20 standard compliance: no hooks, no rebase, no transfer fees.

### 4.11 referral (r/referral/)

Referral tracking. Minimal impact on fund flows but affects attribution.

- `TryRegister` returns a success bool. **Always check it** and apply the appropriate fallback (e.g., use a default referrer or skip attribution). Silent failure causes inconsistent referral states.
- `MintAndStake` and `Mint` must both forward `referrer` to downstream staking calls.
- Referral state must not block or revert core operations (staking, minting) if registration fails.

### 4.12 common (r/common/)

Shared math utilities used across all realms.

- `tick_math.gno` (`GetTickAtSqrtRatio`, `GetSqrtRatioAtTick`): add nil-pointer checks on inputs. Missing nil checks cause panics on invalid input.
- `coins.gno`: validate coin denomination and amounts at every entry point.
- These are foundational — bugs here propagate to every module that imports them.

### 4.13 p/store (KV Store)

Permission model: `None(0)` → `ReadOnly(1)` → `Write(2)`.

- `UpdateAuthorizedCaller` accepts `ReadOnly` and `Write` only. `None` must use `RemoveAuthorizedCaller` — passing `None` to update would previously escalate `None` to `ReadOnly`.
- Implementation realms must NOT receive `Write` permission (proxy already holds it).
- After every upgrade, audit the full authorized-caller table for each domain store.

### 4.14 p/version_manager

- `ChangeImplementation` revokes write from all previous callers, then grants write to new implementation. This is the single source of permission change — do not bypass it.
- Same-version upgrade triggers re-initialization. Ensure initializer handles this without corrupting existing state.
- Rollback is possible (activate a previous registered version). Test rollback paths.

---

## 5. AMM Core (Uniswap V3 Fork)

### 5.1 Key Primitives

| Primitive | Format | Detail |
|-----------|--------|--------|
| sqrtPriceX96 | Q64.96 | Square root of price × 2^96 |
| feeGrowthGlobal | Q128.128 | Cumulative fee per unit liquidity |
| Tick range | int | Valid: `[-887272, 887272]` |
| Fee tiers | fixed | 0.01% / 0.05% / 0.3% / 1% — no new tiers post-deploy |

### 5.2 Swap Loop

Find next tick → `ComputeSwapStep` → accumulate fees → cross tick (update `liquidityNet`) → repeat until `amountSpecifiedRemaining == 0` or price limit hit.

Oracle write must use **pre-swap** tick and liquidity. Writing after the swap gives wrong TWAP.

### 5.3 Swap Callback

```
Pool sends output → SwapCallback on router → router sends input to pool
```

Both checks required in SwapCallback: `access.AssertIsPool(caller)` + `assertIsRouterV1()`.

### 5.4 Reentrancy Lock

`Slot0.unlocked` is the guard. Local copy mutation has no effect. Always call `SetSlot0(...)` to persist before any external call.

---

## 6. Token Handling

- Always use `SafeGRC20Transfer` / `SafeGRC20TransferFrom`. Panic on failure — do not silently continue.
- `std.OriginSend` carries native GNOT. Pools are GRC-20 only.
- WUGNOT unwrap/wrap lives at the **frontend layer**. Do not re-introduce into contracts.
- Unexpected GNOT in a non-native path: **revert**.
- Transfer cap: `int64` max (`2^63 - 1`). Use `safeConvertToInt64` at all boundaries. Handle panic explicitly.

---

## 7. Math Libraries

- `uint256` / `int256` `Mul` and `lsh` do **not** detect overflow. Add explicit range checks.
- `feePips` must be `< 1_000_000` in `ComputeSwapStep`. Equal = division by zero.
- Rounding must consistently favor the pool. Justify any deviation against the Uniswap V3 Solidity reference.
- Q64.96 and Q128.128 operations must not mix formats without explicit conversion.

---

## 8. Testing — Required Review Areas

Every non-trivial change must be validated against all of the following.

### 8.1 Fuzzing

- AMM math functions (`ComputeSwapStep`, `GetAmount0Delta`, `GetAmount1Delta`, `MulDiv`, `MulDivRoundingUp`) must be fuzz-tested with random `uint256` inputs, including values near `2^256-1`, `0`, and `2^128`.
- Swap loop: fuzz with random `amountSpecified`, `sqrtPriceLimitX96`, and arbitrary tick states.
- Reward calculation: fuzz with random `liquidityDelta`, timestamps, and tier combinations.
- Fee growth accumulation: fuzz over long time ranges and high liquidity values.

### 8.2 Boundary Values

| Function | Boundary cases to test |
|----------|----------------------|
| `GetTickAtSqrtRatio` | `MIN_SQRT_RATIO`, `MAX_SQRT_RATIO`, `MIN_SQRT_RATIO + 1`, `MAX_SQRT_RATIO - 1` |
| `ComputeSwapStep` | `feePips = 0`, `feePips = 999_999`, `amountRemaining = 0`, `amountRemaining = MaxInt64` |
| `MulDiv` | Inputs where product overflows uint256 before division |
| `safeConvertToInt64` | `MaxInt64`, `MaxInt64 + 1`, `0`, negative values |
| Warmup schedule | Exactly at tier boundary timestamps, `math.MaxInt64` |
| Tick | `-887272`, `887272`, `-887272 - 1`, `887272 + 1` |
| Liquidity delta | `MaxUint128`, `0`, `-MaxInt128` |

### 8.3 Edge Cases

- Swap with zero liquidity in range (all liquidity out of range).
- Pool with only one tick initialized.
- Position with `tickLower == tickUpper` (invalid — must be rejected).
- Burn all liquidity from a position, then attempt `IncreaseLiquidity`.
- `EndExternalIncentive` called before `startTimestamp`.
- Governance proposal with `amount == 0` and `amount < 0`.
- `ChangeImplementation` to the same version (re-initialization).
- Staker hooks called when pool is halted.
- `CollectReward` on a pool removed from all tiers.
- Multi-hop route where intermediate token equals input or output token.

### 8.4 Overflow and Underflow

Explicitly test:
- `feeGrowthInside` after many tick crosses (Q128.128 wraparound is intentional — verify).
- `tokensOwed0/1` accumulation over a very long staking period.
- `rewardPerSecond * elapsedTime` for long-duration incentives.
- `liquidityGross` at tick when adding and removing positions simultaneously.
- `amountSpecifiedRemaining` decrements in the swap loop — must not underflow past `MinInt64`.
- `abs(-2147483648)` — this input is invalid but must not panic without a pre-check.
- `uint256.Mul` with both operands near `2^128` — no overflow detection in the library.

### 8.5 Rounding Errors and Precision

- `ComputeSwapStep` rounding: `amountIn` rounds up, `amountOut` rounds down (pool-favoring). Verify both directions.
- `MulDivRoundingUp` vs `MulDiv` — use the correct one at each callsite. Swapping them changes who absorbs rounding dust.
- `rewardPerSecond = totalReward / duration` — integer truncation leaves dust. Verify dust handling does not accumulate into a locked balance.
- TWAP tick calculation: negative `tickDelta` must floor toward negative infinity, not truncate toward zero. Test with `tickDelta = -1` and `secondsAgo = 2` (expected result: `-1`, wrong result: `0`).
- Fee growth `feeGrowthInside` for positions spanning the current tick: verify the inside/outside calculation is correct when tick has been crossed an odd vs even number of times.
- `sqrtPriceX96` precision: verify that going from price → sqrtPrice → tick → sqrtPrice round-trips to within 1 tick.

### 8.6 Invariants to Assert in Tests

After every operation, assert:
- `pool.liquidity >= 0` for all pools.
- `tokensOwed0 + tokensOwed1 >= 0` for all positions.
- `pool.balance0 >= sum(tokensOwed0)` across all positions (pool is solvent).
- `feeGrowthGlobal >= feeGrowthOutside` for every initialized tick (outside cannot exceed global).
- Sum of all external incentive `rewardPerSecond * duration` ≤ deposited `rewardAmount`.
- Warmup percentages sum to ≤ 100 at any point in time.
- After `UnStakeToken`, the NFT is returned and no staking state references it.

---

## 9. Security Review Checklist

### Access Control
- [ ] `std.PreviousRealm()` used (not `OriginCaller`) for immediate-caller checks
- [ ] Every new public function has a role/permission assertion
- [ ] `SwapCallback` verifies both: `AssertIsPool(caller)` and `assertIsRouterV1()`
- [ ] No arbitrary/variable functions accepted as arguments for cross-calling

### Reentrancy and CEI
- [ ] Reentrancy lock persisted via `SetSlot0(...)` before external calls
- [ ] All state updates precede token transfers (Checks-Effects-Interactions)
- [ ] `CollectReward` / `DecreaseLiquidity` / `EndExternalIncentive` follow CEI

### Arithmetic and Precision
- [ ] `Mul` / `lsh` on uint256/int256 have explicit pre-call range checks
- [ ] `safeConvertToInt64` used at every uint256→int64 boundary
- [ ] `feePips < 1_000_000` validated at fee-setting entry points
- [ ] All fee percentages capped at 10% (enforced, not just documented)
- [ ] Rounding direction verified against Uniswap V3 reference at each callsite

### Token Flows
- [ ] All transfers use `SafeGRC20Transfer` / `SafeGRC20TransferFrom`
- [ ] Unexpected GNOT in non-native paths causes revert
- [ ] No unwrap/wrap logic in contracts (frontend only)
- [ ] `AddToProtocolFee` called for every fee transfer to `protocol_fee` realm

### State Integrity
- [ ] Slippage checks use actually-received amounts (not owed)
- [ ] `burned = true` positions rejected in `IncreaseLiquidity`
- [ ] All position-altering ops enforce a user-specified deadline
- [ ] `refunded` flag checked atomically in `EndExternalIncentive`
- [ ] `lastCollectTime` tracked per-incentive, updated after successful transfer

### Upgrade and Halt
- [ ] Post-upgrade permission re-registration covers all dependent modules
- [ ] Every new state-changing external function includes a halt check
- [ ] Emission calls check the `bool` return and tolerate halted state
- [ ] Hook-setting functions (`SetTickCrossHook`, etc.) check halt state

### Governance and Treasury
- [ ] Community pool spend amount validated as strictly positive (`> 0`)
- [ ] Governance proposal execution is guarded against front-running
- [ ] `DistributeProtocolFee` only distributes registered amounts
- [ ] Direct transfers to `protocol_fee` realm always call `AddToProtocolFee`

### Rewards and Staking
- [ ] `TryRegister` return value checked; fallback applied on failure
- [ ] `MintAndStake` forwards `referrer` to `StakeToken`
- [ ] Final warmup tier is `math.MaxInt64`
- [ ] Pool tier removal does not block unstake or past reward claims
- [ ] Emission rate changes trigger cache invalidation in staker

### Interrealm Safety
- [ ] No variable functions cross-called without explicit trust/whitelist
- [ ] Objects from `GetX()` on external realm not passed back to that realm as mutator args
- [ ] `init()` captures deployer if needed — only opportunity to access it

### Testing Coverage
- [ ] Fuzz tests cover all AMM math functions with boundary inputs
- [ ] Boundary value tests for every function in `tick_math.gno` and `gnsmath/`
- [ ] Overflow/underflow tests for all accumulation fields over long durations
- [ ] Rounding direction tests for `MulDiv`, `MulDivRoundingUp`, TWAP tick, `ComputeSwapStep`
- [ ] Invariant assertions after every state-changing operation in integration tests

---

## 10. Common Pitfalls

| Pitfall | What goes wrong |
|---------|----------------|
| `OriginCaller` for access control | Intermediate contract impersonates any user |
| Reentrancy lock on local `Slot0` copy | Lock never persists; reentrancy possible |
| `SwapCallback` missing `AssertIsPool` | Anyone forges callback params, drains approvals |
| Transfer before state update | Stale state on re-entry; CEI violated |
| `Mul`/`lsh` without range check | Silent overflow corrupts AMM math |
| Finite final warmup tier | Panic when block time passes it |
| Upgrade without permission re-registration | Dependent modules silently lose write access |
| Halted emission not tolerated | Emission halt freezes unrelated modules |
| Slippage on owed amounts (not received) | User receives less than their minimum |
| Pool tier removal blocks unstake | NFTs permanently locked |
| Fee transfer without `AddToProtocolFee` | Fees permanently locked in protocol_fee realm |
| `TryRegister` return ignored | Inconsistent referral state across modules |
| Governance spend `amount >= 0` not `> 0` | Negative amount proposals pass validation |
| Emission rate change without staker cache invalidation | Stale rewards until next user interaction |
| `rewardPerSecond` dust not handled | Small balance permanently locked in staker |
| Arbitrary function cross-called via arg | Caller loses agency; callee abuses `PreviousRealm` |
| TWAP rounding truncates toward zero | Negative tick delta off by 1 from Uniswap reference |

---

## 11. Uniswap V3/V4 Divergences and AMM Exploit Warnings

GnoSwap is forked from Uniswap V3 but deviates in ways that invalidate several V3/V4 security assumptions. Do not apply Uniswap audit knowledge directly without checking these.

### 11.1 Architectural Divergences

| Area | Uniswap V3/V4 | GnoSwap | Risk |
|------|--------------|---------|------|
| Pool deployment | Factory (isolated contracts per pool) | Singleton realm — all pools share one realm | A bug in pool logic or storage affects every pool simultaneously |
| Token transfer amounts | `uint256` throughout | `int64` at transfer boundary | Normal amounts for high-supply or high-decimal tokens hit the cap and panic |
| Flash loans | Flash swaps (callback receives tokens first) | No flash loans — callback fires after output is sent, before input is received | Flash-loan-dependent arbitrage strategies don't work; flash-loan attack surface removed but composability reduced |
| Position NFTs | Transferable (secondary market, lending) | Non-transferable except to/from staker realm | Cannot compose with lending protocols; liquidation-based strategies impossible |
| Swap access | Permissionless — any address can call pool directly | Permissioned — pool callable only by whitelisted realms | Aggregators and MEV bots must be explicitly whitelisted by governance |
| Protocol fee | Per-pool, off by default | Global across all pools | Governance can change fee for all pools simultaneously — single admin action affects all LPs |
| Router fee | None | Charged on output tokens (default 0.1%, cap 10%) | Exact-out invariant is weaker — user receives `requestedAmount - routerFee`, not `requestedAmount` |
| Fee tiers | Governance can add new tiers | Fixed at 4 tiers post-deploy | Cannot respond to market changes requiring new tick spacings |
| Position key | Derived from owner address | Derived from `positionPackagePath` + tick range — **no owner component** | Two positions with the same tick range in the same package share a key; not per-user |
| IncreaseLiquidity | Anyone can add liquidity to any position | Restricted to position owner | No third-party top-ups; incentive mechanisms built around this are impossible |
| Cross-pool callbacks | Supported in V4 hooks | Not supported | Cannot implement V4-style hooks or custom accounting |

### 11.2 AMM Exploit Patterns — GnoSwap-Specific Exposure

> Items below are grounded in findings from the OpenZeppelin audit reports (Audit + Extended Audit, 2025).  
> Patterns without a GnoSwap-specific audit finding are **not listed** — do not add speculative warnings without code evidence.

---

**⚠ Sandwich Attack / MEV — Partial Mitigation Only**  
*Basis: Audit N-04 (router missing user-specified price limit)*  
`amountOutMin` / `amountInMax` slippage protection exists. However, the router's public interface hardcodes `sqrtPriceLimitX96 = 0`, removing the ability to set per-swap price limits. Users cannot do controlled partial fills. The new callback mechanism allows `sqrtPriceLimitX96` to be specified by callers who build their own contracts — but the canonical router still exposes only slippage tolerance as MEV protection. Any change that widens the gap between `DrySwap` output and live execution is a regression. *Audit N-04 marked resolved via callback redesign; verify that the callback path is accessible to standard users.*

---

**⚠ Pool Initialization Griefing**  
*Basis: Audit N-03 (recoverable griefing attack — resolved via documentation only, no code-level guard)*  
`CreatePool` accepts an arbitrary initial `sqrtPriceX96` with no price-oracle sanity check. An attacker can front-run pool creation at all four fee tiers with an extreme price for the cost of the 100 GNS creation fee. Recovery is permissionless but manual: mint wide-range liquidity → corrective swap → remove liquidity (arbitrage gain offsets LP loss). **No code prevents the attack**; only documentation describes the recovery. Any change to `CreatePool` must preserve this recovery path and must not add a lock that prevents the recovery swap.

---

**⚠ Cross-Function Reentrancy via Staker Hooks**  
*Basis: Extended Audit C-02 (swap reentrancy lock was ineffective — resolved via `SetSlot0`)*  
The reentrancy lock (`Slot0.unlocked`) now persists correctly. However, the staker hooks (`SetSwapStartHook`, `SetSwapEndHook`, `SetTickCrossHook`) execute **inside** the swap loop. If hook code reads pool state (sqrtPrice, liquidity, tick), it observes a partially-updated value. The lock prevents re-entering `Swap`, but does not prevent hook code from reading inconsistent transient state. The `halt.AssertIsNotHaltedPool()` guard was missing from hook-setter functions (Extended L-03, resolved). Verify that any new hook logic is designed to tolerate mid-swap pool state.

---

**⚠ TWAP Oracle Manipulation**  
*Basis: Audit H-01 (oracle used post-swap tick — partially resolved); Extended L-08 (TWAP rounding direction — resolved)*  
Oracle now writes pre-swap tick values. TWAP rounding for negative `tickDelta` now floors toward −∞ (matching Uniswap V3 reference). **The TWAP oracle implementation is explicitly out of scope in both audits** — the circular buffer, `secondsPerLiquidityCumulativeX128`, and observation window were not fully reviewed. Treat all logic that depends on GnoSwap's TWAP as unaudited high-risk territory until a dedicated oracle audit is completed.

---

**⚠ Precision Loss via String-Based Number Passing**  
*Basis: Audit conclusion section — "string-based arithmetic operations" flagged as persistent code quality concern; Audit N-05 (int64 transfer limit)*  
Several interfaces pass `sqrtPriceX96`, amounts, and tick values as `string`. Every `strconv.ParseInt` / `ParseUint` call site is a potential panic (malformed input), silent truncation (value exceeds int64), or wrong-sign error. This is not fully resolved — the audit team noted it as an ongoing concern. Audit every new function that accepts numeric strings. For values that may exceed `int64` (high-supply tokens, accumulated fees), verify that `safeConvertToInt64` is called and its error path panics rather than silently proceeding with a wrong value.

---

**⚠ Protocol Fee Balance Discrepancy**  
*Basis: Audit M-06 (`CollectFee` withdrawal fees were not tracked — resolved)*  
GnoSwap's `protocol_fee` realm is **not** the pool itself — it holds funds separately, and `DistributeProtocolFee` only distributes amounts registered in `tokenListWithAmount`. After M-06 fix, `CollectFee` now calls `AddToProtocolFee`. However, any future code path that transfers tokens to the protocol_fee realm without calling `AddToProtocolFee` will create a permanent balance discrepancy — the realm holds more than it can distribute, and the excess is unrecoverable. Grep for every `SafeGRC20Transfer` targeting the protocol_fee realm address and verify `AddToProtocolFee` is called atomically.

---

**⚠ Router Fee Breaks Exact-Out Semantics for Integrators**  
*Basis: Audit C-07 (router fee caused DoS and exact-out violation — resolved); this is documented intentional design divergence*  
GnoSwap charges a router fee on output tokens. In exact-out swaps, the user receives `requestedAmount - routerFee`, **not** `requestedAmount`. This is intentional and differs from Uniswap V3's exact-out guarantee. The `DrySwapRoute` simulation now correctly applies the same `±swapCount` tolerance as live execution (Extended L-05). Any external adapter or aggregator built on GnoSwap must account for this fee deduction — do not document the router as Uniswap-V3-compatible for exact-out without this caveat.

---

## 12. Navigation

| Need | Location |
|------|----------|
| AMM math | `contract/p/gnoswap/gnsmath/` |
| 256-bit arithmetic | `contract/p/gnoswap/uint256/`, `int256/` |
| Pool swap loop | `contract/r/gnoswap/v1/pool/swap.gno` |
| Pool state / Slot0 | `contract/r/gnoswap/v1/pool/pool.gno` |
| Position lifecycle | `contract/r/gnoswap/v1/position/` |
| Router paths | `contract/r/gnoswap/v1/router/` |
| Reward calculation | `contract/r/gnoswap/v1/staker/reward_calculation*.gno` |
| External incentives | `contract/r/gnoswap/v1/staker/external_incentive.gno` |
| Governance | `contract/r/gnoswap/v1/gov/` |
| Launchpad | `contract/r/gnoswap/v1/launchpad/` |
| Protocol fee | `contract/r/gnoswap/v1/protocol_fee/` |
| Community pool | `contract/r/gnoswap/v1/community_pool/` |
| Emission | `contract/r/gnoswap/emission/` |
| GNS token | `contract/r/gnoswap/gns/` |
| Referral | `contract/r/gnoswap/referral/` |
| Tick math utilities | `contract/r/gnoswap/common/tick_math.gno` |
| Access control | `contract/r/gnoswap/rbac/`, `contract/r/gnoswap/access/` |
| KV store / permissions | `contract/p/gnoswap/store/kv_store.gno` |
| Upgrade mechanism | `contract/p/gnoswap/version_manager/`, `*/upgrade.gno` |
| Emergency pause | `contract/r/gnoswap/halt/` |
| Interrealm spec | `docs/resources/gno-interrealm.md` (gno core repo) |

---

*Update this file when you find a pattern that confused you or a gap that caused a bug. Future agents benefit directly.*