package halt

import (
	"std"
	"strconv"

	"gno.land/r/gnoswap/access"
)

var haltConfig HaltConfig

func init() {
	haltConfig = newNoneConfig()
}

// SetHaltLevel sets the global halt level.
//
// Parameters:
//   - level: halt level to apply (None, SafeMode, Emergency, Complete)
//
// Only callable by admin or governance.
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

// SetOperationStatus sets halt status for a specific operation.
//
// Parameters:
//   - op: operation type
//   - halted: true to halt, false to resume
//
// Only callable by admin or governance.
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
