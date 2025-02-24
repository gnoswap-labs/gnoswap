package halt

import (
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/uassert"

	"gno.land/p/gnoswap/consts"
	phalt "gno.land/p/gnoswap/halt"
)

var (
	adminRealm = std.NewUserRealm(consts.ADMIN)
	govRealm   = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
	userRealm  = std.NewCodeRealm("gno.land/r/demo/users") // for testing non-governance, non-admin caller
)

func TestHalts(t *testing.T) {
	t.Run("GetHalt() initial value", func(t *testing.T) {
		// Initially we're in MainnetSafeMode which should report as halted
		uassert.True(t, GetHalt())
	})

	t.Run("Operation specific checks in MainnetSafeMode", func(t *testing.T) {
		// Withdrawals should be enabled in MainnetSafeMode
		err := IsHalted(OpTypeWithdraw)
		uassert.Error(t, err)

		// Swaps should be disabled in MainnetSafeMode
		err = IsHalted(OpTypeSwap)
		uassert.NoError(t, err)
	})
}

func TestSetHaltLevelByAdmin(t *testing.T) {
	t.Run("with non-admin privilege, panics", func(t *testing.T) {
		std.TestSetRealm(userRealm)
		err := SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.Error(t, err)
	})

	t.Run("with admin privilege, success", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		// Initially we're in MainnetSafeMode
		uassert.True(t, GetHalt())
		if GetCurrentHaltLevel() != LvMainnetSafeMode {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvMainnetSafeMode)
		}

		// Change to NoHalt
		err := SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != phalt.LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), phalt.LvNoHalt)
		}

		// Back to CompleteHalt
		err = SetHaltLevelByAdmin(phalt.LvCompleteHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != phalt.LvCompleteHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), phalt.LvCompleteHalt)
		}
	})
}

func TestSetHalt(t *testing.T) {
	t.Run("with admin (non-governance) privilege, should fail", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		err := SetHalt(false)
		uassert.Error(t, err)
	})

	t.Run("with governance privilege, success", func(t *testing.T) {
		std.TestSetRealm(govRealm)

		// Currently in CompleteHalt from previous test
		uassert.True(t, GetHalt())

		err := SetHalt(false) // try to set to NoHalt
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != phalt.LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), phalt.LvNoHalt)
		}
	})
}

type haltTestCases struct {
	opType    phalt.OpType
	wantError bool
}

