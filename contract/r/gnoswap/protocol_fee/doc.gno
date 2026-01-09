// Package protocol_fee manages fee collection and distribution for GnoSwap protocol operations.
//
// This contract collects fees from various protocol operations (swaps, pool creation,
// withdrawals, staking claims) and distributes them to DevOps and Governance Stakers
// according to configurable percentages.
//
// Distribution Targets:
//   - DevOps: Development and operations fund (default 0%)
//   - GovStaker: Governance stakers / xGNS holders (default 100%)
//
// Key Functions:
//   - DistributeProtocolFee: Distributes accumulated fees to recipients
//   - SetDevOpsPct/SetGovStakerPct: Configure distribution percentages
//   - AddToProtocolFee: Adds fees to the distribution queue
//
// The contract uses a version manager pattern for upgradeable implementations.
package protocol_fee
