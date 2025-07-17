package halt

import "errors"

// Core types
type HaltLevel string
type OpType string

// Backward compatibility types
type LevelID uint8
type Manager struct {
	// Simplified manager for backward compatibility
}

// Manager methods for backward compatibility with old API
func (m *Manager) Level() HaltLevelInterface {
	return &BackwardCompatHaltLevel{level: currentLevel}
}

func (m *Manager) Status(o OpType) string {
	return string(currentLevel)
}

// Interface for backward compatibility
type HaltLevelInterface interface {
	Level() LevelID
	Name() string
	IsOperationAllowed(op OperationInterface) bool
}

type BackwardCompatHaltLevel struct {
	level HaltLevel
}

func (h *BackwardCompatHaltLevel) Level() LevelID {
	return haltLevelToLevelID(h.level)
}

func (h *BackwardCompatHaltLevel) Name() string {
	return string(h.level)
}

func (h *BackwardCompatHaltLevel) IsOperationAllowed(op OperationInterface) bool {
	if op == nil {
		return false
	}
	enabled, _ := GetOperationStatus(op.Type())
	return enabled
}

// Operation interface for backward compatibility
type OperationInterface interface {
	Type() OpType
}

type BackwardCompatOperation struct {
	opType OpType
}

func (o *BackwardCompatOperation) Type() OpType {
	return o.opType
}

// NewOperation creates a backward compatible operation
func NewOperation(opType OpType, name, desc string) OperationInterface {
	return &BackwardCompatOperation{opType: opType}
}

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

// Legacy LevelID constants for backward compatibility
const (
	LvNoHalt          LevelID = 0
	LvEmergencyHalt   LevelID = 1
	LvCompleteHalt    LevelID = 2
	LvContractHalt    LevelID = 3
	LvMainnetSafeMode LevelID = 10
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

// Backward compatibility conversion functions
func levelIDToHaltLevel(id LevelID) HaltLevel {
	switch id {
	case LvNoHalt:
		return HaltLevelNone
	case LvEmergencyHalt:
		return HaltLevelEmergency
	case LvCompleteHalt:
		return HaltLevelComplete
	case LvContractHalt, LvMainnetSafeMode:
		return HaltLevelSafeMode
	default:
		return HaltLevelSafeMode // Default fallback
	}
}

func haltLevelToLevelID(level HaltLevel) LevelID {
	switch level {
	case HaltLevelNone:
		return LvNoHalt
	case HaltLevelEmergency:
		return LvEmergencyHalt
	case HaltLevelComplete:
		return LvCompleteHalt
	case HaltLevelSafeMode:
		return LvMainnetSafeMode // Map to special mainnet mode
	default:
		return LvMainnetSafeMode // Default fallback
	}
}
