# Halt

Emergency pause mechanism for protocol safety.

## Features

- Selective operation halting
- Multiple halt levels
- Admin/governance control
- Beta mainnet safety mode

## Functions

- `SetHaltLevel` - Set system-wide halt level
- `SetOperationStatus` - Control individual operations
- `IsHalted` - Check if operation is halted
- `GetHaltStatus` - Get current halt configuration

## Usage

```go
// Set halt level
SetHaltLevel(HaltLevelSafeMode)

// Halt specific operation
SetOperationStatus(OpTypeSwap, true)

// Check if halted
if IsHalted(OpTypeWithdraw) {
    panic("withdrawals halted")
}
```

## Notes

- Beta mainnet starts with withdrawals disabled
- Governance enables full functionality post-launch
- Emergency mode halts critical operations

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Halt Level**: None, SafeMode, Emergency, Complete
- **Operation Controls**:
  - Swap, Liquidity, Staking operations
  - Reward collection, Pool creation
  - Withdrawals, Governance, Emissions
  - Protocol fees, Incentives, Launchpad