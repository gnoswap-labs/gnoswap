// Package emission manages GNS token emission and distribution for GnoSwap.
//
// The emission system controls creation and distribution of new GNS tokens
// with a deflationary model featuring periodic halvings over 12 years.
//
// Emission Schedule:
//   - Year 1-2:  100% emission rate (225,000,000 GNS/year)
//   - Year 3-4:   50% emission rate (112,500,000 GNS/year)
//   - Year 5-6:   25% emission rate  (56,250,000 GNS/year)
//   - Year 7-8: 12.5% emission rate  (28,125,000 GNS/year)
//   - Year 9-12: 6.25% emission rate (14,062,500 GNS/year)
//
// Distribution Targets (configurable via governance):
//   - LIQUIDITY_STAKER: Rewards for LP providers (default 75%)
//   - DEVOPS: Development and operations fund (default 20%)
//   - COMMUNITY_POOL: Community-governed treasury (default 5%)
//   - GOV_STAKER: GNS staking rewards (default 0%)
//
// Key Functions:
//   - MintAndDistributeGns: Mints and distributes GNS per emission schedule
//   - SetDistributionStartTime: One-time setup of emission start timestamp
//   - ChangeDistributionPct: Updates distribution percentages
//   - ClearDistributedToStaker/GovStaker: Resets pending distribution amounts
package emission
