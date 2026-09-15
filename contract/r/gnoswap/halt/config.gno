package halt

// HaltConfig stores halt state for each operation type.
type HaltConfig map[OpType]bool

// IsHalted returns true if the specified operation is halted, false otherwise.
// Returns false if operation type is not found in configuration.
//
// Parameters:
//   - op: operation type whose halt flag is queried.
//
// Returns:
//   - halted: configured halt flag; false when op is absent from the configuration.
func (c HaltConfig) IsHalted(op OpType) bool {
	halted, exists := c[op]
	if !exists {
		return false
	}

	return halted
}

// Clone creates a deep copy of the halt configuration and returns it.
//
// Returns:
//   - clone: independent map containing the same operation halt flags as the receiver.
func (c HaltConfig) Clone() HaltConfig {
	clone := make(HaltConfig)

	for op, option := range c {
		clone[op] = option
	}

	return clone
}

// get retrieves the halt state for the specified operation type.
//
// Parameters:
//   - op: operation type whose configured halt flag is queried.
//
// Returns:
//   - halted: configured halt flag for op.
//   - error: nil when op exists; otherwise errOpTypeNotFound.
func (c HaltConfig) get(op OpType) (bool, error) {
	enabled, exists := c[op]
	if !exists {
		return false, makeErrorWithDetails(errOpTypeNotFound, op.String())
	}

	return enabled, nil
}

// set stores the halt state for the specified operation type.
//
// Parameters:
//   - op: operation type whose halt flag is updated.
//   - enabled: boolean status to store; true marks op halted and false leaves it enabled.
//
// Returns:
//   - error: nil when op is valid and updated; otherwise an invalid-operation error.
func (c HaltConfig) set(op OpType, enabled bool) error {
	if !op.IsValid() {
		return makeErrorWithDetails(errInvalidOpType, op.String())
	}

	c[op] = enabled

	return nil
}

// newNoneConfig creates a configuration with every supported operation enabled.
//
// Returns:
//   - config: new map with all supported operation halt flags set to false.
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

// newSafeModeConfig creates a configuration that halts withdrawals only.
//
// Returns:
//   - config: new map with OpTypeWithdraw true and every other supported operation false.
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
		OpTypeWithdraw:      true,
	}
}

// newEmergencyConfig creates a configuration that halts most operations.
// Only governance and withdrawals remain enabled for emergency recovery.
//
// Returns:
//   - config: new map with governance and withdrawal halt flags false and all other supported flags true.
func newEmergencyConfig() HaltConfig {
	return HaltConfig{
		OpTypePool:          true,
		OpTypePosition:      true,
		OpTypeProtocolFee:   true,
		OpTypeRouter:        true,
		OpTypeStaker:        true,
		OpTypeLaunchpad:     true,
		OpTypeGovernance:    false,
		OpTypeGovStaker:     true,
		OpTypeXGns:          true,
		OpTypeCommunityPool: true,
		OpTypeEmission:      true,
		OpTypeWithdraw:      false,
	}
}

// newCompleteConfig creates a configuration with every supported operation halted.
//
// Returns:
//   - config: new map with all supported operation halt flags set to true.
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
