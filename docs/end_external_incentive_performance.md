# EndExternalIncentive Performance Optimization

## Problem Statement

`EndExternalIncentive` calls `endExternalIncentive()` which iterates over **all deposits** in the target pool to calculate the total uncollected external reward for refund calculation.

```go
// external_incentive.gno:243-257 — O(N) iteration
s.getDeposits().IterateByPoolPath(0, math.MaxUint64, incentiveResolver.TargetPoolPath(),
    func(positionId uint64, deposit *sr.Deposit) bool {
        // ... calculateCollectableExternalReward per deposit
    })
```

When a pool has thousands of deposits (e.g., 20,000), this iteration can exceed the gas limit, making the function uncallable.

### Current Accounting Model

```
ExternalIncentive {
    totalRewardAmount:       100,000  // fixed at creation
    rewardAmount:            60,000   // decremented on each CollectReward
    distributedRewardAmount: 25,000   // incremented on each CollectReward (reward only, no penalty)
    rewardPerSecond:         1        // fixed at creation
}
```

**On each `CollectReward`** (staker.gno:533-534):
```
rewardAmount      -= (reward + penalty)   // both deducted from pool
distributedReward += reward               // only reward tracked
// penalty is NOT tracked separately — this is the accounting gap
```

**Current refund formula** (external_incentive.gno:260-261):
```
refund = totalRewardAmount - sumOfCalculatedRewards(ALL deposits) - distributedRewardAmount
```

This requires iterating every deposit to compute `sumOfCalculatedRewards`.

---

## Proposed Solutions

### Option A: Track `accumulatedPenalty` — Eliminate Iteration for Fully-Settled Incentives

#### Concept

Add an `accumulatedPenalty` field to `ExternalIncentive`. On each `CollectReward`, accumulate the warmup penalty. This makes the full accounting equation hold:

```
totalRewardAmount = rewardAmount + distributedRewardAmount + accumulatedPenalty
```

When all deposits have collected their rewards, `rewardAmount` equals the exact refund amount.

#### Changes Required

**1. `ExternalIncentive` struct** (`staker/pool.gno:305-321`)

Add field:
```go
accumulatedPenalty int64 // accumulated warmup penalty from CollectReward
```

Add getter/setter, update `Clone()` and `NewExternalIncentive()`.

**2. `ExternalIncentiveResolver`** (`staker/v1/type.gno`)

Add method:
```go
func (self *ExternalIncentiveResolver) addAccumulatedPenalty(amount int64) {
    self.SetAccumulatedPenalty(safeAddInt64(self.AccumulatedPenalty(), amount))
}
```

**3. `CollectReward`** (`staker/v1/staker.gno:533-535`)

```go
// existing
incentive.SetRewardAmount(safeSubInt64(incentive.RewardAmount(), totalRewardAmount))
incentiveResolver.addDistributedRewardAmount(rewardAmount)

// NEW: track penalty
incentiveResolver.addAccumulatedPenalty(externalPenalty)
```

**4. `endExternalIncentive`** (`staker/v1/external_incentive.gno:221-264`)

```go
func (s *stakerV1) endExternalIncentive(...) (*sr.ExternalIncentive, int64, error) {
    // permission checks (unchanged)

    // O(1): no iteration needed
    refund := incentiveResolver.RewardAmount()
    return incentiveResolver.ExternalIncentive, refund, nil
}
```

#### Invariant

After every `CollectReward`:
```
totalRewardAmount == rewardAmount + distributedRewardAmount + accumulatedPenalty
```

After `EndExternalIncentive`:
```
refund == rewardAmount (residual from uncollected deposits + unclaimable periods)
```

#### Trade-off

| Aspect | Detail |
|--------|--------|
| Refund accuracy | Creator gets back **more** than current logic. Uncollected deposits' rewards are included in refund. |
| User impact | Deposits that haven't called `CollectReward` before `EndExternalIncentive` lose their uncollected external reward for this incentive. On next `CollectReward`, `InsufficientExternalReward` guard (staker.gno:510-524) skips the incentive gracefully — no tx failure. |
| Performance | O(1). No iteration. |
| Complexity | Minimal — one new field, one extra line in `CollectReward`. |

#### Scenario: 20,000 deposits, 10,000 uncollected

