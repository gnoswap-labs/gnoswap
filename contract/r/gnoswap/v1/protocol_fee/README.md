# Protocol Fee

Manages fees from platform interactions, distributing to xGNS holders.

## Fee Types

### Swap Fee
- Default: 0.15% of swap amount
- Get/Set functions available

### Pool Creation Fee
- Default: 100 GNS
- Get/Set functions available

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

All fees distributed to xGNS holders.

## Notes

- Be aware of applicable fees
- xGNS holders receive fee share

### Configurable Parameters
The following parameters can be modified:
- **DevOps Percentage**: 0% (default) - portion of protocol fees allocated to development operations
- **GovStaker Percentage**: 100% (default) - portion of protocol fees allocated to xGNS holders
