# Governance Modules (`gov/governance/v1` and `gov/staker/v1`)

Governance manages proposals, timestamp-based voting, execution, xGNS delegation, and reward distribution.

## Rules

- Community-pool spend validation: the proposal amount must be **strictly positive** (`> 0`), the recipient must be valid, and the token path must be registered. The community-pool balance is not checked when the proposal is created; the transfer is attempted when an approved proposal executes and can fail if the pool is underfunded.
- Voting power is not captured at a block height. Proposal creation stores timestamp anchors: the configured smoothing duration before creation and the proposal creation time. Vote lookups use those timestamp histories; `createdHeight` is retained as proposal metadata only.
- Execution of passed executable proposals is delayed by the configured execution delay and must occur before the configured execution window expires.
- Any proposal that touches treasury, fee params, or emission rates is high-risk — validate all downstream effects.

## Active Proposal Maintenance

- Proposal and voting history remain permanent. One timestamp-ordered index tracks potentially active proposals; cancel and execute remove their entries immediately.
- `GetOldestActiveProposalSnapshotTime()` returns `(snapshotTime, hasActive, err)` after checking only the first entry. An inactive first entry returns a maintenance error containing `proposalID: N`, not an empty result.
- `RemoveInactiveProposalFromIndex(cur, proposalID)` can be called by anyone while governance is not halted and removes only that inactive proposal's index entry. Missing or still-active proposals and already-removed index entries are rejected.
- Successful maintenance emits `RemoveInactiveProposalFromIndex` with `prevAddr`, `prevRealm`, and `proposalId`. Existing lifecycle event formats are unchanged.
- Commit each removal separately, query again for any remaining stale entry, then retry delegation-snapshot cleanup. Cleanup never maintains the proposal index and rejects getter errors before deleting history.
- Each getter or maintenance call examines at most one proposal, not a constant amount of gas. B+Tree lookup/update costs remain; delegation-history deletion is not batched by this change.
- Initial deployment only: existing stores with unindexed proposal archives are unsupported; no migration/backfill is provided.

## Community Pool (`community_pool`)

The community pool holds registered protocol assets and is one execution target for governance spend proposals. The community-pool package itself does not implement proposal creation, voting, or an automatic execution queue: `TransferToken` is a direct admin-or-governance entry point while withdrawals are not halted. A governance proposal is one route to authorize that call.

- Governance spend proposals validate a positive amount, valid recipient address, and registered token path at creation.
- The pool balance is checked only when the encoded `TransferToken` action runs. An underfunded proposal can therefore pass voting but fail during execution.
- Token balance tracking must match actual held balance — mismatch is an accounting bug.
- Governance is the recommended normal route for treasury transfers. While governance is not yet mature, the current admin-or-governance authorization is retained so the admin can act in emergencies only.
- Emergency-only admin use is an operational policy, not a contract-enforced condition. An admin can call `TransferToken` directly without an approved governance proposal; the contract does not verify an emergency or automatically remove admin access when governance matures. Withdrawal-halt and token-transfer checks still apply.

## Gov Staker (`gov/staker/`)

xGNS delegation plus two reward streams: GNS emission (single token) and protocol fees (any number of tokens).

- **A stake change must not fold protocol fees.** `Delegate`, `Undelegate`, and `SetAmountByProjectWallet` advance the accrual epoch, record the total stake in force from the new epoch (`totalStakedHistory`), and append one `ProtocolFeeStakeEvent` to the staker. `Redelegate` performs an undelegate-without-lockup followed by a delegate, so it advances through two epochs and appends two events. Stake-change cost is independent of how many tokens ever collected a fee.
- Protocol fees are bucketed on the protocol_fee realm per `(tokenPath, accrual epoch)`. gov/staker folds a token's buckets into its `ProtocolFeeTokenAccumulator` only when that token is collected, each bucket divided by `GetTotalStakedAmountAt(epoch)`. A bucket that arrives while nothing is staked is dropped (same policy as emission).
- A staker's reward for a token is settled from their own stake events: `Σ stake × (A(nextEvent.epoch - 1) − A(segment start))`, closed by the open segment up to the current accumulator. Only events whose previous epoch is `<= foldedEpoch` may be settled; the sub-unit remainder stays in `earnedX128`.
- `CollectProtocolFeeReward(tokenPath)` is the bounded path (`maxAccrualBucketsPerCollect`, `maxStakeEventsPerCollect`); leftovers are paid by the next call. `CollectReward` folds and settles every known token and grows with the token count by design.
- The all-token `CollectReward` path folds every known token (an empty exhaustive fold when nothing is pending) so `foldedEpoch` reaches the epoch in force; otherwise a stake event recorded after the last fee can never be settled.

## Pitfalls

- Folding protocol fees inside a stake change → withdrawal cost grows with the number of fee tokens (GSW-MCP-H01).
- Settling a stake event whose previous epoch is not fully folded → the segment ends at a stale accumulator and mis-attributes fees across the stake change.
- Governance spend `amount >= 0` instead of `> 0` → negative amount proposals pass.
- Treating the quorum denominator as active delegation only → proposal quorum uses total xGNS supply at creation, including launchpad-held issuance.
- Treating the timestamp smoothing anchors as a block snapshot → off-chain vote-weight calculations diverge from the contract.
- Stale voting power history → vote manipulation.
- Proposal execution without the configured time-lock → front-running.
