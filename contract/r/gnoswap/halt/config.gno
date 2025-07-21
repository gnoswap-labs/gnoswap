package halt

// HaltConfig is a map that stores halt options for each operation type
// It provides centralized control over access and withdrawal permissions
type HaltConfig map[OpType]*HaltOption

// IsEnabled checks if both access and withdrawal are enabled for the specified operation type
// Returns true only if both access and withdrawal permissions are enabled
func (c HaltConfig) IsEnabled(op OpType) bool {
	if c[op] == nil {
		return false // Return false if operation type is not configured
	}

	return c[op].IsEnabled()
}

// EnabledAccess checks if access operations are enabled for the specified operation type
// Returns true if access permission is enabled, regardless of withdrawal permission
func (c HaltConfig) IsEnabledAccess(op OpType) bool {
	if c[op] == nil {
		return false // Return false if operation type is not configured
	}

	return c[op].IsEnabledAccess()
}

// IsEnabledWithdraw checks if withdrawal operations are enabled for the specified operation type
// Returns true if withdrawal permission is enabled, regardless of access permission
func (c HaltConfig) IsEnabledWithdraw(op OpType) bool {
	if c[op] == nil {
		return false // Return false if operation type is not configured
	}

	return c[op].IsEnabledWithdraw()
}

// Clone creates a deep copy of the halt configuration
// This ensures that modifications to the clone don't affect the original
func (c HaltConfig) Clone() HaltConfig {
	clone := make(HaltConfig)

	// Copy each halt option by creating a new instance
	for op, option := range c {
		clone[op] = option.Clone()
	}

	return clone
}

// get retrieves the halt option for the specified operation type
// Returns nil if the operation type is not configured
func (c HaltConfig) get(op OpType) *HaltOption {
	return c[op]
}

// set stores the halt option for the specified operation type
// This updates or creates the configuration for the operation type
func (c HaltConfig) set(op OpType, option *HaltOption) {
	c[op] = option
}

// HaltOption represents the permission settings for a specific operation type
// It controls both access and withdrawal permissions independently
type HaltOption struct {
	access   bool // Whether access operations are enabled
	withdraw bool // Whether withdrawal operations are enabled
}

// Enabled checks if both access and withdrawal operations are enabled
// Returns true only when both permissions are enabled
func (o *HaltOption) IsEnabled() bool {
	return o.access && o.withdraw
}

// EnabledAccess checks if access operations are enabled
// Returns the current state of access permission
func (o *HaltOption) IsEnabledAccess() bool {
	return o.access
}

// EnabledWithdraw checks if withdrawal operations are enabled
// Returns the current state of withdrawal permission
func (o *HaltOption) IsEnabledWithdraw() bool {
	return o.withdraw
}

// Clone creates a deep copy of the halt option
// This ensures modifications to the clone don't affect the original
func (o *HaltOption) Clone() *HaltOption {
	return &HaltOption{
		access:   o.access,
		withdraw: o.withdraw,
	}
}

// enableAll enables both access and withdrawal permissions
// This is a convenience method for full operation enablement
func (o *HaltOption) enableAll() {
	o.access = true
	o.withdraw = true
}

// disableAll disables both access and withdrawal permissions
// This is a convenience method for complete operation disables
func (o *HaltOption) disableAll() {
	o.access = false
	o.withdraw = false
}

// enableAccess enables access operations while preserving withdrawal permission
func (o *HaltOption) enableAccess() {
	o.access = true
}

// enableWithdraw enables withdrawal operations while preserving access permission
func (o *HaltOption) enableWithdraw() {
	o.withdraw = true
}

// disableAccess disables access operations while preserving withdrawal permission
func (o *HaltOption) disableAccess() {
	o.access = false
}

// disableWithdraw disables withdrawal operations while preserving access permission
func (o *HaltOption) disableWithdraw() {
	o.withdraw = false
}

// Factory functions for creating halt options with predefined configurations

// newEnabledOption creates a halt option with both access and withdrawal enabled
// This represents a fully operational state
func newEnabledOption() *HaltOption {
	return newHaltOption(true, true)
}

// newAccessOnlyOption creates a halt option with only access enabled
// This enables operations but prevents withdrawals (safe mode)
func newAccessOnlyOption() *HaltOption {
	return newHaltOption(true, false)
}

// newWithdrawOnlyOption creates a halt option with only withdrawal enabled
// This enables emergency withdrawals but prevents new operations
func newWithdrawOnlyOption() *HaltOption {
	return newHaltOption(false, true)
}

// newDisabledOption creates a halt option with both access and withdrawal disabled
// This represents a completely halted state
func newDisabledOption() *HaltOption {
	return newHaltOption(false, false)
}

// newHaltOption creates a halt option with specified access and withdrawal permissions
// This is the base constructor for all halt option variations
func newHaltOption(access bool, withdraw bool) *HaltOption {
	return &HaltOption{
		access:   access,
		withdraw: withdraw,
	}
}

