# Halt

Emergency pause mechanism for protocol safety.

## Overview

Halt system provides granular control over protocol operations for emergency response and beta safety mode. The initial halt level is `NONE`; an authorized caller must explicitly select another level.

## Configuration

### Halt Levels

- **NONE**: All operations enabled (normal operation)
- **SAFE_MODE**: All operations enabled except withdrawals (must be explicitly configured)
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
// Set system to safe mode explicitly when needed
SetHaltLevel(cross(cur), HaltLevelSafeMode)

// Enable emergency mode
SetHaltLevel(cross(cur), HaltLevelEmergency)

// Halt specific operation
SetOperationStatus(cross(cur), OpTypeRouter, true)

// Resume specific operation
SetOperationStatus(cross(cur), OpTypeRouter, false)

// Check before operation
halted, err := IsHalted(OpTypeWithdraw)
if err != nil {
    panic(err)
}
if halted {
    panic("withdrawals halted")
}
```

## Halt Level Behaviors

### NONE (Normal Operation)
- All contracts fully operational
- No restrictions applied

### SAFE_MODE (Explicitly Configured)
- All operations enabled except withdrawals
- Used when explicitly selected during initial mainnet launch or another controlled window
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
- The system initializes at `NONE`; SAFE_MODE is not enabled by default
- Granular operation control
- Event emission for transparency
- Emergency response capability