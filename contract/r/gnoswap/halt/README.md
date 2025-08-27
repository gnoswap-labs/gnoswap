# Halt

Emergency pause mechanism for protocol safety.

## Overview

Halt system provides granular control over protocol operations for emergency response and beta safety mode.

## Configuration

### Halt Levels

- **NONE**: All operations enabled (normal operation)
- **SAFE_MODE**: All operations enabled except withdrawals (beta mainnet default)
- **EMERGENCY**: Only governance and withdrawal operations enabled (crisis response)
- **COMPLETE**: All operations disabled (full system halt)

### Controllable Operations (OpTypes)

- **pool**: Pool creation and liquidity operations
- **position**: Position NFT minting and management
- **protocol_fee**: Fee collection and distribution
- **router**: Swap routing and execution
- **staker**: Liquidity staking and rewards
- **launchpad**: Token distribution projects
- **governance**: Proposal creation and voting
- **gov_staker**: GNS staking for xGNS
- **xgns**: xGNS token operations
- **community_pool**: Treasury management
- **emission**: GNS emission and distribution
- **withdraw**: Withdrawal operations (LP, rewards, etc.)

## Key Functions

### `SetHaltLevel`
Sets system-wide halt level.

### `SetOperationStatus`
Controls individual operation types.

### `IsHalted`
Checks if operation is halted.

## Usage

```go
// Set system to safe mode (beta mainnet)
SetHaltLevel(HaltLevelSafeMode)

// Enable emergency mode
SetHaltLevel(HaltLevelEmergency)

// Halt specific operation
SetOperationStatus(OpTypeRouter, true)

// Resume specific operation
SetOperationStatus(OpTypeRouter, false)

// Check before operation
if IsHalted(OpTypeWithdraw) {
    panic("withdrawals halted")
}
```

## Halt Level Behaviors

### NONE (Normal Operation)
- All contracts fully operational
- No restrictions applied

### SAFE_MODE (Beta Mainnet)
- All operations enabled except withdrawals
- Used during initial mainnet launch
- Allows trading but prevents fund extraction

### EMERGENCY (Crisis Response)
- Only governance and withdrawals enabled
- Allows users to exit positions
- Governance can still execute proposals

### COMPLETE (Full Halt)
- All operations disabled
- Complete system freeze
- Recovery requires admin/governance action

## Security

- Admin/governance control only
- Beta mainnet starts in SAFE_MODE
- Granular operation control
- Event emission for transparency
- Emergency response capability