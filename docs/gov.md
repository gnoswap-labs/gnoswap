# Governance Module (`v1/gov/`)

Governance: proposals, voting, execution.

## Rules

- Community pool spend validation: amount must be **strictly positive** (`> 0`), not merely non-zero (`!= 0`). Negative amounts are semantically invalid.
- Voting power snapshot must be captured at proposal creation block — stale snapshots allow vote manipulation.
- Execution of passed proposals must be time-locked or guarded to prevent front-running.
- Any proposal that touches treasury, fee params, or emission rates is high-risk — validate all downstream effects.

## Active Proposal Maintenance

- `GetOldestActiveProposalSnapshotTime()` returns `(snapshotTime, hasActive, err)` after checking only the first snapshot-index entry. An inactive first entry returns a maintenance-required error, not “no active proposals.”
- `PruneInactiveProposals(cur, limit)` allows the admin or gov/staker to process up to `limit` due deadline entries. Limits must be between 1 and 200 inclusive; invalid limits are rejected before maintenance. It returns `(processed, hasMore)`; processed entries include proposals rescheduled from voting end to expiration.
- Admins can choose smaller batches and submit independent prune transactions until `hasMore` is false, then retry delegation-snapshot cleanup. Use separate transactions so cleanup failure cannot roll back maintenance progress.
- Cleanup never prunes governance indexes. It rejects getter errors before deleting history, even if only one stale proposal remains; explicit maintenance is required in that case.
- Cancel and execute remove index entries immediately. Proposal and voting history remain permanent. Tree lookup/update costs remain; only the number of proposals examined per getter and maintenance call is bounded.

## Community Pool (`v1/community_pool/`)

Protocol treasury. Receives unclaimable internal rewards (zero-liquidity periods) and governance-directed funds.

- Spend proposals: validate positive amount, valid recipient address, registered token path.
- Token balance tracking must match actual held balance — mismatch is an accounting bug.
- No direct sends without governance approval. Admin-only bypass is a centralization risk.

## Pitfalls

- Governance spend `amount >= 0` instead of `> 0` → negative amount proposals pass.
- Stale voting power snapshot → vote manipulation.
- Proposal execution without time-lock → front-running.
