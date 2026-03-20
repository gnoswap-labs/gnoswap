# Launchpad Module (`v1/launchpad/`)

Token distribution and vesting.

## Rules

- Vesting schedule arithmetic: overflow on `totalAmount * vestingRate / denominator` for large supplies. Add explicit range checks.
- Claimable amount calculations must match actual contract balance — accounting drift leads to irreversible fund lock.
- Access control: only authorized addresses can create or modify campaigns.
- Any `collect` function must follow CEI pattern (state update before transfer).

## Pitfalls

- `totalAmount * vestingRate / denominator` overflow for large token supplies → silent corruption.
- Claimable amount diverges from actual balance → funds permanently locked.
- Unauthorized campaign creation/modification → token theft.
- `collect` without CEI → reentrancy risk.
