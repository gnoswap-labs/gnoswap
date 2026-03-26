package halt

import (
	"chain"
	"chain/runtime"
	"strconv"

	"gno.land/r/gnoswap/access"
)

var haltState uint64

func init() {
	haltState = ConfigNone
}

// SetHaltLevel sets the global halt level.
//
// Parameters:
//   - level: halt level to apply (None, SafeMode, Emergency, Complete)
//
// Only callable by admin or governance.
func SetHaltLevel(cur realm, level HaltLevel) {
	caller := runtime.PreviousRealm().Address()
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

// SetOperationStatus sets halt status for a specific operation.
//
// Parameters:
//   - op: operation type
//   - halted: true to halt, false to resume
//
// Only callable by admin or governance.
func SetOperationStatus(cur realm, op OpType, halted bool) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	if !op.IsValid() {
		panic(makeErrorWithDetails(errInvalidOpType, op.String()))
	}

	if halted {
		haltState |= uint64(op)
	} else {
		haltState &^= uint64(op)
	}

	chain.Emit(
		"SetOperationStatus",
		"operation", op.String(),
		"halted", strconv.FormatBool(halted),
		"caller", caller.String(),
	)
}

func setHaltLevel(level HaltLevel) error {
	switch level {
	case HaltLevelNone:
		haltState = ConfigNone
	case HaltLevelSafeMode:
		haltState = ConfigSafeMode
	case HaltLevelEmergency:
		haltState = ConfigEmergency
	case HaltLevelComplete:
		haltState = ConfigComplete
	default:
		return makeErrorWithDetails(errInvalidHaltLevel, level.String())
	}
	return nil
}
