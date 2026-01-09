# Emission

GNS token emission and distribution system.

## Overview

The emission system controls creation and distribution of new GNS tokens with a deflationary model featuring periodic halvings, ensuring predictable and decreasing supply growth over 12 years. For more details, check out [docs](https://docs.gnoswap.io/gnoswap-token/emission).

## Token Economics

- **Total Supply Cap**: 1,000,000,000 GNS
- **Initial Minted**: 100,000,000 GNS
- **To Be Minted**: 900,000,000 GNS over 12 years
- **Halving Period**: Every 2 years (63,072,000 seconds)
- **Halving Reduction**: 50% decrease in emission rate
- **Distribution**: Automatic during protocol activity

## Configuration

- **Distribution Ratios** (modifiable by governance):
  - Liquidity Staker: 75% (default)
  - DevOps: 20% (default)
  - Community Pool: 5% (default)
  - Governance Staker: 0% (default)
- **Start Time**: Unix timestamp (immutable once set)

## Core Features

### Emission Schedule

Implements Bitcoin-style halving model:

- Year 1-2: 100% emission rate
- Year 3-4: 50% emission rate
- Year 5-6: 25% emission rate
- Year 7-8: 12.5% emission rate
- Year 9-12: 6.25% emission rate

### Distribution Mechanism

When triggered by protocol activity:

1. Calculates elapsed time since last distribution
2. Mints GNS based on current emission rate
3. Distributes to targets per configured ratios
4. Carries forward any undistributed amounts

## Key Functions

### `MintAndDistributeGns`

Mints and distributes GNS tokens automatically.

### `SetDistributionStartTime`

One-time setup of emission start timestamp.

### `ChangeDistributionPct`

Updates distribution percentages (admin or governance only).

### `GetDistributionBpsPct`

Returns current distribution percentage in basis points for a target.

## Technical Details

### Timestamp-Based Emission

```
emissionPerSecond = baseEmission / (2^halvingCount)
amountToMint = emissionPerSecond * timeSinceLastMint
```

### Halving Calculation

```
halvingCount = floor(timeSinceStart / halvingPeriod)
```

### Distribution Targets

1. **Liquidity Staker**: Rewards for LP providers
2. **DevOps**: Development and operations fund
3. **Community Pool**: Community-governed treasury
4. **Governance Staker**: GNS staking rewards (currently 0%)

## Usage

```go
// Set emission start (one-time by admin)
SetDistributionStartTime(1704067200) // Jan 1, 2024

// Trigger emission (called automatically)
amount, ok := MintAndDistributeGns()

// Update distribution ratios
ChangeDistributionPct(
    1, 7000,  // 70% to liquidity stakers
    2, 2000,  // 20% to devops
    3, 1000,  // 10% to community pool
    4, 0      // 0% to governance stakers
)

// Query distribution info
stakerPct := GetDistributionBpsPct(LIQUIDITY_STAKER)
accumulated := GetAccuDistributedToStaker()
rate := GetStakerEmissionAmountPerSecond()
```

## Security

- Start time immutable once set and passed
- Distribution percentages must sum to 10000 (100%)
- Automatic triggers prevent manipulation
- Leftover tracking ensures no token loss
- Halving enforced at protocol level
