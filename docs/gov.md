# Governance Module (`v1/gov/`)

Governance: proposals, voting, execution.

## Rules

- Community pool spend validation: amount must be **strictly positive** (`> 0`), not merely non-zero (`!= 0`). Negative amounts are semantically invalid.
- Voting power snapshot must be captured at proposal creation block — stale snapshots allow vote manipulation.
- Execution of passed proposals must be time-locked or guarded to prevent front-running.
- Any proposal that touches treasury, fee params, or emission rates is high-risk — validate all downstream effects.

## Community Pool (`v1/community_pool/`)

Protocol treasury. Receives unclaimable internal rewards (zero-liquidity periods) and governance-directed funds.

- Spend proposals: validate positive amount, valid recipient address, registered token path.
- Token balance tracking must match actual held balance — mismatch is an accounting bug.
- No direct sends without governance approval. Admin-only bypass is a centralization risk.

## Gov Staker (`gov/staker/`)

xGNS delegation plus two reward streams: GNS emission (single token) and protocol fees (any number of tokens).

- **A stake change must never fold protocol fees.** `Delegate` / `Undelegate` / `Redelegate` / `SetAmountByProjectWallet` only call `protocol_fee.AdvanceAccrualEpoch`, record the total stake in force from the new epoch (`totalStakedHistory`) and append one `ProtocolFeeStakeEvent` to the staker. Their cost is independent of how many tokens ever collected a fee.
- Protocol fees are bucketed on the protocol_fee realm per `(tokenPath, accrual epoch)`. gov/staker folds a token's buckets into its `ProtocolFeeTokenAccumulator` only when that token is collected, each bucket divided by `GetTotalStakedAmountAt(epoch)`. A bucket that arrives while nothing is staked is dropped (same policy as emission).
- A staker's reward for a token is settled from their own stake events: `Σ stake × (A(nextEvent.epoch - 1) − A(segment start))`, closed by the open segment up to the current accumulator. Only events whose previous epoch is `<= foldedEpoch` may be settled; the sub-unit remainder stays in `earnedX128`.
- `CollectProtocolFeeReward(tokenPath)` is the bounded path (`maxAccrualBucketsPerCollect`, `maxStakeEventsPerCollect`); leftovers are paid by the next call. `CollectReward` folds and settles every known token and grows with the token count by design.
- The all-token `claimRewards` path must fold every known token (an empty exhaustive fold when nothing is pending) so `foldedEpoch` reaches the epoch in force; otherwise a stake event recorded after the last fee can never be settled.

## Pitfalls

- Folding protocol fees inside a stake change → withdrawal cost grows with the number of fee tokens (GSW-MCP-H01).
- Settling a stake event whose previous epoch is not fully folded → the segment ends at a stale accumulator and mis-attributes fees across the stake change.
- Governance spend `amount >= 0` instead of `> 0` → negative amount proposals pass.
- Stale voting power snapshot → vote manipulation.
- Proposal execution without time-lock → front-running.
