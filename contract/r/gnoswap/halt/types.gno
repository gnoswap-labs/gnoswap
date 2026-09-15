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

// HaltLevel represents current system halt state.
type HaltLevel string

// String returns the string representation of the halt level.
//
// Returns:
//   - text: exact string value represented by the halt level
func (h HaltLevel) String() string {
	return string(h)
}

// Description returns a human-readable description of the halt level.
//
// Returns:
//   - description: human-readable policy description; "Unknown halt level" for
//     an unrecognized value
func (h HaltLevel) Description() string {
	haltLevelDescriptions := map[HaltLevel]string{
		HaltLevelNone:      "All operations enabled",
		HaltLevelSafeMode:  "All operations enabled except withdrawals",
		HaltLevelEmergency: "Only governance and withdrawal operations enabled",
		HaltLevelComplete:  "All operations disabled",
	}

	desc, ok := haltLevelDescriptions[h]
	if !ok {
		return "Unknown halt level"
	}

	return desc
}

// IsValid returns true if the halt level is valid.
//
// Returns:
//   - valid: true for one of the defined halt levels; false otherwise
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

var opTypes = map[OpType]bool{
	OpTypePool:          true,
	OpTypePosition:      true,
	OpTypeProtocolFee:   true,
	OpTypeRouter:        true,
	OpTypeStaker:        true,
	OpTypeLaunchpad:     true,
	OpTypeGovernance:    true,
	OpTypeGovStaker:     true,
	OpTypeXGns:          true,
	OpTypeCommunityPool: true,
	OpTypeEmission:      true,
	OpTypeWithdraw:      true,
}

// String returns the string representation of the operation type.
//
// Returns:
//   - text: exact string value represented by the operation type
func (o OpType) String() string {
	return string(o)
}

// IsValid returns true if the operation type is valid.
//
// Returns:
//   - valid: true when the operation type is defined; false otherwise
func (o OpType) IsValid() bool {
	_, ok := opTypes[o]

	return ok
}

// OpTypes returns all operation types currently supported by the halt
// configuration.
//
// Returns:
//   - operationTypes: slice containing each defined operation type in map iteration order
func OpTypes() []OpType {
	allOpTypes := make([]OpType, 0, len(opTypes))

	for op := range opTypes {
		allOpTypes = append(allOpTypes, op)
	}

	return allOpTypes
}
