# Emission

GNS token emission and distribution system.

## Concept

The GnoSwap emission system controls the creation and distribution of new GNS tokens according to a predetermined schedule. It implements a deflationary model with periodic halvings, similar to Bitcoin, ensuring a predictable and decreasing supply growth over time.

### Emission Schedule
- **Total Supply Cap**: 1,000,000,000 GNS
- **Initial Minted Supply**: 100,000,000 GNS
- **To Be Minted Supply**: 900,000,000 GNS
- **Halving Period**: Every 2 years (63,072,000 seconds)
- **Halving Reduction**: 50% decrease in emission rate
- **Distribution Trigger**: Automatic during user interactions

### Distribution Mechanism
When triggered by protocol activity (swaps, liquidity operations, etc), the system:
1. Calculates elapsed time since last distribution
2. Mints appropriate GNS based on current emission rate
3. Distributes to predefined targets according to percentages
4. Carries forward any undistributed amounts

## Features

- Timestamp-based emission schedule
- Automatic distribution to targets
- Halving every 2 years
- Leftover token tracking
- Configurable distribution ratios
- One-time start timestamp setting

## Functions

- `MintAndDistributeGns` - Mint and distribute GNS tokens
- `SetDistributionStartTime` - Set emission start timestamp
- `GetDistributionRatio` - Get current distribution ratios
- `SetDistributionRatio` - Update distribution percentages

## Usage

```go
// Set emission start (one-time setup by admin/governance)
SetDistributionStartTime(1704067200) // Jan 1, 2024 00:00:00 UTC

// Trigger emission distribution (called automatically)
amount := MintAndDistributeGns()

// Update distribution percentages
ChangeDistributionPct(
    1, 7000,  // 70% to liquidity stakers
    2, 2000,  // 20% to devops
    3, 1000,  // 10% to community pool
    4, 0      // 0% to governance stakers
)

// Query distribution info
stakerPct := GetDistributionBpsPct(LIQUIDITY_STAKER)
accumulated := GetAccuDistributedToStaker()
emissionRate := GetStakerEmissionAmountPerSecond()
```

## Notes

- Called automatically by user interactions (no manual trigger needed)
- Emission rate halves every 2 years automatically
- Undistributed tokens carried to next distribution
- Distribution start is immutable once set and time passes
- All percentages must sum to exactly 10000 (100%)

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Distribution Ratios**:
  - Liquidity Staker: 75% (default)
  - DevOps: 20% (default)
  - Community Pool: 5% (default)
  - Governance Staker: 0% (default)
- **Distribution Start Time**: Unix timestamp for emission start