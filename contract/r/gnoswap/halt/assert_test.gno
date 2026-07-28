package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestAssert_AssertIsNotHaltedPool(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - should panic", HaltLevelEmergency, true},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Setup
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: pool", func() {
					AssertIsNotHaltedPool()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedPool()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedPosition(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - should panic", HaltLevelEmergency, true},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: position", func() {
					AssertIsNotHaltedPosition()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedPosition()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedProtocolFee(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - should panic", HaltLevelEmergency, true},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: protocol_fee", func() {
					AssertIsNotHaltedProtocolFee()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedProtocolFee()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedRouter(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - should panic", HaltLevelEmergency, true},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: router", func() {
					AssertIsNotHaltedRouter()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedRouter()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedStaker(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - should panic", HaltLevelEmergency, true},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: staker", func() {
					AssertIsNotHaltedStaker()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedStaker()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedLaunchpad(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - should panic", HaltLevelEmergency, true},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: launchpad", func() {
					AssertIsNotHaltedLaunchpad()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedLaunchpad()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedGovernance(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - no panic", HaltLevelEmergency, false},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: governance", func() {
					AssertIsNotHaltedGovernance()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedGovernance()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedGovStaker(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - should panic", HaltLevelEmergency, true},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: gov_staker", func() {
					AssertIsNotHaltedGovStaker()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedGovStaker()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedXGns(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - should panic", HaltLevelEmergency, true},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: xgns", func() {
					AssertIsNotHaltedXGns()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedXGns()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedCommunityPool(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - should panic", HaltLevelEmergency, true},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: community_pool", func() {
					AssertIsNotHaltedCommunityPool()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedCommunityPool()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedEmission(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - no panic", HaltLevelSafeMode, false},
		{"Emergency - should panic", HaltLevelEmergency, true},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: emission", func() {
					AssertIsNotHaltedEmission()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedEmission()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedWithdraw(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"None level - no panic", HaltLevelNone, false},
		{"SafeMode - should panic", HaltLevelSafeMode, true},
		{"Emergency - no panic", HaltLevelEmergency, false},
		{"Complete - should panic", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, "halted: withdraw", func() {
					AssertIsNotHaltedWithdraw()
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedWithdraw()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedOperation(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := setHaltLevel(tt.haltLevel)
			uassert.NoError(t, err)

			if tt.shouldPanic {
				expectedMsg := "halted: " + tt.opType.String()
				uassert.PanicsWithMessage(t, cur, expectedMsg, func() {
					AssertIsNotHaltedOperation(tt.opType)
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					AssertIsNotHaltedOperation(tt.opType)
				})
			}
		})
	}
}
