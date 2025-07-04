package halt

import (
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/uassert"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	govRealm     = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
	userRealm    = std.NewCodeRealm("gno.land/r/demo/users") // for testing non-governance, non-admin caller
)

func TestHalts(t *testing.T) {
	t.Run("Operation specific checks in MainnetSafeMode", func(t *testing.T) {
		// Withdrawals should be disabled in MainnetSafeMode
		err := IsHalted(OpTypeWithdraw)
		uassert.Error(t, err)
	})

	t.Run("Operation specific checks in EmergencyHalt", func(t *testing.T) {
		// Withdrawals should be enabled in EmergencyHalt
		err := IsHalted(OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter, OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance)
		uassert.NoError(t, err)
	})
}

func TestSetHaltLevelByAdminAndGovernance(t *testing.T) {
	t.Run("with non-admin or non-governance privilege, should fail", func(t *testing.T) {
		testing.SetRealm(userRealm)
		err := SetHaltLevelByAdmin(cross, LvNoHalt)
		uassert.Error(t, err)
	})

	t.Run("with admin privilege, success", func(t *testing.T) {
		testing.SetRealm(adminRealm)

		// Initially we're in MainnetSafeMode
		if GetCurrentHaltLevel() != LvMainnetSafeMode {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvMainnetSafeMode)
		}

		// Change to NoHalt
		err := SetHaltLevelByAdmin(cross, LvNoHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
		}

		// Back to CompleteHalt
		err = SetHaltLevelByAdmin(cross, LvCompleteHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvCompleteHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvCompleteHalt)
		}
	})
}

func TestSetHalt(t *testing.T) {
	t.Run("with admin privilege, success", func(t *testing.T) {
		testing.SetRealm(adminRealm)
		// err := SetHalt(true)
		err := SetHalt(cross, true)
		uassert.NoError(t, err)
	})

	t.Run("with governance privilege, success", func(t *testing.T) {
		testing.SetRealm(govRealm)

		// Currently in CompleteHalt from previous test
		uassert.True(t, GetHalt())

		err := SetHalt(cross, false) // try to set to NoHalt
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
		}
	})
}

func TestSetHaltWithLevel(t *testing.T) {
	t.Run("with non-privileged user, should fail", func(t *testing.T) {
		testing.SetRealm(userRealm)
		err := SetHalt(cross, true, LvEmergencyHalt)
		uassert.Error(t, err)
	})

	t.Run("admin can set EmergencyHalt and CompleteHalt", func(t *testing.T) {
		testing.SetRealm(adminRealm)

		// Set EmergencyHalt
		err := SetHalt(cross, true, LvEmergencyHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvEmergencyHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvEmergencyHalt)
		}

		// In EmergencyHalt, only withdrawals should be allowed
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
		err = IsHalted(OpTypePool)
		uassert.Error(t, err)

		// Set CompleteHalt
		err = SetHalt(cross, true, LvCompleteHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvCompleteHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvCompleteHalt)
		}

		// In CompleteHalt, all operations should be halted
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
		err = IsHalted(OpTypePool)
		uassert.Error(t, err)
	})

	t.Run("governance can set EmergencyHalt and CompleteHalt", func(t *testing.T) {
		testing.SetRealm(govRealm)

		// Set EmergencyHalt
		err := SetHalt(cross, true, LvEmergencyHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvEmergencyHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvEmergencyHalt)
		}

		// Set CompleteHalt
		err = SetHalt(cross, true, LvCompleteHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvCompleteHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvCompleteHalt)
		}
	})

	t.Run("invalid halt levels should fail", func(t *testing.T) {
		testing.SetRealm(adminRealm)

		// Try to set ContractHalt (not allowed)
		err := SetHalt(cross, true, LvContractHalt)
		uassert.Error(t, err)

		// Try to set MainnetSafeMode (not allowed)
		err = SetHalt(cross, true, LvMainnetSafeMode)
		uassert.Error(t, err)
	})

	t.Run("unhalt should always set to NoHalt", func(t *testing.T) {
		testing.SetRealm(adminRealm)

		// First set to EmergencyHalt
		err := SetHalt(cross, true, LvEmergencyHalt)
		uassert.NoError(t, err)

		// Unhalt should set to NoHalt regardless of current level
		err = SetHalt(cross, false)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
		}
	})

	t.Run("default halt level should be CompleteHalt", func(t *testing.T) {
		testing.SetRealm(adminRealm)

		// Set halt without specifying level
		err := SetHalt(cross, true)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvCompleteHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvCompleteHalt)
		}
	})

	t.Run("explicit NoHalt setting should work", func(t *testing.T) {
		testing.SetRealm(adminRealm)

		// First set to EmergencyHalt
		err := SetHalt(cross, true, LvEmergencyHalt)
		uassert.NoError(t, err)

		// Explicitly set to NoHalt
		err = SetHalt(cross, true, LvNoHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
		}
	})
}

