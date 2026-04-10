package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestAssert_OperateWrappers(t *testing.T) {
	err := setHaltLevel(HaltLevelEmergency)
	uassert.NoError(t, err)

	uassert.PanicsWithMessage(t, "halted: pool:operate", func() { AssertIsNotHaltedPool() })
	uassert.PanicsWithMessage(t, "halted: position:operate", func() { AssertIsNotHaltedPosition() })
	uassert.NotPanics(t, func() { AssertIsNotHaltedGovernance() })
}

func TestAssert_AssertCanRecover(t *testing.T) {
	tests := []struct {
		level       HaltLevel
		shouldPanic bool
	}{
		{HaltLevelNone, false},
		{HaltLevelSafeMode, true},
		{HaltLevelEmergency, false},
		{HaltLevelComplete, true},
	}

	for _, tt := range tests {
		err := setHaltLevel(tt.level)
		uassert.NoError(t, err)
		if tt.shouldPanic {
			uassert.PanicsWithMessage(t, "halted: position:recover", func() {
				AssertCanRecover(OpTypePosition)
			})
		} else {
			uassert.NotPanics(t, func() { AssertCanRecover(OpTypePosition) })
		}
	}

	uassert.PanicsWithMessage(t, "action not allowed for domain: governance:recover", func() {
		AssertCanRecover(OpTypeGovernance)
	})
}

func TestAssert_AssertActionAllowed(t *testing.T) {
	err := setHaltLevel(HaltLevelEmergency)
	uassert.NoError(t, err)

	uassert.PanicsWithMessage(t, "halted: protocol_fee:operate", func() {
		AssertActionAllowed(OpTypeProtocolFee, ActionOperate)
	})
	uassert.PanicsWithMessage(t, "halted: community_pool:operate", func() {
		AssertActionAllowed(OpTypeCommunityPool, ActionOperate)
	})
	uassert.PanicsWithMessage(t, "action not allowed for domain: router:recover", func() {
		AssertActionAllowed(OpTypeRouter, ActionRecover)
	})
}
