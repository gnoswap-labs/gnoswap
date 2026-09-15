package halt

import (
	"chain"
	"strconv"

	"gno.land/r/gnoswap/access"
)

var haltStates HaltStateManager

func init() {
	haltStates = newHaltStateManagerByConfig(newNoneConfig())
}

// SetHaltLevel sets the global halt level.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - level: halt level to apply (None, SafeMode, Emergency, or Complete).
//
// Only callable by admin or governance.
func SetHaltLevel(cur realm, level HaltLevel) {
	caller := cur.Previous().Address()
	access.AssertIsAdminOrGovernance(caller)

	err := setHaltLevel(level)
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"SetHaltLevel",
		"level", level.String(),
		"description", level.Description(),
		"caller", caller.String(),
	)
}

// SetOperationStatus sets the halt status for a specific operation.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - op: operation type whose halt status is changed.
//   - halted: true to block the operation, false to allow it.
//
// Only callable by admin or governance.
func SetOperationStatus(cur realm, op OpType, halted bool) {
	caller := cur.Previous().Address()
	access.AssertIsAdminOrGovernance(caller)

	if !op.IsValid() {
		panic(makeErrorWithDetails(errInvalidOpType, op.String()))
	}

	err := haltStates.setOperationHalted(op, halted)
	if err != nil {
		panic(err)
	}

	chain.Emit(
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

	return haltStates.updateOperationHaltsByConfig(config)
}
