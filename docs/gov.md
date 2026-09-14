# Governance Module (`v1/gov/`)

Governance: proposals, voting, execution.

## Rules

- Community pool spend validation: amount must be **strictly positive** (`> 0`), not merely non-zero (`!= 0`). Negative amounts are semantically invalid.
- Voting power snapshot must be captured at proposal creation block — stale snapshots allow vote manipulation.
- Execution of passed proposals must be time-locked or guarded to prevent front-running.
- Any proposal that touches treasury, fee params, or emission rates is high-risk — validate all downstream effects.

## Active Proposal Maintenance

- Proposal and voting history remain permanent. One snapshot-ordered index tracks potentially active proposals; cancel and execute remove their entries immediately.
- `GetOldestActiveProposalSnapshotTime()` returns `(snapshotTime, hasActive, err)` after checking only the first entry. An inactive first entry returns a maintenance error containing `proposalID: N`, not an empty result.
- `RemoveInactiveProposalFromIndex(cur, proposalID)` can be called by anyone while governance is not halted and removes only that inactive proposal's index entry. Missing or still-active proposals and already-removed index entries are rejected.
- Successful maintenance emits `RemoveInactiveProposalFromIndex` with `prevAddr`, `prevRealm`, and `proposalId`. Existing lifecycle event formats are unchanged.
- Commit each removal separately, query again for any remaining stale entry, then retry delegation-snapshot cleanup. Cleanup never maintains the proposal index and rejects getter errors before deleting history.
- Each getter or maintenance call examines at most one proposal, not a constant amount of gas. B+Tree lookup/update costs remain; delegation-history deletion is not batched by this change.
- Initial deployment only: existing stores with unindexed proposal archives are unsupported; no migration/backfill is provided.

## Community Pool (`v1/community_pool/`)

Protocol treasury. Receives unclaimable internal rewards (zero-liquidity periods) and governance-directed funds.

- Spend proposals: validate positive amount, valid recipient address, registered token path.
- Token balance tracking must match actual held balance — mismatch is an accounting bug.
- No direct sends without governance approval. Admin-only bypass is a centralization risk.

## Pitfalls

- Governance spend `amount >= 0` instead of `> 0` → negative amount proposals pass.
- Stale voting power snapshot → vote manipulation.
- Proposal execution without time-lock → front-running.
