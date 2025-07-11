package halt

import (
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
)

// Helper function to reset halt manager to initial state
func resetToMainnetSafeMode() {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	adminRealm := std.NewUserRealm(adminAddr)
	testing.SetRealm(adminRealm)

	// Re-create the MainnetSafeMode level with original settings
	operations := make(map[OpType]bool)
	operations[OpTypePool] = true
	operations[OpTypePosition] = true
	operations[OpTypeProtocolFee] = true
	operations[OpTypeRouter] = true
	operations[OpTypeStaker] = true
	operations[OpTypeLaunchpad] = true
	operations[OpTypeGovernance] = true
	operations[OpTypeGovStaker] = true
	operations[OpTypeXGns] = true
	operations[OpTypeEmission] = true
	operations[OpTypeWithdraw] = false // disabled in MainnetSafeMode

	mainnetSafeMode := NewHaltLevel(
		LvMainnetSafeMode,
		"MainnetSafeMode",
		"Safe mode for post-mainnet (no withdrawals)",
		operations,
	)

	// Get the halt manager and re-register the level
	mgr := GetHaltManager()
	mgr.RegisterHaltLevel(mainnetSafeMode)

	// Set the level
	SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
}

// Test halt module functions that require specific caller permissions
func TestHaltPermissions(t *testing.T) {
	// Reset state when test completes
	defer resetToMainnetSafeMode()

	var (
		adminAddr, _      = access.GetAddress(access.ROLE_ADMIN)
		adminRealm        = std.NewUserRealm(adminAddr)
		govRealm          = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
		unauthorizedRealm = std.NewCodeRealm("gno.land/r/demo/unauthorized")
	)

	tests := []struct {
		name   string
		testFn func(t *testing.T)
	}{
		{
			name: "IsHalted with no parameters checks complete halt",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to CompleteHalt
				err := SetHaltLevelByAdmin(cross, LvCompleteHalt)
				uassert.NoError(t, err)

				// IsHalted() with no params should return error for complete halt
				err = IsHalted()
				uassert.Error(t, err)

				// Set to NoHalt
				err = SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)

				// IsHalted() with no params should return nil for no halt
				err = IsHalted()
				uassert.NoError(t, err)
			},
		},
		{
			name: "IsHalted with multiple operation types",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Save original state
				originalLevel := GetCurrentHaltLevel()
				defer func() {
					// Restore original state
					SetHaltLevelByAdmin(cross, originalLevel)
				}()

				// Set to EmergencyHalt
				err := SetHaltLevelByAdmin(cross, LvEmergencyHalt)
				uassert.NoError(t, err)

				// Mix of allowed and disallowed operations
				err = IsHalted(OpTypeWithdraw, OpTypePool)
				uassert.Error(t, err) // Pool is not allowed in EmergencyHalt

				// Only allowed operations
				err = IsHalted(OpTypeWithdraw, OpTypeGovernance)
				uassert.NoError(t, err)

				// Only disallowed operations
				err = IsHalted(OpTypePool, OpTypePosition)
				uassert.Error(t, err)
			},
		},
		{
			name: "SetHaltByAdmin with unauthorized caller",
			testFn: func(t *testing.T) {
				testing.SetRealm(unauthorizedRealm)

				err := SetHaltByAdmin(cross, true)
				uassert.Error(t, err)
				uassert.True(t, strings.Contains(err.Error(), "only admin can set halt"))
			},
		},
		{
			name: "SetHaltByAdmin with admin privileges",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Test halting
				err := SetHaltByAdmin(cross, true)
				uassert.NoError(t, err)
				uassert.True(t, GetCurrentHaltLevel() == LvCompleteHalt)

				// Test unhalting
				err = SetHaltByAdmin(cross, false)
				uassert.NoError(t, err)
				uassert.True(t, GetCurrentHaltLevel() == LvNoHalt)
			},
		},
		{
			name: "SetHalt with admin and governance",
			testFn: func(t *testing.T) {
				// Save original state
				originalLevel := GetCurrentHaltLevel()
				defer func() {
					// Restore original state
					testing.SetRealm(adminRealm)
					SetHaltLevelByAdmin(cross, originalLevel)
				}()

				// Test with admin
				testing.SetRealm(adminRealm)
				err := SetHalt(cross, true, LvEmergencyHalt)
				uassert.NoError(t, err)
				uassert.True(t, GetCurrentHaltLevel() == LvEmergencyHalt)

				// Test with governance
				testing.SetRealm(govRealm)
				err = SetHalt(cross, false)
				uassert.NoError(t, err)
				uassert.True(t, GetCurrentHaltLevel() == LvNoHalt)

				// Test with unauthorized
				testing.SetRealm(unauthorizedRealm)
				err = SetHalt(cross, true)
				uassert.Error(t, err)
				uassert.True(t, strings.Contains(err.Error(), "only admin or governance can set halt"))
			},
		},
		{
			name: "SetHalt with invalid levels",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Try to set invalid levels
				invalidLevels := []LevelID{LvContractHalt, LvMainnetSafeMode, LevelID(99)}

				for _, level := range invalidLevels {
					err := SetHalt(cross, true, level)
					uassert.Error(t, err)
					uassert.True(t, strings.Contains(err.Error(), "only NoHalt, EmergencyHalt and CompleteHalt levels are allowed"))
				}
			},
		},
		{
			name: "SetHaltLevel permissions",
			testFn: func(t *testing.T) {
				// Save original state
				originalLevel := GetCurrentHaltLevel()
				defer func() {
					// Restore original state
					testing.SetRealm(adminRealm)
					SetHaltLevelByAdmin(cross, originalLevel)
				}()

				// Test with admin
				testing.SetRealm(adminRealm)
				err := SetHaltLevel(cross, LvEmergencyHalt)
				uassert.NoError(t, err)

				// Test with governance
				testing.SetRealm(govRealm)
				err = SetHaltLevel(cross, LvCompleteHalt)
				uassert.NoError(t, err)

				// Test with unauthorized
				testing.SetRealm(unauthorizedRealm)
				err = SetHaltLevel(cross, LvNoHalt)
				uassert.Error(t, err)
				uassert.True(t, strings.Contains(err.Error(), "only admin or governance can set halt level"))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.testFn(t)
		})
	}
}

