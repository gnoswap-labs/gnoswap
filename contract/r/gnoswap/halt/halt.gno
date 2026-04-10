package halt

import (
	"chain"
	"chain/runtime"
	"strconv"

	"gno.land/r/gnoswap/access"
)

var haltStates HaltStateManager

func init() {
	haltStates = newHaltStateManagerByConfig(newNoneConfig())
}

func SetHaltLevel(cur realm, level HaltLevel) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)
	err := setHaltLevel(level)
	if err != nil {
		panic(err)
	}
	chain.Emit("SetHaltLevel", "level", level.String(), "description", level.Description(), "caller", caller.String())
}

// Backward-compatible shorthand for operate action.
func SetOperationStatus(cur realm, op OpType, halted bool) {
	SetActionStatus(cur, op, ActionOperate, halted)
}

func SetActionStatus(cur realm, domain OpType, action Action, halted bool) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)
	err := haltStates.setActionHalted(domain, action, halted)
	if err != nil {
		panic(err)
	}
	chain.Emit(
		"SetActionStatus",
		"domain", domain.String(),
		"action", action.String(),
		"halted", strconv.FormatBool(halted),
		"caller", caller.String(),
	)
}

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
	return haltStates.updateByConfig(config)
}
