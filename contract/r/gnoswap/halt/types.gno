package halt

// Halt levels define different states of system operation restriction.
const (
	HaltLevelNone      HaltLevel = "NONE"      // All operations enabled.
	HaltLevelSafeMode  HaltLevel = "SAFE_MODE" // All operations enabled except withdrawals.
	HaltLevelEmergency HaltLevel = "EMERGENCY" // Only governance and withdrawal operations enabled.
	HaltLevelComplete  HaltLevel = "COMPLETE"  // All operations disabled.
)

// Operation types representing individual contracts.
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

var haltLevelDescriptions = map[HaltLevel]string{
	HaltLevelNone:      "All operations enabled",
	HaltLevelSafeMode:  "All operations enabled except withdrawals",
	HaltLevelEmergency: "Only governance and withdrawal operations enabled",
	HaltLevelComplete:  "All operations disabled",
}

// HaltLevel represents current system halt state.
type HaltLevel string

// String returns the string representation of the halt level.
func (h HaltLevel) String() string {
	return string(h)
}

// Description returns a human-readable description of the halt level.
func (h HaltLevel) Description() string {
	desc, ok := haltLevelDescriptions[h]
	if !ok {
		return "Unknown halt level"
	}

	return desc
}

// IsValid returns true if the halt level is valid.
func (h HaltLevel) IsValid() bool {
	switch h {
	case HaltLevelNone, HaltLevelSafeMode, HaltLevelEmergency, HaltLevelComplete:
		return true
	default:
		return false
	}
}

// OpType represents operation types that can be controlled independently.
type OpType string

// String returns the string representation of the operation type.
func (o OpType) String() string {
	return string(o)
}

// IsValid returns true if the operation type is valid.
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
