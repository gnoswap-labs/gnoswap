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

- **Distribution Ratios** (modifiable by admin or governance):
  - Liquidity Staker: 75% (default)
  - DevOps: 20% (default)
  - Community Pool: 5% (default)
  - Governance Staker: 0% (default)
- **Start Time**: Unix timestamp. It may be changed while the configured timestamp is still in the future; once active, it cannot be changed.

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
2. Mints GNS based on the current timestamp range and halving-year rates
3. Distributes to targets per configured ratios
4. Carries forward any undistributed amounts

If emission is halted, `MintAndDistributeGns` returns `(0, false)` without
panicking. A caller that requires emission must explicitly handle that result.

## Key Functions

### `MintAndDistributeGns`

Mints and distributes GNS tokens automatically.

### `SetDistributionStartTime`

Sets or reschedules the emission start timestamp before distribution is active.
The timestamp must be positive and in the future; after the configured start
time has been reached, the timestamp is immutable.

### `ChangeDistributionPct`

Updates distribution percentages (admin or governance only).

### `GetDistributionBpsPct`

Returns current distribution percentage in basis points for a target, or an error if the target is invalid.

## Technical Details

### Timestamp-Based Emission

The following is a conceptual view of the schedule:

```
emissionPerSecond = baseEmission / (2^halvingCount)
amountToMint = emissionPerSecond * elapsedSeconds
```

The implementation uses integer, piecewise rates. For each halving year
intersecting the inclusive mint range `[fromTimestamp, toTimestamp]`, it
initializes `yearAmountPerSecond` as
`floor(yearDistributionAmount / SECONDS_IN_YEAR)` and multiplies that rate by
the inclusive number of seconds. The mint range is clamped to the 12-year
schedule end. When a range reaches a year end, the remaining integer amount
(including division dust) is added so that the year's allocation is exhausted.

### Halving Calculation

Halving years are determined by the schedule's year boundaries; the conceptual
form is:

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
// Set emission start (admin/governance; timestamp must be in the future)
SetDistributionStartTime(cross(cur), futureStartTimestamp)

// Trigger emission (called automatically by protocol flows)
amount, ok := MintAndDistributeGns(cross(cur))

// Update distribution ratios
ChangeDistributionPct(
    cross(cur),
    7000, // 70% to liquidity stakers
    2000, // 20% to devops
    1000, // 10% to community pool
    0,    // 0% to governance stakers
)

// Query distribution info
stakerPct, err := GetDistributionBpsPct(LIQUIDITY_STAKER)
if err != nil {
    panic(err)
}
accumulated := GetAccuDistributedToStaker()
rate, err := GetStakerEmissionAmountPerSecond()
if err != nil {
    panic(err)
}
```

## Security

- Start time may be rescheduled while still in the future and is immutable once active
- Distribution percentages must sum to 10000 (100%)
- A halted `MintAndDistributeGns` call returns `false`; no automatic cross-module cascade occurs
- If staker cache invalidation is required, keep the optional distribution-change callback registered
- Leftover tracking carries undistributed amounts forward
- Halving is enforced at protocol level