- 10,000 collected: their (reward + penalty) already deducted from `rewardAmount`
- 10,000 uncollected: their share remains in `rewardAmount` → goes to creator as refund
- Those 10,000 lose their uncollected external reward for this incentive
- Their `CollectReward` call will emit `InsufficientExternalReward` and skip

---

### Option B: Two-Phase Refund (End + ClaimRefund)

#### Concept

Split `EndExternalIncentive` into two phases:
1. **End**: Mark incentive as ended, return GNS deposit only. Users can still `CollectReward`.
2. **ClaimRefund**: After a grace period, creator claims remaining `rewardAmount`.

This preserves user rewards while eliminating the iteration.

#### Changes Required

**1. `ExternalIncentive` struct** (`staker/pool.gno:305-321`)

Add fields:
```go
accumulatedPenalty int64 // accumulated warmup penalty
ended              bool  // whether EndExternalIncentive has been called
endedTimestamp     int64 // timestamp when End was called
```

**2. `CollectReward`** (`staker/v1/staker.gno:533-535`)

Same as Option A — add penalty tracking:
```go
incentiveResolver.addAccumulatedPenalty(externalPenalty)
```

**3. `EndExternalIncentive`** (`staker/v1/external_incentive.gno:137-218`)

Modify to:
- Mark `ended = true`, `endedTimestamp = currentTime`
- Return GNS deposit to creator immediately
- Do NOT transfer reward tokens — wait for `ClaimRefund`
- Remove iteration logic entirely

```go
func (s *stakerV1) EndExternalIncentive(targetPoolPath, incentiveId string, refundAddress address) {
    // ... validation (unchanged)

    incentiveResolver.SetEnded(true)
    incentiveResolver.SetEndedTimestamp(currentTime)
    incentivesResolver.update(incentive)

    // return GNS deposit only
    gns.Transfer(cross, refundAddress, incentiveResolver.DepositGnsAmount())

    // remove from time-based index
    s.removeIncentiveIdByCreationTime(targetPoolPath, incentiveId, incentive.CreatedTimestamp())
}
```

**4. New function: `ClaimIncentiveRefund`**

```go
func (s *stakerV1) ClaimIncentiveRefund(targetPoolPath, incentiveId string) {
    // validate incentive exists and is ended
    // validate caller is creator or admin
    // validate grace period has passed (e.g., endedTimestamp + GRACE_PERIOD < currentTime)
    // validate not already refunded

    refund := incentiveResolver.RewardAmount()

    // cap by actual balance
    stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
    balance := common.BalanceOf(incentiveResolver.RewardToken(), stakerAddr)
    if balance < refund {
        refund = balance
    }

    incentiveResolver.SetRefunded(true)
    incentiveResolver.addDistributedRewardAmount(refund)
    incentivesResolver.update(incentive)

    common.SafeGRC20Transfer(cross, incentiveResolver.RewardToken(), caller, refund)
}
```

#### Trade-off

| Aspect | Detail |
|--------|--------|
| Refund accuracy | Exact. Users collect first, then creator gets remainder. |
| User impact | No loss. Grace period allows uncollected deposits to claim. |
| Performance | O(1) for both End and ClaimRefund. |
| Complexity | Medium — new function, new fields, new state transition. |
| UX | Creator must call two transactions. Grace period adds delay. |
| Grace period | Needs a protocol-level constant (e.g., 7 days, 30 days). If too short, users still lose. If too long, creator waits. |

#### Scenario: 20,000 deposits, 10,000 uncollected

- `EndExternalIncentive`: incentive marked ended, GNS returned
- Grace period: 10,000 uncollected deposits have time to call `CollectReward`
- After grace period: creator calls `ClaimIncentiveRefund`, gets back remaining `rewardAmount`
- Any deposits that still haven't collected lose their share (same as Option A, but delayed)

---

### Option C: Deposit Counter — Conditional Iteration

#### Concept

Track the number of **active deposits that haven't completed collection** for each incentive. When the counter reaches 0, `rewardAmount` is exact — no iteration needed. When non-zero, fall back to iteration but only over uncollected deposits.

#### Changes Required

**1. `ExternalIncentive` struct** (`staker/pool.gno:305-321`)

Add fields:
```go
accumulatedPenalty       int64 // accumulated warmup penalty
pendingCollectionCount   int64 // deposits that haven't collected after incentive end
```

