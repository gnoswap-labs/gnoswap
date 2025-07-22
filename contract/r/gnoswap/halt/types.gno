package halt

import "errors"

// Halt levels define different states of system operation restriction
const (
	HaltLevelNone      HaltLevel = "NONE"      // All operations enabled
	HaltLevelSafeMode  HaltLevel = "SAFE_MODE" // All operations enabled except withdrawals
	HaltLevelEmergency HaltLevel = "EMERGENCY" // Only governance and withdrawal operations enabled
	HaltLevelComplete  HaltLevel = "COMPLETE"  // All operations disabled
)

// Operation types representing individual contracts and their capabilities
const (
	OpTypePool          OpType = "pool"           // Pool contract operations
	OpTypePosition      OpType = "position"       // Position management operations
	OpTypeProtocolFee   OpType = "protocol_fee"   // Protocol fee operations
	OpTypeRouter        OpType = "router"         // Router contract operations
	OpTypeStaker        OpType = "staker"         // Staker contract operations
	OpTypeLaunchpad     OpType = "launchpad"      // Launchpad contract operations
	OpTypeGovernance    OpType = "governance"     // Governance contract operations
	OpTypeGovStaker     OpType = "gov_staker"     // Governance staker operations
	OpTypeXGns          OpType = "xgns"           // xGNS token operations
	OpTypeCommunityPool OpType = "community_pool" // Community pool operations
	OpTypeEmission      OpType = "emission"       // Token emission operations
	OpTypeWithdraw      OpType = "withdraw"       // Withdraw operations
)

// Default errors used throughout the halt system
var (
	errHalted = errors.New("halted") // Error returned when operations are halted
)

// Core types and descriptions mapping for halt levels
var haltLevelDescriptions = map[HaltLevel]string{
	HaltLevelNone:      "All operations enabled",
	HaltLevelSafeMode:  "All operations enabled except withdrawals",
	HaltLevelEmergency: "Only governance and withdrawal operations enabled",
	HaltLevelComplete:  "All operations disabled",
}

// HaltLevel represents the current system halt state
type HaltLevel string

// String returns the string representation of the halt level
func (h HaltLevel) String() string {
	return string(h)
}

// Description returns a human-readable description of what the halt level allows
func (h HaltLevel) Description() string {
	desc, ok := haltLevelDescriptions[h]
	if !ok {
		return "Unknown halt level"
	}

	return desc
}

// IsValid checks if the halt level is one of the predefined valid levels
func (h HaltLevel) IsValid() bool {
	switch h {
	case HaltLevelNone, HaltLevelSafeMode, HaltLevelEmergency, HaltLevelComplete:
		return true
	default:
		return false
	}
}

// OpType represents different operation types that can be controlled independently
type OpType string

// String returns the string representation of the operation type
func (o OpType) String() string {
	return string(o)
}

// IsValid checks if the operation type is one of the predefined valid operation types
func (o OpType) IsValid() bool {
	switch o {
	case OpTypePool,
		OpTypePosition,
		OpTypeProtocolFee,
		OpTypeRouter,
		OpTypeStaker,
		OpTypeLaunchpad,
		OpTypeGovernance,
		OpTypeGovStaker,
		OpTypeXGns,
		OpTypeCommunityPool,
		OpTypeEmission,
		OpTypeWithdraw:
		return true
	default:
		return false
	}
}