func TestHaltOperationStatus(t *testing.T) {
	var (
		adminAddr, _      = access.GetAddress(access.ROLE_ADMIN)
		adminRealm        = std.NewUserRealm(adminAddr)
		govRealm          = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
		unauthorizedRealm = std.NewCodeRealm("gno.land/r/demo/unauthorized")
	)

	tests := []struct {
		name   string
		testFn func(t *testing.T)
	}{
		{
			name: "SetOperationStatus by governance",
			testFn: func(t *testing.T) {
				testing.SetRealm(govRealm)

				// Set to NoHalt first
				testing.SetRealm(adminRealm)
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)

				// Test governance setting operation status
				testing.SetRealm(govRealm)
				err = SetOperationStatus(cross, OpTypePool, false)
				uassert.NoError(t, err)

				// Verify operation is disabled
				err = IsHalted(OpTypePool)
				uassert.Error(t, err)

				// Re-enable
				err = SetOperationStatus(cross, OpTypePool, true)
				uassert.NoError(t, err)

				// Verify operation is enabled
				err = IsHalted(OpTypePool)
				uassert.NoError(t, err)
			},
		},
		{
			name: "SetOperationStatus by unauthorized caller",
			testFn: func(t *testing.T) {
				testing.SetRealm(unauthorizedRealm)

				err := SetOperationStatus(cross, OpTypePool, false)
				uassert.Error(t, err)
				uassert.True(t, strings.Contains(err.Error(), "only governance"))
				uassert.True(t, strings.Contains(err.Error(), "can set operation status"))
			},
		},
		{
			name: "SetOperationStatusByAdmin",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to NoHalt first
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)

				// Test admin setting operation status
				err = SetOperationStatusByAdmin(cross, OpTypePosition, false)
				uassert.NoError(t, err)

				// Verify operation is disabled
				err = IsHalted(OpTypePosition)
				uassert.Error(t, err)

				// Re-enable
				err = SetOperationStatusByAdmin(cross, OpTypePosition, true)
				uassert.NoError(t, err)

				// Verify operation is enabled
				err = IsHalted(OpTypePosition)
				uassert.NoError(t, err)
			},
		},
		{
			name: "SetOperationStatusByAdmin unauthorized",
			testFn: func(t *testing.T) {
				testing.SetRealm(unauthorizedRealm)

				err := SetOperationStatusByAdmin(cross, OpTypePool, false)
				uassert.Error(t, err)
				uassert.True(t, strings.Contains(err.Error(), "only admin can set operation status"))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.testFn(t)
		})
	}
}

