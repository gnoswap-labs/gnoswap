package halt

import (
	"std"
	"strconv"

	"gno.land/r/gnoswap/access"
)

var (
	haltConfig HaltConfig
)

func init() {
	haltConfig = newNoneConfig()
}

// SetHaltLevel sets the global halt level, overriding individual operation settings.
// Only accessible by admin or governance roles. Panics if level is invalid.
// Emits SetHaltLevel event with level details and caller address.
func SetHaltLevel(cur realm, level HaltLevel) {
	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	err := setHaltLevel(level)
	if err != nil {
		panic(err)
	}

	std.Emit(
		"SetHaltLevel",
		"level", level.String(),
		"description", level.Description(),
		"caller", caller.String(),
	)
}

// SetOperationStatus sets halt status for a specific operation type.
// Only accessible by admin or governance roles. Panics if operation type is invalid.
// Emits SetOperationStatus event with operation details and caller address.
func SetOperationStatus(cur realm, op OpType, halted bool) {
	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	if !op.IsValid() {
		panic(makeErrorWithDetails(errInvalidOpType, op.String()))
	}

	haltConfig.set(op, halted)

	std.Emit(
		"SetOperationStatus",
		"operation", string(op),
		"halted", strconv.FormatBool(halted),
		"caller", caller.String(),
	)
}

// setHaltLevel applies predefined halt level configuration.
// Returns error if halt level is invalid.
func setHaltLevel(level HaltLevel) error {
	var config HaltConfig

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
		return makeErrorWithDetails(errInvalidHaltLevel, level.String())
	}

	haltConfig = config

	return nil
}
