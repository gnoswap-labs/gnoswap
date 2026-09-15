// Package protocol_fee manages fee collection and distribution for GnoSwap protocol operations.
//
// This contract collects authorized fees from protocol operations such as swaps,
// pool creation, withdrawals, and staking claims, then accounts for their
// distribution to DevOps and GovStaker according to configurable percentages.
//
// Distribution Targets:
//   - DevOps: Development and operations fund (default 0%)
//   - GovStaker: Governance-staker destination (default 100%)
//
// Accounting:
//   - reservedTokens tracks token paths with collected fees awaiting distribution.
//   - Per-token allocation accumulators and distribution-history trees distinguish
//     amounts allocated from amounts actually transferred.
//   - GovStaker allocations are bucketed by token path and accrual epoch.
//
// Key Functions:
//   - DistributeProtocolFee: Distributes accumulated fees to recipients
//   - SetDevOpsPct/SetGovStakerPct: Configure distribution percentages
//   - AddToProtocolFee: Pulls an approved fee into the distribution queue
//
// The contract uses a version manager pattern for upgradeable implementations.
package protocol_fee