func TestEnableOperationsForTestnet(t *testing.T) {
	// Setup test with admin privileges
	std.TestSetRealm(adminRealm)

	// First set to MainnetSafeMode
	err := SetHaltLevelByAdmin(LvMainnetSafeMode)
	uassert.NoError(t, err)
	if GetCurrentHaltLevel() != LvMainnetSafeMode {
		t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvMainnetSafeMode)
	}

	// Verify initially all operations except governance are disabled
	isHaltedTests := []haltTestCases{
		{phalt.OpTypeWithdraw, true},
		{phalt.OpTypeSwap, false},
		{phalt.OpTypeLiquidity, false},
		{phalt.OpTypeGovernance, false},
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
		err := EnableWithdrawalsForTestnet()
		uassert.NoError(t, err)
		tests := []haltTestCases{
			{phalt.OpTypeWithdraw, false}, // now enabled
			{phalt.OpTypeSwap, true},      // still disabled
			{phalt.OpTypeLiquidity, true}, // still disabled
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

	t.Run("Enable swaps", func(t *testing.T) {
		err := EnableSwapsForTestnet()
		uassert.NoError(t, err)

		tests := []haltTestCases{
			{phalt.OpTypeSwap, false},     // now enabled
			{phalt.OpTypeWithdraw, false}, // now enabled
			{phalt.OpTypeLiquidity, true}, // still disabled
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

	t.Run("Enable liquidity", func(t *testing.T) {
		err := EnableLiquidityForTestnet()
		uassert.NoError(t, err)

		tests := []haltTestCases{
			{phalt.OpTypeLiquidity, false},  // now enabled
			{phalt.OpTypeSwap, false},       // now enabled
			{phalt.OpTypeWithdraw, false},   // now enabled
			{phalt.OpTypeGovernance, false}, // now enabled
		}

		for _, tt := range tests {
			err := IsHalted(tt.opType)
			if tt.wantError {
				uassert.Error(t, err)
				return
			}
			uassert.NoError(t, err)
		}

		// Despite all operations being enabled, we're still in MainnetSafeMode
		// So `GetHalt()` should still return true.
		uassert.True(t, GetHalt())
	})

	t.Run("Move to NoHalt after testing", func(t *testing.T) {
		// Finally transition to NoHalt
		err := SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.NoError(t, err)

		// Now GetHalt() should return false
		uassert.False(t, GetHalt())

		if GetCurrentHaltLevel() != phalt.LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), phalt.LvNoHalt)
		}
	})
}

func TestMultipleOperationHalts(t *testing.T) {
	// Setup test with admin privileges
	std.TestSetRealm(adminRealm)

	// First set to MainnetSafeMode
	err := SetHaltLevelByAdmin(LvMainnetSafeMode)
	uassert.NoError(t, err)

	t.Run("Check multiple operations in MainnetSafeMode", func(t *testing.T) {
		// Only Withdraw is enabled in MainnetSafeMode, so this should fail
		err := IsHalted(OpTypeWithdraw, OpTypeSwap)
		uassert.Error(t, err)

		// Both operations are disabled in MainnetSafeMode
		err = IsHalted(OpTypeSwap, OpTypeLiquidity)
		uassert.NoError(t, err)
	})

	t.Run("Check multiple operations after enabling some", func(t *testing.T) {
		// Enable withdrawals and swaps
		err := EnableWithdrawalsForTestnet()
		uassert.NoError(t, err)
		err = EnableSwapsForTestnet()
		uassert.NoError(t, err)

		// Now both Withdraw and Swap should be enabled
		err = IsHalted(OpTypeWithdraw, OpTypeSwap)
		uassert.NoError(t, err)

		err = IsHalted(OpTypeWithdraw, OpTypeSwap, OpTypeLiquidity)
		uassert.NoError(t, err)
	})

	t.Run("Check all operations after enabling everything", func(t *testing.T) {
		// Enable all operations
		err := EnableLiquidityForTestnet()
		uassert.NoError(t, err)

		// Now all operations should be enabled
		err = IsHalted(OpTypeWithdraw, OpTypeSwap, OpTypeLiquidity)
		uassert.NoError(t, err)
	})
}

func TestCustomOperationHalts(t *testing.T) {
	// Setup test with admin privileges
	std.TestSetRealm(adminRealm)

	// Define custom operation types for testing
	customOp1 := phalt.OpType("CUSTOM_OP_1")
	customOp2 := phalt.OpType("CUSTOM_OP_2")
	invalidOp := phalt.OpType("INVALID_OP")

	t.Run("Check undefined custom operations", func(t *testing.T) {
		// Set to NoHalt first
		err := SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.NoError(t, err)

		// Even in NoHalt, undefined operations should be considered halted
		err = IsHalted(customOp1)
		uassert.Error(t, err)

		// Multiple operations including undefined ones
		err = IsHalted(OpTypeWithdraw, customOp1, OpTypeSwap)
		uassert.Error(t, err)
	})

	t.Run("Check multiple custom operations", func(t *testing.T) {
		// Test with multiple custom operations
		err := IsHalted(customOp1, customOp2, invalidOp)
		uassert.Error(t, err)

		// Mix of valid and custom operations
		err = IsHalted(OpTypeWithdraw, customOp1, OpTypeSwap, customOp2)
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
	std.TestSetRealm(adminRealm)

	t.Run("EnableOperations in non-MainnetSafeMode", func(t *testing.T) {
		// First set to NoHalt
		err := SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.NoError(t, err)

		// Try to enable operations in NoHalt mode - should return nil without changing state
		err = EnableWithdrawalsForTestnet()
		uassert.NoError(t, err)

		err = EnableSwapsForTestnet()
		uassert.NoError(t, err, "EnableSwapsForTestnet should not change state in NoHalt")

		err = EnableLiquidityForTestnet()
		uassert.NoError(t, err, "should not change state in NoHalt")

		// Verify operations maintain their NoHalt state
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err, "should not change state in NoHalt")

		err = IsHalted(OpTypeSwap)
		uassert.NoError(t, err, "should not change state in NoHalt")

		err = IsHalted(OpTypeLiquidity)
		uassert.NoError(t, err, "should not change state in NoHalt")
	})

	t.Run("Operation state transitions during halt level changes", func(t *testing.T) {
		// Set to MainnetSafeMode
		err := SetHaltLevelByAdmin(LvMainnetSafeMode)
		uassert.NoError(t, err)

		// Enable all operations in MainnetSafeMode
		err = EnableWithdrawalsForTestnet()
		uassert.NoError(t, err)
		err = EnableSwapsForTestnet()
		uassert.NoError(t, err)
		err = EnableLiquidityForTestnet()
		uassert.NoError(t, err)

		// Change to EmergencyHalt - should override previous settings
		err = SetHaltLevelByAdmin(phalt.LvEmergencyHalt)
		uassert.NoError(t, err)

		// In EmergencyHalt, only withdrawals should be allowed
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)

		err = IsHalted(OpTypeSwap)
		uassert.Error(t, err)

		err = IsHalted(OpTypeLiquidity)
		uassert.Error(t, err)

		// // Change back to MainnetSafeMode
		err = SetHaltLevelByAdmin(LvMainnetSafeMode)
		uassert.NoError(t, err)

		// Check if operations return to their MainnetSafeMode defaults
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
	})

	t.Run("Operation dependencies in MainnetSafeMode", func(t *testing.T) {
		// Set to MainnetSafeMode
		err := SetHaltLevelByAdmin(LvMainnetSafeMode)
		uassert.NoError(t, err)

		// Try to enable liquidity before enabling swaps
		err = EnableLiquidityForTestnet()
		uassert.NoError(t, err)

		// Enable swaps and verify all states
		err = EnableSwapsForTestnet()
		uassert.NoError(t, err)

		// Check final states of all operations
		operations := []struct {
			opType    phalt.OpType
			wantError bool
		}{
			{OpTypeWithdraw, false},
			{OpTypeSwap, false},
			{OpTypeLiquidity, false},
			{OpTypeGovernance, true},
		}

		for _, op := range operations {
			err := IsHalted(op.opType)
			if op.wantError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		}
	})

	t.Run("Operation status after complete cycle", func(t *testing.T) {
		// Start with MainnetSafeMode
		err := SetHaltLevelByAdmin(LvMainnetSafeMode)
		uassert.NoError(t, err)

		// Go through complete cycle of modes
		modes := []phalt.LevelID{
			phalt.LvNoHalt,
			phalt.LvSwapHalt,
			phalt.LvEmergencyHalt,
			phalt.LvCompleteHalt,
			LvMainnetSafeMode,
		}

		for _, mode := range modes {
			err = SetHaltLevelByAdmin(mode)
			uassert.NoError(t, err)

			// Verify expected operation states for each mode
			switch mode {
			case phalt.LvNoHalt:
				err = IsHalted(OpTypeWithdraw, OpTypeSwap, OpTypeLiquidity)
				uassert.NoError(t, err)
			case phalt.LvSwapHalt:
				err = IsHalted(OpTypeSwap)
				uassert.Error(t, err)
				err = IsHalted(OpTypeWithdraw)
				uassert.NoError(t, err)
			case phalt.LvEmergencyHalt:
				err = IsHalted(OpTypeWithdraw)
				uassert.NoError(t, err)
				err = IsHalted(OpTypeSwap, OpTypeLiquidity)
				uassert.Error(t, err)
			case phalt.LvCompleteHalt:
				err = IsHalted(OpTypeWithdraw, OpTypeSwap, OpTypeLiquidity)
				uassert.Error(t, err)
			case LvMainnetSafeMode:
				err = IsHalted(OpTypeWithdraw)
				uassert.NoError(t, err)
			}
		}
	})
}

func TestModeTransitions(t *testing.T) {
	std.TestSetRealm(adminRealm)

	t.Run("MainnetSafeMode to NoHalt transition", func(t *testing.T) {
		// Set initial state to MainnetSafeMode
		err := SetHaltLevelByAdmin(LvMainnetSafeMode)
		uassert.NoError(t, err)

		// Enable all operations in MainnetSafeMode
		err = EnableWithdrawalsForTestnet()
		uassert.NoError(t, err)
		err = EnableSwapsForTestnet()
		uassert.NoError(t, err)
		err = EnableLiquidityForTestnet()
		uassert.NoError(t, err)

		// Verify current state in MainnetSafeMode
		initialState := map[phalt.OpType]bool{
			OpTypeWithdraw:   true,
			OpTypeSwap:       true,
			OpTypeLiquidity:  true,
			OpTypeGovernance: false,
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
		err = SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.NoError(t, err)
		uassert.False(t, GetHalt())
		currentHaltLevel := GetCurrentHaltLevel()
		if currentHaltLevel != phalt.LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", currentHaltLevel, phalt.LvNoHalt)
		}

		// All operations should be enabled in NoHalt
		err = IsHalted(OpTypeWithdraw, OpTypeSwap, OpTypeLiquidity, OpTypeGovernance)
		uassert.NoError(t, err)
	})

	t.Run("Emergency Mode transitions", func(t *testing.T) {
		// default state: NoHalt
		err := SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.NoError(t, err)

		// NoHalt -> EmergencyHalt
		err = SetHaltLevelByAdmin(phalt.LvEmergencyHalt)
		uassert.NoError(t, err)

		// only withdrawals should be allowed
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
		err = IsHalted(OpTypeSwap, OpTypeLiquidity)
		uassert.Error(t, err)

		// EmergencyHalt -> CompleteHalt
		err = SetHaltLevelByAdmin(phalt.LvCompleteHalt)
		uassert.NoError(t, err)

		// all operations should be halted
		err = IsHalted(OpTypeWithdraw, OpTypeSwap, OpTypeLiquidity)
		uassert.Error(t, err)
	})

	t.Run("Mode transition ordering", func(t *testing.T) {
		// Define transition sequence
		transitions := []struct {
			mode         phalt.LevelID
			enabledOps   []phalt.OpType
			disabledOps  []phalt.OpType
			expectHalted bool
		}{
			{
				mode:         phalt.LvNoHalt,
				enabledOps:   []phalt.OpType{OpTypeWithdraw, OpTypeSwap, OpTypeLiquidity},
				disabledOps:  []phalt.OpType{},
				expectHalted: false,
			},
			{
				mode:         phalt.LvSwapHalt,
				enabledOps:   []phalt.OpType{OpTypeWithdraw, OpTypeLiquidity},
				disabledOps:  []phalt.OpType{OpTypeSwap},
				expectHalted: false,
			},
			{
				mode:         phalt.LvEmergencyHalt,
				enabledOps:   []phalt.OpType{OpTypeWithdraw},
				disabledOps:  []phalt.OpType{OpTypeSwap, OpTypeLiquidity},
				expectHalted: false,
			},
			{
				mode:         phalt.LvCompleteHalt,
				enabledOps:   []phalt.OpType{},
				disabledOps:  []phalt.OpType{OpTypeWithdraw, OpTypeSwap, OpTypeLiquidity},
				expectHalted: true,
			},
			{
				mode:         LvMainnetSafeMode,
				enabledOps:   []phalt.OpType{OpTypeWithdraw},
				disabledOps:  []phalt.OpType{},
				expectHalted: true,
			},
		}

		for _, transition := range transitions {
			err := SetHaltLevelByAdmin(transition.mode)
			uassert.NoError(t, err)

			uassert.Equal(t, transition.expectHalted, GetHalt())

			for _, op := range transition.enabledOps {
				err = IsHalted(op)
				uassert.NoError(t, err)
			}

			for _, op := range transition.disabledOps {
				err = IsHalted(op)
				uassert.Error(t, err)
			}
		}
	})

	t.Run("Mode transition edge cases", func(t *testing.T) {
		// transition to same mode
		err := SetHaltLevelByAdmin(LvMainnetSafeMode)
		uassert.NoError(t, err)
		err = SetHaltLevelByAdmin(LvMainnetSafeMode)
		uassert.NoError(t, err)

		// rapid mode transitions
		modes := []phalt.LevelID{
			phalt.LvNoHalt,
			LvMainnetSafeMode,
			phalt.LvEmergencyHalt,
			phalt.LvCompleteHalt,
			phalt.LvNoHalt,
		}

		for _, mode := range modes {
			err = SetHaltLevelByAdmin(mode)
			uassert.NoError(t, err)
			if mode != GetCurrentHaltLevel() {
				t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), mode)
			}
		}

		// operation status preservation after mode cycle
		err = SetHaltLevelByAdmin(LvMainnetSafeMode)
		uassert.NoError(t, err)

		// enable all operations
		err = EnableWithdrawalsForTestnet()
		uassert.NoError(t, err)
		err = EnableSwapsForTestnet()
		uassert.NoError(t, err)
		err = EnableLiquidityForTestnet()
		uassert.NoError(t, err)

		// cycle through modes and back
		err = SetHaltLevelByAdmin(phalt.LvEmergencyHalt)
		uassert.NoError(t, err)
		err = SetHaltLevelByAdmin(LvMainnetSafeMode)
		uassert.NoError(t, err)

		// check operation states are reset to MainnetSafeMode defaults
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
	})
}

