# Staker Module (`v1/staker/`)

Stakes LP NFTs, distributes GNS emissions and external incentives.

## Key Files

| File | Purpose |
|------|---------|
| `staker.gno` | Core staking logic |
| `external_incentive.gno` | External incentive management |
| `reward_calculation*.gno` | Reward computation |
| `calculate_pool_position_reward.gno` | Per-position reward calculation |
| `type.gno` | Type definitions |
| `wrap_unwrap.gno` | Token wrapping utilities |

## Rules

### Hooks
- `SetTickCrossHook`, `SetSwapStartHook`, `SetSwapEndHook` execute **inside** the swap loop.
- Hook code reads mid-swap pool state (sqrtPrice, liquidity, tick) — partially updated values. Design hooks to tolerate this.
- Hook-setting functions must check halt state (audit L-03).

### Tiers
- Tier 1 (50%) / Tier 2 (30%) / Tier 3 (20%).
- Empty tier redistributes share to remaining tiers.
- Pool removal from tier must NOT block unstake or past reward collection.
- `UnStakeToken` only records an exit checkpoint. It must never calculate or pay a reward, or a long unclaimed window would make a position unwithdrawable.
- The checkpoint pins the exit tick, the two boundary ticks (the unstake prunes them) and the tier context (a later tier change would re-rate the closed window). `PoolResolver` reads through that pin only on the checkpoint path.
- `Collect*` accept a checkpoint and collect per source; the checkpoint is dropped when every source is done. A checkpoint collect is permissionless, since it can only pay the position's owner.
- A checkpoint's window is final: a zero user reward is left to accrue only while the position is staked, so delivery must still pay the penalty and advance the cursor for a checkpoint.
- `EndExternalIncentive` refuses while an unstaked position still owes a reward from **that** incentive: its share has not been drawn down yet, so refunding would pay it to the creator. The count is keyed by incentive id, never by pool - a pool-wide guard would let one blocked incentive take every other incentive in the pool down with it.
- An incentive's reward amount only ever decreases, so a checkpoint owed more than the incentive holds can never be paid. Such a debt is **forfeited** on collect (`ForfeitUncollectedIncentiveReward`), releasing both the position's re-staking and the incentive's refund; keeping it pending would lock both forever with no escape path.
- The checkpoint also pins the **unstaking fee rate**: the window closed under it, and collect is permissionless, so a later fee change must not apply retroactively.
- A checkpoint delivery refuses when its cursor already reached the window's close. Collect computes amounts once and then transfers per source, and checkpoint collects are permissionless, so a re-entering call between transfers must not get a precomputed amount replayed.
- **Invariant the deferred collect depends on**: every path that changes the tier layout must materialize the reward cache of all tiered pools first, at the current time (`changeTier` does this via `cacheReward`). A tier change that skips it would let `resolveInternalRewardSegments` re-rate a checkpoint's closed window with the new layout.

### External Incentives
- Active window: `startTimestamp <= now < endTimestamp`. Both bounds required.
- `refunded` flag prevents double-claim on `EndExternalIncentive`. Set atomically.
- `EndExternalIncentive` needs `now >= endTimestamp` and keeps the record; `CancelExternalIncentive` needs `now < startTimestamp`, removes it from the incentive tree, the per-pool start-time index and the global tree, and refunds the reward tokens plus the GNS deposit to the **creator** (never a caller-supplied address). Callable by admin, governance, or the creator. Removal is only safe before the start: discovery is bounded by the current time, so no deposit can reference a pending incentive.
- `lastCollectTime` tracked **per incentive** (not shared). Updated only after successful transfer.
- `rewardPerSecond = totalReward / duration` — integer truncation leaves dust. Verify dust does not accumulate into locked balance.

### Warmup
- Final warmup tier must be `math.MaxInt64`. Finite value → panic when block time passes it.
- Warmup percentages must sum to ≤ 100 at any point.

### External Reward Delivery Guard (audit finding #4)

`UnStakeToken` collects inline, so a panic anywhere in reward delivery holds the
NFT and the underlying liquidity hostage. `deliverExternalIncentiveReward`
therefore pre-checks the staker realm's live balance of the reward token against
what BOTH delivery legs will move — the user payout and the unstaking-fee
settlement, which also flushes carried-over pending protocol fees of the same
token — and **skips** the delivery (emitting `UndeliverableExternalReward`)
instead of letting `SafeGRC20Transfer` panic.

**Skip semantics.** The guard runs before any bookkeeping. While the position
stays staked, a skip is a deferral: the per-incentive collect cursor does not
advance and the reward becomes collectible again once the balance is restored
(anyone may donate). At unstake, the skipped share is forfeited; never having
been deducted, it stays inside the incentive and returns to its creator through
`EndExternalIncentive`.

**Why a balance check is sufficient (the closed failure set).** GnoSwap
transfers resolve through grc20reg's concrete `*grc20.Token` straight into
`PrivateLedger` — no token-realm code runs in the path, so a reward token cannot
inject pause, blocklist or fee-on-transfer behaviour. The ledger's own failure
set is: sender balance, address validity, self-transfer, negative amount, and a
recipient-balance overflow (`math/overflow.Add64p` panics). Validity,
self-transfer and negative amounts are unreachable at this call site. The
recipient overflow is unreachable for **every** registered token, because grc20
`Mint` refuses any amount past `MaxInt64 - totalSupply` and all ledger
operations conserve `sum(balances) == totalSupply`; hence
`recipientBalance + amount <= totalSupply <= MaxInt64`.
`TestGrc20MintOverflowGuard_PinsSupplyInvariant` pins that theorem — if it ever
fails, re-derive the guard. The one remaining reachable failure is the sender
balance falling short: an issuer burning the staker realm's balance, or
accounting drift. That is exactly what the guard checks.

> **Re-audit trigger:** the derivation above is bound to the deployed
> `r/demo/defi/grc20reg` + `p/demo/tokens/grc20` pair (grc20reg refuses
> re-registration, so a token's ledger can never be swapped). If the registry is
> ever migrated, re-derive the failure set before trusting the guard.

**Trust model of pair-token rewards.** Pool-pair tokens qualify as reward tokens
for their own pool without the governance allowlist — a product policy. An LP
who farms token X rewards on an X pool is trusting X's issuer; the guard bounds
a betrayal of that trust to the X rewards themselves, never the principal and
never other tokens.

**Deny switch.** `SetDeniedRewardToken(tokenPath, denied)` (admin or governance)
is the operational stop for that policy: a denied token cannot start NEW
incentives, through either qualification path. Existing incentives keep
collecting — the guard already bounds them — and default protocol tokens (GNS,
WUGNOT) cannot be denied.

Withdrawal transactions can still fail on the VM's storage-deposit layer when
the signer attaches too small a deposit; that is signer-side and clears on
retry with a larger `-max-deposit`.

## Pitfalls

- Finite final warmup tier → panic at runtime.
- Pool tier removal blocks unstake → NFTs permanently locked.
- Reward calculation reintroduced into the unstake path → a long unclaimed window locks NFTs.
- Refunding an incentive while positions are uncollected → their reward is paid to the creator instead.
- `lastCollectTime` shared across incentives → wrong reward amounts.
- `referrer` not forwarded → lost referral attribution.
- `rewardPerSecond` dust not handled → small balance permanently locked.
- Reward delivery without the balance guard → a third-party token failure aborts `UnStakeToken` and locks the NFT (audit finding #4).
