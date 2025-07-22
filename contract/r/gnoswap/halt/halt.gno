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

// SetOperationStatus sets both access and withdrawal status for a specific operation type
// Only admin or governance can call this function
func SetOperationStatus(cur realm, op OpType, halted bool) {
	caller := std.PreviousRealm().Address()
	assertIsAdminOrGovernance(caller)

	if !op.IsValid() {
		panic(ufmt.Errorf("invalid operation type: %s", op))
	}

	// Save the updated configuration
	haltConfig.set(op, halted)

	// Emit event for monitoring
	std.Emit(
		"SetOperationStatus",
		"operation", string(op),
		"halted", strconv.FormatBool(halted),
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
