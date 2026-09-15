# Protocol Fee

Fee collection and distribution for protocol operations.

## Overview

The protocol-fee contract collects authorized fees from protocol operations and
distributes them to GovStaker and DevOps according to configured percentages.

## Gnoweb

The root `Render("")` delegates to the active implementation and shows realm identity, distribution allocations in basis points, recipient addresses, the accrual epoch, and halt flags.

Rendering reads fixed configuration without aggregating balances across tokens. Unsupported paths return `404`.

## Configuration

- **Router Fee (initial/default)**: 0.15% of the swap amount; configured by the router, with an admin-or-governance range of 0–10%
- **Pool Creation Fee (initial/default)**: 100 GNS; configured by the pool and modifiable through governance
- **Withdrawal Fee (initial/default)**: 1% of LP fees claimed; configured by the pool and modifiable through governance
- **Unstaking Fee (initial/default)**: 1% of staking rewards; configured by the staker and modifiable by admin or governance
- **Distribution (default)**: 100% to GovStaker and 0% to DevOps

The operation-specific fees above are configured in their owning modules; they
are not protocol-fee distribution percentages.

## Fee Sources

1. **Swaps**: The router applies its configured swap fee (0.15% initially).
2. **Pool Creation**: The pool charges its configured creation fee (100 GNS initially).
3. **LP Withdrawals**: The pool charges its configured withdrawal fee (1% initially).
4. **Staking Claims**: The staker charges its configured unstaking fee (1% initially).

## Key Functions

### `DistributeProtocolFee`
Distributes accumulated fees to recipients.

### `SetDevOpsPct`
Sets the DevOps funding percentage.

### `SetGovStakerPct`
Sets the GovStaker funding percentage.

### `AddToProtocolFee`
Adds an approved fee amount to the distribution queue.

### `AdvanceAccrualEpoch`
Closes the accrual epoch in force and returns the new one. Called by gov/staker on every stake change, so fees are attributed to the stake distribution live when they arrived.

### `ConsumeAccrualBuckets`
Returns and clears up to `limit` of the oldest pending buckets of one token, as parallel epoch and amount slices. Called by gov/staker when that token is collected.

## Usage

```go
// Distribute accumulated fees
DistributeProtocolFee(cross(cur))

// Configure distribution
SetDevOpsPct(cross(cur), 2000)     // 20% to DevOps
SetGovStakerPct(cross(cur), 8000)  // 80% to GovStaker

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
