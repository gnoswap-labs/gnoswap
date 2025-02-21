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
		uassert.NoError(t, err)

		// Swaps should be disabled in MainnetSafeMode
		err = IsHalted(OpTypeSwap)
		uassert.Error(t, err)
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
		{phalt.OpTypeWithdraw, false},
		{phalt.OpTypeSwap, true},
		{phalt.OpTypeLiquidity, true},
		{phalt.OpTypeGovernance, true},
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
		uassert.Error(t, err)
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

		// But Liquidity is still disabled
		err = IsHalted(OpTypeWithdraw, OpTypeSwap, OpTypeLiquidity)
		uassert.Error(t, err)
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
