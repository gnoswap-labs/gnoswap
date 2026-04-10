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

func TestAssert_AssertCanWithdraw(t *testing.T) {
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
			uassert.PanicsWithMessage(t, "halted: position:withdraw", func() {
				AssertCanWithdraw(OpTypePosition)
			})
		} else {
			uassert.NotPanics(t, func() { AssertCanWithdraw(OpTypePosition) })
		}
	}

	uassert.PanicsWithMessage(t, "action not allowed for domain: governance:withdraw", func() {
		AssertCanWithdraw(OpTypeGovernance)
	})
}

func TestAssert_InternalActionHelperCoverage(t *testing.T) {
	err := setHaltLevel(HaltLevelEmergency)
	uassert.NoError(t, err)

	uassert.PanicsWithMessage(t, "halted: protocol_fee:operate", func() {
		AssertIsNotHaltedProtocolFee()
	})
	uassert.PanicsWithMessage(t, "halted: community_pool:operate", func() {
		AssertIsNotHaltedCommunityPool()
	})
	uassert.PanicsWithMessage(t, "action not allowed for domain: router:withdraw", func() {
		AssertCanWithdraw(OpTypeRouter)
	})
	uassert.PanicsWithMessage(t, "action not allowed for domain: protocol_fee:withdraw", func() {
		AssertCanWithdraw(OpTypeProtocolFee)
	})
}
