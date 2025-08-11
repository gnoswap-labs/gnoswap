# Protocol Fee

Fee collection and distribution for protocol operations.

## Overview

Protocol Fee contract collects fees from various protocol operations and distributes them to xGNS holders and DevOps.

## Configuration

- **Router Fee**: 0.15% of swap amount
- **Pool Creation Fee**: 100 GNS
- **Withdrawal Fee**: 1% of LP fees claimed
- **Unstaking Fee**: 1% of staking rewards
- **Distribution**: 100% to xGNS holders (default)

## Fee Sources

1. **Swaps**: 0.15% fee on all trades
2. **Pool Creation**: 100 GNS per new pool
3. **LP Withdrawals**: 1% of collected fees
4. **Staking Claims**: 1% of rewards

## Key Functions

### `DistributeProtocolFee`
Distributes accumulated fees to recipients.

### `SetDevOpsPct`
Sets DevOps funding percentage.

### `SetGovStakerPct`
Sets xGNS holder percentage.

### `AddToProtocolFee`
Adds fees to distribution queue.

## Usage

```go
// Distribute accumulated fees
tokenAmounts := DistributeProtocolFee()

// Configure distribution
SetDevOpsPct(2000)     // 20% to DevOps
SetGovStakerPct(8000)  // 80% to xGNS holders

// View accumulated fees
GetProtocolFee(tokenPath)
```

## Security

- Admin-only configuration changes
- Automatic fee accumulation
- Multi-token support
- Transparent distribution tracking