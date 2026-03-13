# Governance Module (`v1/gov/`)

Governance: proposals, voting, execution. **Not fully audited.**

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

## Pitfalls

- Governance spend `amount >= 0` instead of `> 0` → negative amount proposals pass.
- Stale voting power snapshot → vote manipulation.
- Proposal execution without time-lock → front-running.
