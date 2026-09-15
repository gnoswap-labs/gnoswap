# Protocol Fee Module (`r/gnoswap/protocol_fee/v1/`)

Collects authorized protocol fees and accounts for their distribution to the
configured DevOps and GovStaker destinations.

## Rules

- Every fee collection must call `AddToProtocolFee`, which pulls an approved amount from an authorized pool, position, router, or staker caller and records it in the protocol-fee accounting.
- `DistributeProtocolFee` processes only token paths in `reservedTokens`. Per-token cumulative allocation accumulators (`accuToGovStaker` and `accuToDevOps`) track amounts assigned to each destination, while distribution-history trees track actual transfers.
- GovStaker accrual is additionally bucketed as `accrualBuckets[tokenPath][epoch]`; each epoch bucket is consumed against the stake state for that epoch.
- Addresses and token paths are validated before transfers, and transfer failures must abort without leaving a partially applied accounting update.
- The default split is 100% to GovStaker and 0% to DevOps; authorized admin or governance configuration can change the percentages.
- A direct token transfer to the protocol-fee address without `AddToProtocolFee` is not added to `reservedTokens` or accrual buckets and is not included by `Distribute`; these APIs provide no public recovery path for such an unregistered balance.

## Pitfalls

- Calling `DistributeProtocolFee` without first registering a fee through `AddToProtocolFee` leaves that amount outside the distribution queue.
- Treating an accumulator as an actual transfer total ignores pending allocations; consult the distribution-history getters for completed transfers.
- Treating protocol-fee rewards as one current-balance share ignores epoch buckets, total stake in force, and Q128 settlement.
- Bypassing access control, token validation, or failed-transfer handling can corrupt accounting or strand funds.
