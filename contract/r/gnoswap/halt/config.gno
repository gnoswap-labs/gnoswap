package halt

// HaltConfig stores halt state for each operation type.
type HaltConfig map[OpType]bool

// IsHalted checks if operation is halted.
func (c HaltConfig) IsHalted(op OpType) bool {
	halted, exists := c[op]
	if !exists {
		return false
	}

	return halted
}

// Clone creates deep copy of halt configuration.
func (c HaltConfig) Clone() HaltConfig {
	clone := make(HaltConfig)

	for op, option := range c {
		clone[op] = option
	}

	return clone
}

// get retrieves halt state for operation type.
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

// newNoneConfig creates configuration with all operations enabled.
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

// newSafeModeConfig creates configuration with withdrawals disabled.
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

// newEmergencyConfig creates configuration for emergency mode.
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

// newCompleteConfig creates configuration with all operations disabled.
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