type haltTestCases struct {
	opType    OpType
	wantError bool
}

func TestEnableOperationsForTestnet(t *testing.T) {
	// Setup test with admin privileges
	func() {
		testing.SetRealm(adminRealm)

		// First set to MainnetSafeMode
		err := SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != LvMainnetSafeMode {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvMainnetSafeMode)
		}

		// Verify initially all operations except governance are disabled
		isHaltedTests := []haltTestCases{
			{OpTypeWithdraw, true},
			{OpTypeGovernance, false},
		}

		for _, tt := range isHaltedTests {
			err := IsHalted(tt.opType)
			if tt.wantError {
				uassert.Error(t, err)
				return
			}
			uassert.NoError(t, err)
		}

		t.Run("Enable withdrawals", func(t *testing.T) {
			err := EnableWithdrawalsForTestnet(cross)
			uassert.NoError(t, err)
			tests := []haltTestCases{
				{OpTypeWithdraw, false}, // now enabled

				// contract operations should be enabled
				{OpTypePool, false},
				{OpTypePosition, false},
				{OpTypeProtocolFee, false},
				{OpTypeRouter, false},
				{OpTypeStaker, false},
				{OpTypeLaunchpad, false},
			}

			for _, tt := range tests {
				err := IsHalted(tt.opType)
				if tt.wantError {
					uassert.Error(t, err)
					return
				}
				uassert.NoError(t, err)
			}
		})

		t.Run("Move to NoHalt after testing", func(t *testing.T) {
			// Finally transition to NoHalt
			err := SetHaltLevelByAdmin(cross, LvNoHalt)
			uassert.NoError(t, err)

			// Now GetHalt() should return false
			uassert.False(t, GetHalt())

			if GetCurrentHaltLevel() != LvNoHalt {
				t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
			}
		})
	}()
}

func TestCustomOperationHalts(t *testing.T) {
	// Setup test with admin privileges
	testing.SetRealm(adminRealm)

	// Define custom operation types for testing
	customOp1 := OpType("CUSTOM_OP_1")
	customOp2 := OpType("CUSTOM_OP_2")
	invalidOp := OpType("INVALID_OP")

	t.Run("Check undefined custom operations", func(t *testing.T) {
		// Set to NoHalt first
		err := SetHaltLevelByAdmin(cross, LvNoHalt)
		uassert.NoError(t, err)

		// Even in NoHalt, undefined operations should be considered halted
		err = IsHalted(customOp1)
		uassert.Error(t, err)

		// Multiple operations including undefined ones
		err = IsHalted(OpTypeWithdraw, customOp1)
		uassert.Error(t, err)
	})

	t.Run("Check multiple custom operations", func(t *testing.T) {
		// Test with multiple custom operations
		err := IsHalted(customOp1, customOp2, invalidOp)
		uassert.Error(t, err)

		// Mix of valid and custom operations
		err = IsHalted(OpTypeWithdraw, customOp1, customOp2)
		uassert.Error(t, err)
	})

	t.Run("Check operation type string representation", func(t *testing.T) {
		err := IsHalted(customOp1)
		if err == nil {
			t.Fatal("expected error for custom operation")
		}
		// Verify error message contains the custom operation name
		if !strings.Contains(err.Error(), string(customOp1)) {
			t.Fatalf("error message should contain operation name '%s', got: %s", customOp1, err.Error())
		}
	})
}

