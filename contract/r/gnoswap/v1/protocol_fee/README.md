# Protocol Fee

Fee collection and distribution for protocol operations.

## Fee Types

### Router Fee
- Default: 0.15% of swap amount

### Pool Creation Fee
- Default: 100 GNS

### Withdrawal Fee
- Default: 1% of claimed LP fees
- Processed during liquidity withdrawal

### Unstaking Fee
- Default: 1% of staking rewards
- Applied when claiming rewards

## Flow

1. **Swaps**: 0.15% fee on swap amount
2. **Pool Creation**: 100 GNS fee
3. **Liquidity Withdrawal**: 1% of claimed fees
4. **Staking Claims**: 1% of rewards

## Features

- Multiple fee types (swap, creation, withdrawal)
- Automatic distribution to xGNS holders
- Configurable fee percentages
- DevOps funding support

## Functions

- `DistributeProtocolFee` - Distribute accumulated fees
- `SetDevOpsPct` - Set DevOps percentage
- `SetGovStakerPct` - Set GovStaker percentage
- `AddToProtocolFee` - Add fees to distribution queue
- `ClearTokenListWithAmount` - Clear fee accumulator

## Usage

```go
// Distribute fees
tokenAmounts := DistributeProtocolFee()

// Set distribution percentages
SetDevOpsPct(2000) // 20% to DevOps
```

## Notes

- Fees accumulate until distributed
- Default: 100% to xGNS holders
- Multiple token types supported

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **DevOps Percentage**: 0% (default) - portion for development and operations
- **GovStaker Percentage**: 100% (default) - portion for xGNS holders
- **Distribution Frequency**: On-demand via DistributeProtocolFee