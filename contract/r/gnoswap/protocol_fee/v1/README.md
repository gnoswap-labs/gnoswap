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
DistributeProtocolFee(cross)

// Configure distribution
SetDevOpsPct(cross, 2000)     // 20% to DevOps
SetGovStakerPct(cross, 8000)  // 80% to xGNS holders

// View tokens reserved for the next distribution
GetReservedTokens()
```

## Security

- Configuration changes are restricted to admin or governance; distribution is restricted to admin or gov/staker
- Automatic fee accumulation
- Multi-token support
- Transparent distribution tracking
