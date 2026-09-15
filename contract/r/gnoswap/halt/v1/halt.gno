package halt

import (
	"chain"
	"strconv"

	"gno.land/r/gnoswap/access/v1"
)

var haltStates HaltStateManager

func init() {
	haltStates = newHaltStateManagerByConfig(newNoneConfig())
}

// SetHaltLevel sets the global halt level.
//
// Parameters:
//   - level: halt level to apply (None, SafeMode, Emergency, Complete)
//
// Only callable by admin or governance.
// Levels that halt withdrawals (SafeMode, Complete) are only callable by governance,
// so a single admin key cannot freeze user funds.
func SetHaltLevel(cur realm, level HaltLevel) {
	caller := cur.Previous().Address()
	assertCanSetWithdrawHalted(caller, levelHaltsWithdraw(level))

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
// Halting withdrawals is only callable by governance.
func SetOperationStatus(cur realm, op OpType, halted bool) {
	caller := cur.Previous().Address()
	assertCanSetWithdrawHalted(caller, op == OpTypeWithdraw && halted)

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

// assertCanSetWithdrawHalted enforces that only governance can halt withdrawals,
// while admin or governance can perform any other halt change.
func assertCanSetWithdrawHalted(caller address, haltsWithdraw bool) {
	if haltsWithdraw {
		access.AssertIsGovernance(caller)
		return
	}

	access.AssertIsAdminOrGovernance(caller)
}

// levelHaltsWithdraw returns true if the halt level halts withdraw operations.
func levelHaltsWithdraw(level HaltLevel) bool {
	switch level {
	case HaltLevelSafeMode, HaltLevelComplete:
		return true
	default:
		return false
	}
}
