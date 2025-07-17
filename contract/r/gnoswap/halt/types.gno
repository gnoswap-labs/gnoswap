package halt

import "errors"

// Core types
type HaltLevel string
type OpType string

// Halt levels
const (
	HaltLevelNone      HaltLevel = "NONE"
	HaltLevelSafeMode  HaltLevel = "SAFE_MODE"
	HaltLevelEmergency HaltLevel = "EMERGENCY"
	HaltLevelComplete  HaltLevel = "COMPLETE"
)

// Operation types representing individual contracts
const (
	OpTypePool          OpType = "pool"
	OpTypePosition      OpType = "position"
	OpTypeProtocolFee   OpType = "protocol_fee"
	OpTypeRouter        OpType = "router"
	OpTypeStaker        OpType = "staker"
	OpTypeLaunchpad     OpType = "launchpad"
	OpTypeGovernance    OpType = "governance"
	OpTypeGovStaker     OpType = "gov_staker"
	OpTypeXGns          OpType = "xgns"
	OpTypeCommunityPool OpType = "community_pool"
	OpTypeEmission      OpType = "emission"
	OpTypeWithdraw      OpType = "withdraw"
)

// Errors
var (
	errHalted       = errors.New("operations halted")
	errUnauthorized = errors.New("unauthorized")
	errInvalidLevel = errors.New("invalid halt level")
)

// String methods for better debugging
func (h HaltLevel) String() string {
	return string(h)
}

func (o OpType) String() string {
	return string(o)
}

// IsValid checks if the halt level is valid
func (h HaltLevel) IsValid() bool {
	switch h {
	case HaltLevelNone, HaltLevelSafeMode, HaltLevelEmergency, HaltLevelComplete:
		return true
	default:
		return false
	}
}

// IsValid checks if the operation type is valid
func (o OpType) IsValid() bool {
	switch o {
	case OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter,
		OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance, OpTypeGovStaker,
		OpTypeXGns, OpTypeCommunityPool, OpTypeEmission, OpTypeWithdraw:
		return true
	default:
		return false
	}
}