func TestHaltErrorHandling(t *testing.T) {
	t.Run("Permission error handling", func(t *testing.T) {
		// Test with non-admin/non-governance realm
		std.TestSetRealm(userRealm)

		// Try to set halt level
		err := SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.Error(t, err)
		if !strings.Contains(err.Error(), "only admin") {
			t.Errorf("Error message should mention admin permission requirement")
		}

		// Try to set operation status
		err = SetOperationStatus(OpTypeSwap, true)
		uassert.Error(t, err)
		if !strings.Contains(err.Error(), "only governance") {
			t.Errorf("Error message should mention governance permission requirement")
		}

		// Verify state remains unchanged after failed attempts
		std.TestSetRealm(adminRealm)
		currentLevel := GetCurrentHaltLevel()
		if currentLevel == phalt.LvNoHalt {
			t.Errorf("Halt level should not have changed after failed attempt")
		}
	})

	t.Run("Error handling in EnableForTestnet functions", func(t *testing.T) {
		// Set to NoHalt first
		std.TestSetRealm(adminRealm)
		err := SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.NoError(t, err)

		// Try EnableForTestnet functions in wrong mode
		err = EnableWithdrawalsForTestnet()
		uassert.NoError(t, err) // Should return nil without effect

		err = EnableSwapsForTestnet()
		uassert.NoError(t, err) // Should return nil without effect

		err = EnableLiquidityForTestnet()
		uassert.NoError(t, err) // Should return nil without effect

		// Switch to MainnetSafeMode
		err = SetHaltLevelByAdmin(LvMainnetSafeMode)
		uassert.NoError(t, err)

		// Try with non-admin privileges
		std.TestSetRealm(userRealm)

		err = EnableWithdrawalsForTestnet()
		uassert.Error(t, err)
		if !strings.Contains(err.Error(), "only admin") {
			t.Errorf("Error message should mention admin permission requirement")
		}

		err = EnableSwapsForTestnet()
		uassert.Error(t, err)
		if !strings.Contains(err.Error(), "only admin") {
			t.Errorf("Error message should mention admin permission requirement")
		}

		err = EnableLiquidityForTestnet()
		uassert.Error(t, err)
		if !strings.Contains(err.Error(), "only admin") {
			t.Errorf("Error message should mention admin permission requirement")
		}
	})
}

