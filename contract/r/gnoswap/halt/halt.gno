package halt

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"
)

// Global halt configuration that controls all operation permissions
var (
	haltConfig HaltConfig
)

// Initialize the halt system with all operations enabled
func init() {
	haltConfig = newNoneConfig()
}

/** Core public API **/

// SetHaltLevel sets the global halt level for the entire system
// Only admin or governance can call this function
// This function overrides all individual operation settings
func SetHaltLevel(cur realm, level HaltLevel) {
	caller := std.PreviousRealm().Address()
	assertIsAdminOrGovernance(caller)

	// Apply the new halt level configuration
	err := setHaltLevel(level)
	if err != nil {
		panic(err)
	}

	// Emit event for monitoring and debugging
	std.Emit(
		"SetHaltLevel",
		"level", level.String(),
		"description", level.Description(),
		"caller", caller.String(),
	)
}

// EnableWithdrawals enables withdrawal operations for all operation types
// Only admin or governance can call this function
func EnableWithdrawals(cur realm) {
	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	assertIsAdminOrGovernance(caller)

	// Update all operations to allow withdrawals
	config, err := updateWithdraws(haltConfig, true)
	if err != nil {
		panic(err)
	}

	haltConfig = config

	// Emit event for monitoring
	std.Emit(
		"EnableWithdrawals",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"enabled", strconv.FormatBool(true),
	)
}

// DisableWithdrawals disables withdrawal operations for all operation types
// Only admin or governance can call this function
func DisableWithdrawals(cur realm) {
	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	assertIsAdminOrGovernance(caller)

	// Update all operations to disable withdrawals
	config, err := updateWithdraws(haltConfig, false)
	if err != nil {
		panic(err)
	}

	haltConfig = config

	// Emit event for monitoring
	std.Emit(
		"EnableWithdrawals",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"enabled", strconv.FormatBool(false),
	)
}

// SetOperationStatus sets both access and withdrawal status for a specific operation type
// Only admin or governance can call this function
func SetOperationStatus(cur realm, op OpType, enabled bool) {
	caller := std.PreviousRealm().Address()
	assertIsAdminOrGovernance(caller)

	// Get current operation configuration
	opOption := haltConfig.get(op)

	// Update access permission
	opOption, err := updateHaltAccessOption(opOption, enabled)
	if err != nil {
		panic(err)
	}

	// Update withdrawal permission
	opOption, err = updateHaltWithdrawOption(opOption, enabled)
	if err != nil {
		panic(err)
	}

	// Save the updated configuration
	haltConfig.set(op, opOption)

	// Emit event for monitoring
	std.Emit(
		"SetOperationStatus",
		"operation", string(op),
		"enabledAccess", strconv.FormatBool(opOption.access),
		"enabledWithdraw", strconv.FormatBool(opOption.withdraw),
		"caller", caller.String(),
	)
}

// SetOperationAccessStatus sets only the access status for a specific operation type
// Only admin or governance can call this function
func SetOperationAccessStatus(cur realm, op OpType, enabled bool) {
	caller := std.PreviousRealm().Address()
	assertIsAdminOrGovernance(caller)

	// Get current operation configuration
	opOption := haltConfig.get(op)

	// Update only access permission, leave withdrawal unchanged
	opOption, err := updateHaltAccessOption(opOption, enabled)
	if err != nil {
		panic(err)
	}

	// Save the updated configuration
	haltConfig.set(op, opOption)

	// Emit event for monitoring
	std.Emit(
		"SetOperationStatus",
		"operation", string(op),
		"enabledAccess", strconv.FormatBool(opOption.access),
		"enabledWithdraw", strconv.FormatBool(opOption.withdraw),
		"caller", caller.String(),
	)
}

// SetOperationWithdrawStatus sets only the withdrawal status for a specific operation type
// Only admin or governance can call this function
func SetOperationWithdrawStatus(cur realm, op OpType, enabled bool) {
	caller := std.PreviousRealm().Address()
	assertIsAdminOrGovernance(caller)

	// Get current operation configuration
	opOption := haltConfig.get(op)

	// Update only withdrawal permission, leave access unchanged
	opOption, err := updateHaltWithdrawOption(opOption, enabled)
	if err != nil {
		panic(err)
	}

	// Save the updated configuration
	haltConfig.set(op, opOption)

	// Emit event for monitoring
	std.Emit(
		"SetOperationStatus",
		"operation", string(op),
		"enabledAccess", strconv.FormatBool(opOption.access),
		"enabledWithdraw", strconv.FormatBool(opOption.withdraw),
		"caller", caller.String(),
	)
}

// setHaltLevel is an internal function that applies a predefined halt level configuration
// This replaces the entire halt configuration with the level's default settings
func setHaltLevel(level HaltLevel) error {
	var config HaltConfig

	// Select the appropriate configuration based on halt level
	switch level {
	case HaltLevelNone:
		config = newNoneConfig()
	case HaltLevelSafeMode:
		config = newSafeModeConfig()
	case HaltLevelEmergency:
		config = newEmergencyConfig()
	case HaltLevelComplete:
		config = newCompleteConfig()
	default:
		return ufmt.Errorf("invalid halt level: %s", level)
	}

	// Apply the new configuration
	haltConfig = config

	return nil
}

// updateHaltAccessOption updates the access permission for a specific halt option
// Returns error if the option is nil
func updateHaltAccessOption(option *HaltOption, access bool) (*HaltOption, error) {
	if option == nil {
		return nil, ufmt.Errorf("halt option is nil")
	}	

	// Enable or isable access based on the flag
	if access {
		option.enableAccess()
	} else {
		option.disableAccess()
	}

	return option, nil
}

// updateHaltWithdrawOption updates the withdrawal permission for a specific halt option
// Returns error if the option is nil
func updateHaltWithdrawOption(option *HaltOption, withdraw bool) (*HaltOption, error) {
	if option == nil {
		return nil, ufmt.Errorf("halt option is nil")
	}

	// Enable or isable withdrawal based on the flag
	if withdraw {
		option.enableWithdraw()
	} else {
		option.disableWithdraw()
	}

	return option, nil
}

// updateAccesses updates access permissions for all operation types in the configuration
// Used for bulk access control operations
func updateAccesses(config HaltConfig, access bool) (HaltConfig, error) {
	// Iterate through all operation types and update access
	for op, opOption := range config {
		if access {
			opOption.enableAccess()
		} else {
			opOption.disableAccess()
		}

		// Save the updated option back to config
		config.set(op, opOption)
	}

	return config, nil
}

// updateWithdraws updates withdrawal permissions for all operation types in the configuration
// Used for bulk withdrawal control operations
func updateWithdraws(config HaltConfig, withdraw bool) (HaltConfig, error) {
	// Iterate through all operation types and update withdrawal
	for op, opOption := range config {
		if withdraw {
			opOption.enableWithdraw()
		} else {
			opOption.disableWithdraw()
		}

		// Save the updated option back to config
		config.set(op, opOption)
	}

	return config, nil
}