**2. `CollectReward`** (`staker/v1/staker.gno:533-547`)

```go
// existing
incentive.SetRewardAmount(safeSubInt64(incentive.RewardAmount(), totalRewardAmount))
incentiveResolver.addDistributedRewardAmount(rewardAmount)

// NEW
incentiveResolver.addAccumulatedPenalty(externalPenalty)

// when deposit completes collection for ended incentive, decrement counter
if depositResolver.ExternalRewardLastCollectTime(incentiveId) > incentiveResolver.EndTimestamp() {
    deposit.RemoveExternalIncentiveId(incentiveId)     // existing logic
    incentiveResolver.decrementPendingCollectionCount() // NEW
}
```

**3. `StakeToken`** (`staker/v1/staker.gno:308-319`)

```go
for _, incentiveId := range currentIncentiveIds {
    incentive := s.getExternalIncentives().get(incentiveId)
    if currentTime > incentive.EndTimestamp() {
        continue
    }
    deposit.AddExternalIncentiveId(incentiveId)
    incentive.IncrementPendingCollectionCount() // NEW
    s.getExternalIncentives().set(incentiveId, incentive)
}
```

**4. Lazy discovery in `calculatePositionReward`** (`staker/v1/calculate_pool_position_reward.gno:111-121`)

When new incentives are discovered and added to a deposit:
```go
for _, incentiveId := range currentIncentiveIds {
    deposit.AddExternalIncentiveId(incentiveId)
    // NEW: increment counter for the incentive
    incentive := incentivesResolver.get(incentiveId)
    if incentive != nil {
        incentive.IncrementPendingCollectionCount()
    }
}
```

**5. `endExternalIncentive`** (`staker/v1/external_incentive.gno:221-264`)

```go
func (s *stakerV1) endExternalIncentive(...) (*sr.ExternalIncentive, int64, error) {
    // permission checks (unchanged)

    if incentiveResolver.PendingCollectionCount() == 0 {
        // all deposits settled — exact refund
        refund := incentiveResolver.RewardAmount()
        return incentiveResolver.ExternalIncentive, refund, nil
    }

    // fallback: still has pending deposits — use current O(N) iteration
    // but this only happens when deposits haven't collected yet
    totalReward := int64(0)
    s.getDeposits().IterateByPoolPath(...)
    refund := safeSubInt64(incentiveResolver.TotalRewardAmount(), totalReward)
    refund = safeSubInt64(refund, incentiveResolver.DistributedRewardAmount())
    return incentiveResolver.ExternalIncentive, refund, nil
}
```

#### Trade-off

| Aspect | Detail |
|--------|--------|
| Refund accuracy | Exact when counter == 0. Falls back to current logic otherwise. |
| User impact | None. Fully backward-compatible. |
| Performance | O(1) when all deposits have collected. O(N) fallback otherwise (same as current). |
| Complexity | High — counter must be maintained at multiple points (StakeToken, CollectReward, lazy discovery). Race conditions possible if counter drifts. |
| Risk | Counter drift: if `AddExternalIncentiveId` is called without incrementing, or vice versa, the counter becomes incorrect. This could cause premature refund (counter=0 but deposits exist) or permanent lock (counter>0 but no deposits). |

#### Counter Accuracy Concern

Deposits are added to incentives in **two** places:
1. `StakeToken` (staker.gno:311-318) — explicit
2. `calculatePositionReward` (calculate_pool_position_reward.gno:111-121) — lazy discovery during `CollectReward`

Both must increment the counter. If either path is missed, the counter drifts.

Similarly, counter is decremented when:
1. `CollectReward` removes the incentiveId from deposit (staker.gno:546-548) — after collecting past end time

If a deposit is removed via `UnstakeToken` without collecting this specific incentive's final reward, the counter won't decrement. However, `UnstakeToken` always calls `CollectReward` first (staker.gno:742), so this should be handled.

---

### Option D: Capped Iteration with Early Termination

#### Concept

Keep the iteration but add a **cap** on the number of deposits processed. If the cap is reached, use `rewardAmount` as the refund (same as Option A). This provides a "best effort" calculation with guaranteed termination.

#### Changes Required

**1. `ExternalIncentive` struct** — add `accumulatedPenalty` (same as Option A)

