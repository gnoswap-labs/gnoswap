package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestAssert_AssertIsNotHalted(t *testing.T) {
	type assertFunc func()

	// Operations that panic in Emergency+Complete, pass in None+SafeMode
	standardOps := []struct {
		name     string
		assertFn assertFunc
		panicMsg string
	}{
		{"Pool", AssertIsNotHaltedPool, "halted: pool"},
		{"Position", AssertIsNotHaltedPosition, "halted: position"},
		{"ProtocolFee", AssertIsNotHaltedProtocolFee, "halted: protocol_fee"},
		{"Router", AssertIsNotHaltedRouter, "halted: router"},
		{"Staker", AssertIsNotHaltedStaker, "halted: staker"},
		{"Launchpad", AssertIsNotHaltedLaunchpad, "halted: launchpad"},
		{"GovStaker", AssertIsNotHaltedGovStaker, "halted: gov_staker"},
		{"XGns", AssertIsNotHaltedXGns, "halted: xgns"},
		{"CommunityPool", AssertIsNotHaltedCommunityPool, "halted: community_pool"},
		{"Emission", AssertIsNotHaltedEmission, "halted: emission"},
	}

	for _, op := range standardOps {
		t.Run(op.name, func(t *testing.T) {
			for _, tc := range []struct {
				level       HaltLevel
				shouldPanic bool
			}{
				{HaltLevelNone, false},
				{HaltLevelSafeMode, false},
				{HaltLevelEmergency, true},
				{HaltLevelComplete, true},
			} {
				err := setHaltLevel(tc.level)
				uassert.NoError(t, err)

				if tc.shouldPanic {
					uassert.PanicsWithMessage(t, op.panicMsg, op.assertFn)
				} else {
					uassert.NotPanics(t, op.assertFn)
				}
			}
		})
	}

	// Governance: only panics in Complete
	t.Run("Governance", func(t *testing.T) {
		for _, tc := range []struct {
			level       HaltLevel
			shouldPanic bool
		}{
			{HaltLevelNone, false},
			{HaltLevelSafeMode, false},
			{HaltLevelEmergency, false},
			{HaltLevelComplete, true},
		} {
			err := setHaltLevel(tc.level)
			uassert.NoError(t, err)

			if tc.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: governance", func() {
					AssertIsNotHaltedGovernance()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedGovernance()
				})
			}
		}
	})

	// Withdraw: panics in SafeMode+Complete
	t.Run("Withdraw", func(t *testing.T) {
		for _, tc := range []struct {
			level       HaltLevel
			shouldPanic bool
		}{
			{HaltLevelNone, false},
			{HaltLevelSafeMode, true},
			{HaltLevelEmergency, false},
			{HaltLevelComplete, true},
		} {
			err := setHaltLevel(tc.level)
			uassert.NoError(t, err)

			if tc.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: withdraw", func() {
					AssertIsNotHaltedWithdraw()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedWithdraw()
				})
			}
		}
	})
}

func TestAssert_AssertIsNotHaltedOperation(t *testing.T) {
	tests := []struct {
		name        string
		opType      OpType
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"Pool in None - no panic", OpTypePool, HaltLevelNone, false},
		{"Pool in Emergency - should panic", OpTypePool, HaltLevelEmergency, true},
		{"Governance in Emergency - no panic", OpTypeGovernance, HaltLevelEmergency, false},
		{"Withdraw in SafeMode - should panic", OpTypeWithdraw, HaltLevelSafeMode, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				expectedMsg := "halted: " + tt.opType.String()
				uassert.PanicsWithMessage(t, expectedMsg, func() {
					AssertIsNotHaltedOperation(tt.opType)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedOperation(tt.opType)
				})
			}
		})
	}
}