// Configuration factory functions for predefined halt levels

// newNoneConfig creates a configuration where all operations are fully enabled
// This represents the normal operational state (HaltLevelNone)
func newNoneConfig() HaltConfig {
	return HaltConfig{
		OpTypePool:          newEnabledOption(), // enable all operations (access and withdraw)
		OpTypePosition:      newEnabledOption(), // enable all operations (access and withdraw)
		OpTypeProtocolFee:   newEnabledOption(), // enable all operations (access and withdraw)
		OpTypeRouter:        newEnabledOption(), // enable all operations (access and withdraw)
		OpTypeStaker:        newEnabledOption(), // enable all operations (access and withdraw)
		OpTypeLaunchpad:     newEnabledOption(), // enable all operations (access and withdraw)
		OpTypeGovernance:    newEnabledOption(), // enable all operations (access and withdraw)
		OpTypeGovStaker:     newEnabledOption(), // enable all operations (access and withdraw)
		OpTypeXGns:          newEnabledOption(), // enable all operations (access and withdraw)
		OpTypeCommunityPool: newEnabledOption(), // enable all operations (access and withdraw)
		OpTypeEmission:      newEnabledOption(), // enable all operations (access and withdraw)
	}
}

// newSafeModeConfig creates a configuration for safe mode operations
// All operations can be accessed but withdrawals are disabled (HaltLevelSafeMode)
func newSafeModeConfig() HaltConfig {
	return HaltConfig{
		OpTypePool:          newAccessOnlyOption(), // enable only access (access)
		OpTypePosition:      newAccessOnlyOption(), // enable only access (access)
		OpTypeProtocolFee:   newAccessOnlyOption(), // enable only access (access)
		OpTypeRouter:        newAccessOnlyOption(), // enable only access (access)
		OpTypeStaker:        newAccessOnlyOption(), // enable only access (access)
		OpTypeLaunchpad:     newAccessOnlyOption(), // enable only access (access)
		OpTypeGovernance:    newAccessOnlyOption(), // enable only access (access)
		OpTypeGovStaker:     newAccessOnlyOption(), // enable only access (access)
		OpTypeXGns:          newAccessOnlyOption(), // enable only access (access)
		OpTypeCommunityPool: newAccessOnlyOption(), // enable only access (access)
		OpTypeEmission:      newAccessOnlyOption(), // enable only access (access)
	}
}

// newEmergencyConfig creates a configuration for emergency situations
// Only governance operations are fully enabled, others enable only withdrawals (HaltLevelEmergency)
func newEmergencyConfig() HaltConfig {
	return HaltConfig{
		OpTypePool:          newWithdrawOnlyOption(), // enable only withdraw (withdraw)
		OpTypePosition:      newWithdrawOnlyOption(), // enable only withdraw (withdraw)
		OpTypeProtocolFee:   newWithdrawOnlyOption(), // enable only withdraw (withdraw)
		OpTypeRouter:        newWithdrawOnlyOption(), // enable only withdraw (withdraw)
		OpTypeStaker:        newWithdrawOnlyOption(), // enable only withdraw (withdraw)
		OpTypeLaunchpad:     newWithdrawOnlyOption(), // enable only withdraw (withdraw)
		OpTypeGovernance:    newEnabledOption(),      // enable all operations (access and withdraw)
		OpTypeGovStaker:     newWithdrawOnlyOption(), // enable only withdraw (withdraw)
		OpTypeXGns:          newWithdrawOnlyOption(), // enable only withdraw (withdraw)
		OpTypeCommunityPool: newWithdrawOnlyOption(), // enable only withdraw (withdraw)
		OpTypeEmission:      newWithdrawOnlyOption(), // enable only withdraw (withdraw)
	}
}

// newCompleteConfig creates a configuration where all operations are completely disabled
// This represents a full system halt (HaltLevelComplete)
func newCompleteConfig() HaltConfig {
	return HaltConfig{
		OpTypePool:          newDisabledOption(), // disable all operations (no operation)
		OpTypePosition:      newDisabledOption(), // disable all operations (no operation)
		OpTypeProtocolFee:   newDisabledOption(), // disable all operations (no operation)
		OpTypeRouter:        newDisabledOption(), // disable all operations (no operation)
		OpTypeStaker:        newDisabledOption(), // disable all operations (no operation)
		OpTypeLaunchpad:     newDisabledOption(), // disable all operations (no operation)
		OpTypeGovernance:    newDisabledOption(), // disable all operations (no operation)
		OpTypeGovStaker:     newDisabledOption(), // disable all operations (no operation)
		OpTypeXGns:          newDisabledOption(), // disable all operations (no operation)
		OpTypeCommunityPool: newDisabledOption(), // disable all operations (no operation)
		OpTypeEmission:      newDisabledOption(), // disable all operations (no operation)
	}
}