**2. `endExternalIncentive`** (`staker/v1/external_incentive.gno:221-264`)

```go
const maxIterationCount = 1000

func (s *stakerV1) endExternalIncentive(...) (*sr.ExternalIncentive, int64, error) {
    // permission checks (unchanged)

    totalReward := int64(0)
    iterCount := int64(0)
    cappedOut := false

    s.getDeposits().IterateByPoolPath(0, math.MaxUint64, incentiveResolver.TargetPoolPath(),
        func(positionId uint64, deposit *sr.Deposit) bool {
            iterCount++
            if iterCount > maxIterationCount {
                cappedOut = true
                return true // stop iteration
            }

            // existing calculation logic
            depositResolver := NewDepositResolver(deposit)
            lastCollectTime := depositResolver.ExternalRewardLastCollectTime(incentiveResolver.IncentiveId())
            if lastCollectTime > incentiveResolver.EndTimestamp() {
                return false
            }
            rewardState := resolver.RewardStateOf(deposit)
            calculatedTotalReward := rewardState.calculateCollectableExternalReward(
                lastCollectTime, currentTime, incentiveResolver.ExternalIncentive)
            totalReward = safeAddInt64(totalReward, calculatedTotalReward)
            return false
        })

    var refund int64
    if cappedOut {
        // fallback: use rewardAmount directly (uncollected rewards go to creator)
        refund = incentiveResolver.RewardAmount()
    } else {
        // exact calculation (current logic)
        refund = safeSubInt64(incentiveResolver.TotalRewardAmount(), totalReward)
        refund = safeSubInt64(refund, incentiveResolver.DistributedRewardAmount())
    }

    return incentiveResolver.ExternalIncentive, refund, nil
}
```

#### Trade-off

| Aspect | Detail |
|--------|--------|
| Refund accuracy | Exact when deposits <= cap. Approximate (favors creator) when over cap. |
| User impact | When capped, same as Option A — uncollected deposits lose rewards. |
| Performance | O(min(N, cap)). Guaranteed upper bound. |
| Complexity | Low — one constant, one counter, one branch. |
| Tuning | `maxIterationCount` must be chosen to stay within gas limit. Too low = frequent fallback. Too high = still hits gas limit. |

---

## Comparison Matrix

| | Option A | Option B | Option C | Option D |
|---|---|---|---|---|
| **Approach** | `refund = rewardAmount` | End + Grace + ClaimRefund | Deposit counter | Capped iteration |
| **Performance** | O(1) always | O(1) always | O(1) best, O(N) worst | O(min(N, cap)) |
| **Refund accuracy** | Approximate (favors creator) | Exact | Exact when counter=0 | Exact when N <= cap |
| **User reward loss** | Yes — uncollected deposits | No (grace period) | No (when counter works) | Conditional |
| **New fields** | 1 (`accumulatedPenalty`) | 3 (`accumulatedPenalty`, `ended`, `endedTimestamp`) | 2 (`accumulatedPenalty`, `pendingCollectionCount`) | 1 (`accumulatedPenalty`) |
| **New functions** | None | 1 (`ClaimIncentiveRefund`) | None | None |
| **Code changes** | Minimal | Medium | High | Low |
| **Counter drift risk** | None | None | Yes | None |
| **UX change** | None | Creator calls 2 txs | None | None |
| **Backward compatible** | No (refund amount changes) | No (flow changes) | Yes (fallback to current) | Partially |

---

## Recommendation

**For maximum simplicity and performance**: Option A.
- One new field, one new line in `CollectReward`, iteration deleted.
- Trade-off is that uncollected deposits lose external rewards.
- This is acceptable if `EndExternalIncentive` is only callable after `endTimestamp`, giving users the full incentive period to collect.

**For exact accuracy with no user loss**: Option B.
- Cleanest separation of concerns.
- Requires grace period design decision and new public function.
- Creator UX changes (two transactions).

**For backward compatibility with gradual improvement**: Option C.
- Counter eliminates iteration when all deposits have collected.
- Falls back to current logic when counter > 0.
- Highest implementation risk due to counter maintenance across multiple code paths.

**For quick fix with safety net**: Option D.
- Minimal code change.
- Bounded gas cost.
- Still iterates up to cap — not a fundamental fix.