func TestHaltSpecialFunctions(t *testing.T) {
	// Reset state when test completes
	defer resetToMainnetSafeMode()

	var (
		adminAddr, _      = access.GetAddress(access.ROLE_ADMIN)
		adminRealm        = std.NewUserRealm(adminAddr)
		unauthorizedRealm = std.NewCodeRealm("gno.land/r/demo/unauthorized")
	)

	tests := []struct {
		name   string
		testFn func(t *testing.T)
	}{
		{
			name: "EnableWithdrawalsForTestnet",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to MainnetSafeMode first
				err := SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
				uassert.NoError(t, err)

				// Verify withdrawals are initially disabled
				err = IsHalted(OpTypeWithdraw)
				uassert.Error(t, err)

				// Enable withdrawals
				err = EnableWithdrawalsForTestnet(cross)
				uassert.NoError(t, err)

				// Verify withdrawals are now enabled
				err = IsHalted(OpTypeWithdraw)
				uassert.NoError(t, err)
			},
		},
		{
			name: "EnableWithdrawalsForTestnet not in MainnetSafeMode",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to NoHalt
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)

				// Should return nil without error
				err = EnableWithdrawalsForTestnet(cross)
				uassert.NoError(t, err)
			},
		},
		{
			name: "EnableWithdrawalsForTestnet unauthorized",
			testFn: func(t *testing.T) {
				testing.SetRealm(unauthorizedRealm)

				err := EnableWithdrawalsForTestnet(cross)
				uassert.Error(t, err)
				uassert.True(t, strings.Contains(err.Error(), "only admin can enable withdrawals"))
			},
		},
		{
			name: "EnableContractOperations",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to ContractHalt first
				err := SetHaltLevelByAdmin(cross, LvContractHalt)
				uassert.NoError(t, err)

				// Enable specific contract
				err = EnableContractOperations(cross, OpTypePool)
				uassert.NoError(t, err)

				// Verify operation is enabled
				err = IsHalted(OpTypePool)
				uassert.NoError(t, err)
			},
		},
		{
			name: "EnableContractOperations not in ContractHalt",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to NoHalt
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)

				// Should return nil without error
				err = EnableContractOperations(cross, OpTypePool)
				uassert.NoError(t, err)
			},
		},
		{
			name: "DisableContractOperations",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to NoHalt first
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)

				// Disable specific contract
				err = DisableContractOperations(cross, OpTypeRouter)
				uassert.NoError(t, err)

				// Verify operation is disabled
				err = IsHalted(OpTypeRouter)
				uassert.Error(t, err)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.testFn(t)
		})
	}
}

