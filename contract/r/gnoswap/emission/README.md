# Emission

GNS token emission and distribution system.

## Features

- Timestamp-based emission schedule
- Automatic distribution to targets
- Halving every 2 years
- Leftover token tracking

## Functions

- `MintAndDistributeGns` - Mint and distribute GNS tokens
- `SetDistributionStartTime` - Set emission start timestamp
- `GetDistributionRatio` - Get current distribution ratios
- `SetDistributionRatio` - Update distribution percentages

## Usage

```go
// Trigger emission distribution
amount := MintAndDistributeGns()

// Set distribution start
SetDistributionStartTime(startTimestamp)
```

## Notes

- Called automatically by user interactions
- Emission rate halves every 2 years
- Undistributed tokens carried to next distribution

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Distribution Ratios**:
  - Liquidity Staker: 75% (default)
  - DevOps: 20% (default)
  - Community Pool: 5% (default)
  - Governance Staker: 0% (default)
- **Distribution Start Time**: Unix timestamp for emission start