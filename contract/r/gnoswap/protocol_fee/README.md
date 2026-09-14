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

### `AdvanceAccrualEpoch`
Closes the accrual epoch in force and returns the new one. Called by gov/staker on every stake change, so fees are attributed to the stake distribution live when they arrived.

### `ConsumeAccrualBuckets`
Returns and clears up to `limit` of the oldest pending buckets of one token, as parallel epoch and amount slices. Called by gov/staker when that token is collected.

## Usage

```go
// Distribute accumulated fees
DistributeProtocolFee(cross)

// Configure distribution
SetDevOpsPct(cross, 2000)     // 20% to DevOps
SetGovStakerPct(cross, 8000)  // 80% to xGNS holders

// View tokens reserved for the next distribution
GetReservedTokens()

// View what gov/staker has not folded yet
GetAccrualEpoch()
GetAccrualPendingTokens()
GetAccrualBuckets(tokenPath, 0)
```

## Security

- Configuration changes are restricted to admin or governance; distribution is restricted to admin or gov/staker
- Automatic fee accumulation
- Multi-token support
- Transparent distribution tracking