func TestHaltStatusFunctions(t *testing.T) {
	var (
		adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
		adminRealm   = std.NewUserRealm(adminAddr)
	)

	tests := []struct {
		name   string
		testFn func(t *testing.T)
	}{
		{
			name: "GetHaltManager",
			testFn: func(t *testing.T) {
				mgr := GetHaltManager()
				uassert.NotEqual(t, nil, mgr)

				// Should be the same instance as the global manager
				mgr2 := GetHaltManager()
				uassert.True(t, mgr == mgr2)
			},
		},
		{
			name: "GetCurrentHaltLevel",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Test different levels
				levels := []LevelID{LvNoHalt, LvEmergencyHalt, LvCompleteHalt}

				for _, level := range levels {
					err := SetHaltLevelByAdmin(cross, level)
					uassert.NoError(t, err)
					uassert.True(t, GetCurrentHaltLevel() == level)
				}
			},
		},
		{
			name: "IsContractHalted",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to NoHalt - contracts should not be halted
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)
				uassert.False(t, IsContractHalted(OpTypePool))

				// Set to EmergencyHalt - pool should be halted
				err = SetHaltLevelByAdmin(cross, LvEmergencyHalt)
				uassert.NoError(t, err)
				uassert.True(t, IsContractHalted(OpTypePool))
				uassert.False(t, IsContractHalted(OpTypeWithdraw))
			},
		},
		{
			name: "GetContractStatus",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to NoHalt
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)

				// All operations should be allowed
				uassert.True(t, GetContractStatus(OpTypePool))
				uassert.True(t, GetContractStatus(OpTypeWithdraw))

				// Set to EmergencyHalt
				err = SetHaltLevelByAdmin(cross, LvEmergencyHalt)
				uassert.NoError(t, err)

				// Only withdrawals and governance should be allowed
				uassert.False(t, GetContractStatus(OpTypePool))
				uassert.True(t, GetContractStatus(OpTypeWithdraw))
				uassert.True(t, GetContractStatus(OpTypeGovernance))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.testFn(t)
		})
	}
}

func TestHaltErrorMessages(t *testing.T) {
	var (
		adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
		adminRealm   = std.NewUserRealm(adminAddr)
	)

	tests := []struct {
		name   string
		testFn func(t *testing.T)
	}{
		{
			name: "IsHalted error message contains operation name",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to EmergencyHalt
				err := SetHaltLevelByAdmin(cross, LvEmergencyHalt)
				uassert.NoError(t, err)

				// Check error message for halted operation
				err = IsHalted(OpTypePool)
				uassert.Error(t, err)
				uassert.True(t, strings.Contains(err.Error(), string(OpTypePool)))
				uassert.True(t, strings.Contains(err.Error(), "currently disabled"))
			},
		},
		{
			name: "IsHalted with multiple operations shows first halted",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// Set to EmergencyHalt
				err := SetHaltLevelByAdmin(cross, LvEmergencyHalt)
				uassert.NoError(t, err)

				// Check with multiple operations where first is halted
				err = IsHalted(OpTypePool, OpTypeWithdraw)
				uassert.Error(t, err)
				uassert.True(t, strings.Contains(err.Error(), string(OpTypePool)))
			},
		},
		{
			name: "setHaltLevel error on invalid level",
			testFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)

				// This would normally not be accessible, but we can test the manager directly
				mgr := GetHaltManager()
				err := mgr.SetCurrentLevel(LevelID(127)) // Use a valid but high level ID
				uassert.Error(t, err)
				uassert.True(t, strings.Contains(err.Error(), "invalid halt level"))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.testFn(t)
		})
	}
}

func TestHaltInitialization(t *testing.T) {
	// Reset state to ensure consistent starting point
	resetToMainnetSafeMode()

	tests := []struct {
		name   string
		testFn func(t *testing.T)
	}{
		{
			name: "initial state should be MainnetSafeMode",
			testFn: func(t *testing.T) {
				// The module should initialize to MainnetSafeMode
				currentLevel := GetCurrentHaltLevel()
				uassert.True(t, currentLevel == LvMainnetSafeMode)
			},
		},
		{
			name: "MainnetSafeMode should disable withdrawals",
			testFn: func(t *testing.T) {
				// Withdrawals should be disabled in MainnetSafeMode initially
				err := IsHalted(OpTypeWithdraw)
				uassert.Error(t, err)
			},
		},
		{
			name: "MainnetSafeMode should allow other operations",
			testFn: func(t *testing.T) {
				// Other operations should be allowed in MainnetSafeMode
				allowedOps := []OpType{
					OpTypePool,
					OpTypePosition,
					OpTypeProtocolFee,
					OpTypeRouter,
					OpTypeStaker,
					OpTypeLaunchpad,
					OpTypeGovernance,
					OpTypeGovStaker,
					OpTypeXGns,
					OpTypeEmission,
				}

				for _, op := range allowedOps {
					err := IsHalted(op)
					uassert.NoError(t, err)
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.testFn(t)
		})
	}
}
