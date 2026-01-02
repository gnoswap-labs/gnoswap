// Package gns implements the GNS governance and utility token for GnoSwap.
//
// GNS is a GRC20-compliant token with a deflationary emission schedule.
// The emission follows a 12-year schedule with halving every 2 years:
//   - Years 1-2:  225,000,000 GNS per year (100%)
//   - Years 3-4:  112,500,000 GNS per year (50%)
//   - Years 5-6:   56,250,000 GNS per year (25%)
//   - Years 7-8:   28,125,000 GNS per year (12.5%)
//   - Years 9-12:  14,062,500 GNS per year (6.25%)
//
// Token Economics:
//   - Maximum Supply: 1,000,000,000 GNS
//   - Initial Mint:     100,000,000 GNS
//   - Total Emission:   900,000,000 GNS
//
// Key Functions:
//   - InitEmissionState: Initializes emission schedule (emission contract only)
//   - MintGns: Mints tokens per emission schedule (emission contract only)
//   - Burn: Burns tokens from circulation (admin only)
//   - Transfer/TransferFrom/Approve: Standard GRC20 operations
//
// The emission state tracks accumulated and remaining amounts per halving year,
// ensuring precise token distribution according to the schedule.
package gns
