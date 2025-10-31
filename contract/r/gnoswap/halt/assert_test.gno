package halt

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestAssert_AssertIsNotHaltedPool(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: pool", func() {
					AssertIsNotHaltedPool()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedPool()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedPosition(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: position", func() {
					AssertIsNotHaltedPosition()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedPosition()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedProtocolFee(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: protocol_fee", func() {
					AssertIsNotHaltedProtocolFee()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedProtocolFee()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedRouter(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: router", func() {
					AssertIsNotHaltedRouter()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedRouter()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedStaker(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: staker", func() {
					AssertIsNotHaltedStaker()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedStaker()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedLaunchpad(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: launchpad", func() {
					AssertIsNotHaltedLaunchpad()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedLaunchpad()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedGovernance(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: governance", func() {
					AssertIsNotHaltedGovernance()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedGovernance()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedGovStaker(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: gov_staker", func() {
					AssertIsNotHaltedGovStaker()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedGovStaker()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedXGns(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: xgns", func() {
					AssertIsNotHaltedXGns()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedXGns()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedCommunityPool(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: community_pool", func() {
					AssertIsNotHaltedCommunityPool()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedCommunityPool()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedEmission(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: emission", func() {
					AssertIsNotHaltedEmission()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedEmission()
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedWithdraw(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: withdraw", func() {
					AssertIsNotHaltedWithdraw()
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedWithdraw()
				})
			}
		})
	}
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
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

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

func TestAssert_AssertIsNotHaltedPoolWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"Emergency version 1 - should panic", HaltLevelEmergency, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: pool", func() {
					AssertIsNotHaltedPoolWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedPoolWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedPositionWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"Emergency version 1 - should panic", HaltLevelEmergency, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: position", func() {
					AssertIsNotHaltedPositionWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedPositionWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedProtocolFeeWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"Emergency version 1 - should panic", HaltLevelEmergency, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: protocol_fee", func() {
					AssertIsNotHaltedProtocolFeeWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedProtocolFeeWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedRouterWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"Emergency version 1 - should panic", HaltLevelEmergency, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: router", func() {
					AssertIsNotHaltedRouterWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedRouterWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedStakerWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"Emergency version 1 - should panic", HaltLevelEmergency, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: staker", func() {
					AssertIsNotHaltedStakerWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedStakerWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedLaunchpadWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"Emergency version 1 - should panic", HaltLevelEmergency, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: launchpad", func() {
					AssertIsNotHaltedLaunchpadWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedLaunchpadWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedGovernanceWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"Emergency version 1 - no panic", HaltLevelEmergency, 1, false},
		{"Complete version 1 - should panic", HaltLevelComplete, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: governance", func() {
					AssertIsNotHaltedGovernanceWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedGovernanceWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedGovStakerWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"Emergency version 1 - should panic", HaltLevelEmergency, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: gov_staker", func() {
					AssertIsNotHaltedGovStakerWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedGovStakerWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedXGnsWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"Emergency version 1 - should panic", HaltLevelEmergency, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: xgns", func() {
					AssertIsNotHaltedXGnsWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedXGnsWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedCommunityPoolWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"Emergency version 1 - should panic", HaltLevelEmergency, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: community_pool", func() {
					AssertIsNotHaltedCommunityPoolWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedCommunityPoolWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedWithdrawWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"None level version 1 - no panic", HaltLevelNone, 1, false},
		{"SafeMode version 1 - should panic", HaltLevelSafeMode, 1, true},
		{"Emergency version 1 - no panic", HaltLevelEmergency, 1, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, "halted: withdraw", func() {
					AssertIsNotHaltedWithdrawWithVersion(tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedWithdrawWithVersion(tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHaltedOperationWithVersion(t *testing.T) {
	tests := []struct {
		name        string
		opType      OpType
		haltLevel   HaltLevel
		version     int
		shouldPanic bool
	}{
		{"Pool in None version 1 - no panic", OpTypePool, HaltLevelNone, 1, false},
		{"Pool in Emergency version 1 - should panic", OpTypePool, HaltLevelEmergency, 1, true},
		{"Governance in Emergency version 1 - no panic", OpTypeGovernance, HaltLevelEmergency, 1, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				expectedMsg := "halted: " + tt.opType.String()
				uassert.PanicsWithMessage(t, expectedMsg, func() {
					AssertIsNotHaltedOperationWithVersion(tt.opType, tt.version)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHaltedOperationWithVersion(tt.opType, tt.version)
				})
			}
		})
	}
}

func TestAssert_AssertIsNotHalted(t *testing.T) {
	tests := []struct {
		name        string
		opTypes     []OpType
		haltLevel   HaltLevel
		shouldPanic bool
	}{
		{"Single op not halted", []OpType{OpTypePool}, HaltLevelNone, false},
		{"Single op halted", []OpType{OpTypePool}, HaltLevelEmergency, true},
		{"Multiple ops not halted", []OpType{OpTypePool, OpTypePosition}, HaltLevelNone, false},
		{"One of multiple ops halted", []OpType{OpTypePool, OpTypeGovernance}, HaltLevelEmergency, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))

			if tt.shouldPanic {
				uassert.Panics(t, func() {
					AssertIsNotHalted(tt.opTypes...)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHalted(tt.opTypes...)
				})
			}
		})
	}
}

// Helper function to get config by halt level
func getConfigByLevel(level HaltLevel) HaltConfig {
	switch level {
	case HaltLevelNone:
		return newNoneConfig()
	case HaltLevelSafeMode:
		return newSafeModeConfig()
	case HaltLevelEmergency:
		return newEmergencyConfig()
	case HaltLevelComplete:
		return newCompleteConfig()
	default:
		return newNoneConfig()
	}
}
