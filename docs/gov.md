# Governance Module (`v1/gov/`)

Governance: proposals, voting, execution.

## Rules

- Community pool spend validation: amount must be **strictly positive** (`> 0`), not merely non-zero (`!= 0`). Negative amounts are semantically invalid.
- Voting power snapshot must be captured at proposal creation block — stale snapshots allow vote manipulation.
- Execution of passed proposals must be time-locked or guarded to prevent front-running.
- Any proposal that touches treasury, fee params, or emission rates is high-risk — validate all downstream effects.

## Active Proposal Maintenance

- A single snapshot-ordered B+Tree indexes proposals that may still be active. Proposal and voting history remain permanent.
- `GetOldestActiveProposalSnapshotTime()` returns `(snapshotTime, hasActive, err)` after checking only the first index entry. An inactive first entry returns a maintenance-required error containing `proposalID: N`, not “no active proposals.”
- `RemoveInactiveProposalFromIndexByAdmin(cur, proposalID)` removes only the specified inactive proposal's snapshot-index entry. It is admin-only, rejects missing or still-active proposals, and does not delete proposal or voting history.
- Submit the removal in a separate transaction, then query again. If another stale entry is reported, remove that proposal's index entry before retrying delegation-snapshot cleanup. Separate transactions prevent a cleanup failure from rolling back maintenance progress.
- Delegation-snapshot cleanup never removes proposal-index entries. It rejects getter errors before deleting history and still protects the oldest active proposal's snapshot.
- Cancel and execute remove their index entries immediately. Elapsed proposals otherwise require explicit single-item maintenance; there is no deadline index, rescheduling, or batch pruner.
- Each getter or maintenance call examines at most one proposal, not a constant amount of gas. B+Tree lookup/update costs remain, and delegation-history deletion itself is not batched by this change.

## Community Pool (`v1/community_pool/`)

Protocol treasury. Receives unclaimable internal rewards (zero-liquidity periods) and governance-directed funds.

- Spend proposals: validate positive amount, valid recipient address, registered token path.
- Token balance tracking must match actual held balance — mismatch is an accounting bug.
- No direct sends without governance approval. Admin-only bypass is a centralization risk.

## Pitfalls

- Governance spend `amount >= 0` instead of `> 0` → negative amount proposals pass.
- Stale voting power snapshot → vote manipulation.
- Proposal execution without time-lock → front-running.