func TestOperationStatusEdgeCases(t *testing.T) {
	// Setup test with admin privileges
	testing.SetRealm(adminRealm)

	t.Run("EnableOperations in non-MainnetSafeMode", func(t *testing.T) {
		// First set to NoHalt
		err := SetHaltLevelByAdmin(cross, LvNoHalt)
		uassert.NoError(t, err)

		// Try to enable operations in NoHalt mode - should return nil without changing state
		err = EnableWithdrawalsForTestnet(cross)
		uassert.NoError(t, err)

		// Verify operations maintain their NoHalt state
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err, "should not change state in NoHalt")
	})

	t.Run("Operation state transitions during halt level changes", func(t *testing.T) {
		// Set to MainnetSafeMode
		err := SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
		uassert.NoError(t, err)

		// Enable all operations in MainnetSafeMode
		err = EnableWithdrawalsForTestnet(cross)
		uassert.NoError(t, err)

		// Change to EmergencyHalt - should override previous settings
		err = SetHaltLevelByAdmin(cross, LvEmergencyHalt)
		uassert.NoError(t, err)

		// In EmergencyHalt, only withdrawals should be allowed
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)

		// Change back to MainnetSafeMode
		err = SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
		uassert.NoError(t, err)

		// Check if operations return to their MainnetSafeMode defaults
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
	})
}

func TestModeTransitions(t *testing.T) {
	testing.SetRealm(adminRealm)

	t.Run("MainnetSafeMode to NoHalt transition", func(t *testing.T) {
		// Set initial state to MainnetSafeMode
		err := SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
		uassert.NoError(t, err)

		// Enable all operations in MainnetSafeMode
		err = EnableWithdrawalsForTestnet(cross)
		uassert.NoError(t, err)

		// Verify current state in MainnetSafeMode
		initialState := map[OpType]bool{
			OpTypeWithdraw:   true,
			OpTypeGovernance: true,
		}

		for op, shouldBeEnabled := range initialState {
			err := IsHalted(op)
			if shouldBeEnabled {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err)
			}
		}

		// Transition to NoHalt
		err = SetHaltLevelByAdmin(cross, LvNoHalt)
		uassert.NoError(t, err)
		uassert.False(t, GetHalt())
		currentHaltLevel := GetCurrentHaltLevel()
		if currentHaltLevel != LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", currentHaltLevel, LvNoHalt)
		}

		// All operations should be enabled in NoHalt
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
	})

	t.Run("Emergency Mode transitions", func(t *testing.T) {
		// default state: NoHalt
		err := SetHaltLevelByAdmin(cross, LvNoHalt)
		uassert.NoError(t, err)

		// NoHalt -> EmergencyHalt
		err = SetHaltLevelByAdmin(cross, LvEmergencyHalt)
		uassert.NoError(t, err)

		// only withdrawals should be allowed
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)

		// EmergencyHalt -> CompleteHalt
		err = SetHaltLevelByAdmin(cross, LvCompleteHalt)
		uassert.NoError(t, err)

		// all contract operations should be halted
		err = IsHalted(OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter, OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance)
		uassert.Error(t, err)

		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
	})

	t.Run("Mode transition edge cases", func(t *testing.T) {
		// transition to same mode
		err := SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
		uassert.NoError(t, err)
		err = SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
		uassert.NoError(t, err)

		// rapid mode transitions
		modes := []LevelID{
			LvNoHalt,
			LvMainnetSafeMode,
			LvEmergencyHalt,
			LvCompleteHalt,
			LvNoHalt,
		}

		for _, mode := range modes {
			err = SetHaltLevelByAdmin(cross, mode)
			uassert.NoError(t, err)
			if mode != GetCurrentHaltLevel() {
				t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), mode)
			}
		}

		// operation status preservation after mode cycle
		err = SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
		uassert.NoError(t, err)

		// enable all operations
		err = EnableWithdrawalsForTestnet(cross)
		uassert.NoError(t, err)

		// cycle through modes and back
		err = SetHaltLevelByAdmin(cross, LvEmergencyHalt)
		uassert.NoError(t, err)
		err = SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
		uassert.NoError(t, err)

		// check operation states are reset to MainnetSafeMode defaults
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
	})
}
