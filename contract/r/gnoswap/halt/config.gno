package halt

// HaltConfig is a map that stores halt options for each operation type
// It provides centralized control over access and withdrawal permissions
type HaltConfig map[OpType]bool

// IsEnabled checks if both access and withdrawal are enabled for the specified operation type
// Returns true only if both access and withdrawal permissions are enabled
func (c HaltConfig) IsHalted(op OpType) bool {
	halted, exists := c[op]
	if !exists {
		return false // Return false if operation type is not configured
	}

	return halted
}

// Clone creates a deep copy of the halt configuration
// This ensures that modifications to the clone don't affect the original
func (c HaltConfig) Clone() HaltConfig {
	clone := make(HaltConfig)

	// Copy each halt option by creating a new instance
	for op, option := range c {
		clone[op] = option
	}

	return clone
}

// get retrieves the halt option for the specified operation type
// Returns nil if the operation type is not configured
func (c HaltConfig) get(op OpType) (bool, error) {
	enabled, exists := c[op]
	if !exists {
		return false, makeErrorWithDetails(errInvalidOpType, op.String())
	}

	return enabled, nil
}

func (c HaltConfig) set(op OpType, enabled bool) error {
	if !op.IsValid() {
		return makeErrorWithDetails(errInvalidOpType, op.String())
	}

	c[op] = enabled

	return nil
}

// Configuration factory functions for predefined halt levels

// newNoneConfig creates a configuration where all operations are fully enabled
// This represents the normal operational state (HaltLevelNone)
func newNoneConfig() HaltConfig {
	return HaltConfig{
		OpTypePool:          false,
		OpTypePosition:      false,
		OpTypeProtocolFee:   false,
		OpTypeRouter:        false,
		OpTypeStaker:        false,
		OpTypeLaunchpad:     false,
		OpTypeGovernance:    false,
		OpTypeGovStaker:     false,
		OpTypeXGns:          false,
		OpTypeCommunityPool: false,
		OpTypeEmission:      false,
		OpTypeWithdraw:      false,
	}
}

// newSafeModeConfig creates a configuration for safe mode operations
// All operations can be accessed but withdrawals are disabled (HaltLevelSafeMode)
func newSafeModeConfig() HaltConfig {
	return HaltConfig{
		OpTypePool:          false,
		OpTypePosition:      false,
		OpTypeProtocolFee:   false,
		OpTypeRouter:        false,
		OpTypeStaker:        false,
		OpTypeLaunchpad:     false,
		OpTypeGovernance:    false,
		OpTypeGovStaker:     false,
		OpTypeXGns:          false,
		OpTypeCommunityPool: false,
		OpTypeEmission:      false,
		OpTypeWithdraw:      true, // halt withdraw
	}
}

// newEmergencyConfig creates a configuration for emergency situations
// Only governance operations are fully enabled, others enable only withdrawals (HaltLevelEmergency)
func newEmergencyConfig() HaltConfig {
	return HaltConfig{
		OpTypePool:          true,
		OpTypePosition:      true,
		OpTypeProtocolFee:   true,
		OpTypeRouter:        true,
		OpTypeStaker:        true,
		OpTypeLaunchpad:     true,
		OpTypeGovernance:    false, // not halt governance
		OpTypeGovStaker:     true,
		OpTypeXGns:          true,
		OpTypeCommunityPool: true,
		OpTypeEmission:      true,
		OpTypeWithdraw:      false, // not halt withdraw
	}
}

// newCompleteConfig creates a configuration where all operations are completely disabled
// This represents a full system halt (HaltLevelComplete)
func newCompleteConfig() HaltConfig {
	return HaltConfig{
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
}