func TestContractSpecificHalt(t *testing.T) {
	// Setup test with admin privileges
	std.TestSetRealm(adminRealm)

	t.Run("Initial ContractSafeMode state", func(t *testing.T) {
		err := SetHaltLevelByAdmin(LvContractSafeMode)
		uassert.NoError(t, err, "ContractSafeMode should be set")

		// all contracts are initially enabled
		contracts := []phalt.OpType{
			OpTypePool,
			OpTypePosition,
			OpTypeProtocolFee,
			OpTypeRouter,
			OpTypeStaker,
			OpTypeLaunchpad,
			OpTypeGovernance,
		}

		for _, contract := range contracts {
			err = IsContractHalted(contract)
			uassert.NoError(t, err)
		}

		// all global operations are enabled
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
		err = IsHalted(OpTypeDeposit)
		uassert.NoError(t, err)
		err = IsHalted(OpTypeSwap)
		uassert.NoError(t, err)
		err = IsHalted(OpTypeLiquidity)
		uassert.NoError(t, err)
	})

	t.Run("Enable/Disable individual contracts", func(t *testing.T) {
		err := EnableContractOperations(OpTypePool)
		uassert.NoError(t, err)

		err = IsContractHalted(OpTypePool)
		uassert.NoError(t, err, "Contract pool should be enabled")

		err = DisableContractOperations(OpTypePool)
		uassert.NoError(t, err)

		err = IsContractHalted(OpTypePool)
		uassert.Error(t, err, "Contract pool should be disabled")
	})

	t.Run("Contract operation permission check", func(t *testing.T) {
		// non-admin realm
		std.TestSetRealm(userRealm)

		// enable/disable are not allowed for non-admin realm
		err := EnableContractOperations(OpTypePool)
		uassert.Error(t, err)
		if !strings.Contains(err.Error(), "only admin") {
			t.Errorf("Error should mention admin permission requirement")
		}

		err = DisableContractOperations(OpTypePool)
		uassert.Error(t, err)
		if !strings.Contains(err.Error(), "only admin") {
			t.Errorf("Error should mention admin permission requirement")
		}
	})

	t.Run("Enable all contracts progressively", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		contracts := []phalt.OpType{
			OpTypePool,
			OpTypePosition,
			OpTypeProtocolFee,
			OpTypeRouter,
			OpTypeStaker,
			OpTypeLaunchpad,
		}

		for _, contract := range contracts {
			err := EnableContractOperations(contract)
			uassert.NoError(t, err)

			err = IsContractHalted(contract)
			uassert.NoError(t, err)

			err = IsHalted(OpTypeWithdraw)
			uassert.NoError(t, err)
		}
	})

	t.Run("Contract status query", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		err := EnableContractOperations(OpTypePool)
		uassert.NoError(t, err)

		status := GetContractStatus(OpTypePool)
		uassert.True(t, status)

		err = DisableContractOperations(OpTypePool)
		uassert.NoError(t, err)

		status = GetContractStatus(OpTypePool)
		uassert.False(t, status)
	})
}
