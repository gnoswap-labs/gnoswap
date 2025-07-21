package halt

import (
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
)

func TestHaltExtended_HaltPermissions(t *testing.T) {
	tests := []struct {
		name                 string
		setupLevel           LevelID
		operationToTest      []OpType
		useAdminRealm        bool
		useGovRealm          bool
		useUnauthorizedRealm bool
		testAction           string
		expectedError        bool
		expectedPanicMessage string
	}{
		{
			name:            "IsHalted with no parameters checks complete halt - CompleteHalt should error",
			setupLevel:      LvCompleteHalt,
			operationToTest: []OpType{},
			useAdminRealm:   true,
			testAction:      "IsHalted",
			expectedError:   true,
		},
		{
			name:            "IsHalted with no parameters checks complete halt - NoHalt should not error",
			setupLevel:      LvNoHalt,
			operationToTest: []OpType{},
			useAdminRealm:   true,
			testAction:      "IsHalted",
			expectedError:   false,
		},
		{
			name:            "IsHalted with multiple operation types - EmergencyHalt mixed operations",
			setupLevel:      LvEmergencyHalt,
			operationToTest: []OpType{OpTypeWithdraw, OpTypePool},
			useAdminRealm:   true,
			testAction:      "IsHalted",
			expectedError:   true, // Pool is not allowed in EmergencyHalt
		},
		{
			name:            "IsHalted with multiple operation types - EmergencyHalt allowed operations",
			setupLevel:      LvEmergencyHalt,
			operationToTest: []OpType{OpTypeWithdraw, OpTypeGovernance},
			useAdminRealm:   true,
			testAction:      "IsHalted",
			expectedError:   false,
		},
		{
			name:                 "SetHaltByAdmin with unauthorized caller",
			setupLevel:           LvMainnetSafeMode,
			useUnauthorizedRealm: true,
			testAction:           "SetHaltByAdmin",
			expectedError:        true,
			expectedPanicMessage: "only admin can set halt",
		},
		{
			name:          "SetHaltByAdmin with admin privileges - halt true",
			setupLevel:    LvMainnetSafeMode,
			useAdminRealm: true,
			testAction:    "SetHaltByAdmin_true",
			expectedError: false,
		},
		{
			name:          "SetHaltByAdmin with admin privileges - halt false",
			setupLevel:    LvCompleteHalt,
			useAdminRealm: true,
			testAction:    "SetHaltByAdmin_false",
			expectedError: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedPanicMessage != "" {
						uassert.True(t, strings.Contains(r.(string), tc.expectedPanicMessage))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			resetToMainnetSafeMode()
			var err error
			
			if tc.useAdminRealm {
				adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
				testing.SetRealm(std.NewUserRealm(adminAddr))
				err = SetHaltLevelByAdmin(cross, tc.setupLevel)
				uassert.NoError(t, err)
			} else if tc.useGovRealm {
				govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
				testing.SetRealm(std.NewUserRealm(govAddr))
				err = SetHaltLevel(cross, tc.setupLevel)
				uassert.NoError(t, err)
			} else if tc.useUnauthorizedRealm {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/unauthorized"))
			}

			// when & then
			switch tc.testAction {
			case "IsHalted":
				err = IsHalted(tc.operationToTest...)
				if tc.expectedError {
					uassert.Error(t, err)
				} else {
					uassert.NoError(t, err)
				}
			case "SetHaltByAdmin":
				err = SetHaltByAdmin(cross, true)
				if tc.expectedError {
					uassert.Error(t, err)
					if tc.expectedPanicMessage != "" {
						uassert.True(t, strings.Contains(err.Error(), tc.expectedPanicMessage))
					}
				} else {
					uassert.NoError(t, err)
				}
			case "SetHaltByAdmin_true":
				err = SetHaltByAdmin(cross, true)
				if tc.expectedError {
					uassert.Error(t, err)
				} else {
					uassert.NoError(t, err)
					uassert.True(t, GetCurrentHaltLevel() == LvCompleteHalt)
				}
			case "SetHaltByAdmin_false":
				err = SetHaltByAdmin(cross, false)
				if tc.expectedError {
					uassert.Error(t, err)
				} else {
					uassert.NoError(t, err)
					uassert.True(t, GetCurrentHaltLevel() == LvNoHalt)
				}
			}
		})
	}
}

func TestHaltExtended_SetHaltFunctions(t *testing.T) {
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
			name: "SetHaltByAdmin with admin privileges",
			testFn: func(t *testing.T) {
				// Save original state
				originalLevel := GetCurrentHaltLevel()
				defer func() {
					// Restore original state
					testing.SetRealm(adminRealm)
					SetHaltLevelByAdmin(cross, originalLevel)
				}()

				testing.SetRealm(adminRealm)

				// Test halt true
				err := SetHaltByAdmin(cross, true)
				uassert.NoError(t, err)
				uassert.True(t, GetCurrentHaltLevel() == LvCompleteHalt)

				// Test halt false
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

func TestHaltExtended_OperationStatus(t *testing.T) {
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

func TestHaltExtended_SpecialFunctions(t *testing.T) {
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

func TestHaltExtended_StatusFunctions(t *testing.T) {
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

func TestHaltExtended_ErrorMessages(t *testing.T) {
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

func TestHaltExtended_Initialization(t *testing.T) {
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

// Helper function to reset state to MainnetSafeMode for consistent testing
func resetToMainnetSafeMode() {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	testing.SetRealm(std.NewUserRealm(adminAddr))
	SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
	
	// Reset withdraw status to disabled in MainnetSafeMode (in case it was enabled by tests)
	SetOperationStatusByAdmin(cross, OpTypeWithdraw, false)
}
