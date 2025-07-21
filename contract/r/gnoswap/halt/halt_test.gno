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
	tt := []struct {
		name         string
		setupFn      func()
		operations   []OpType
		expectedFail bool
	}{
		{
			name: "Operation specific checks in MainnetSafeMode",
			setupFn: func() {
				resetToMainnetSafeMode()
			},
			operations:   []OpType{OpTypeWithdraw},
			expectedFail: true,
		},
		{
			name: "Operation specific checks in EmergencyHalt",
			setupFn: func() {
				resetToMainnetSafeMode()
			},
			operations:   []OpType{OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter, OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance},
			expectedFail: false,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// Setup
			tc.setupFn()

			// When
			err := IsHalted(tc.operations...)

			// Then
			if tc.expectedFail {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestSetHaltLevelByAdminAndGovernance(t *testing.T) {
	tt := []struct {
		name          string
		setupFn       func()
		useAdminRealm bool
		useUserRealm  bool
		targetLevel   LevelID
		expectedFail  bool
	}{
		{
			name: "with non-admin or non-governance privilege, should fail",
			setupFn: func() {
				resetToMainnetSafeMode()
			},
			useUserRealm: true,
			targetLevel:  LvNoHalt,
			expectedFail: true,
		},
		{
			name: "with admin privilege, success",
			setupFn: func() {
				resetToMainnetSafeMode()
			},
			useAdminRealm: true,
			targetLevel:   LvNoHalt,
			expectedFail:  false,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// Setup
			tc.setupFn()

			// Set realm directly based on test case
			if tc.useAdminRealm {
				testing.SetRealm(adminRealm)
			} else if tc.useUserRealm {
				testing.SetRealm(userRealm)
			}

			// When
			err := SetHaltLevelByAdmin(cross, tc.targetLevel)

			// Then
			if tc.expectedFail {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				// Verify level change
				if tc.targetLevel == LvNoHalt {
					if GetCurrentHaltLevel() != LvNoHalt {
						t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
					}
				}
			}
		})
	}
}

func TestSetHalt(t *testing.T) {
	tt := []struct {
		name          string
		useAdminRealm bool
		useGovRealm   bool
		haltValue     bool
		expectedFail  bool
		verifyFn      func(t *testing.T)
	}{
		{
			name:          "with admin privilege, success",
			useAdminRealm: true,
			haltValue:     true,
			expectedFail:  false,
			verifyFn:      func(t *testing.T) {},
		},
		{
			name:         "with governance privilege, success",
			useGovRealm:  true,
			haltValue:    false,
			expectedFail: false,
			verifyFn: func(t *testing.T) {
				// Verify it changed to NoHalt
				if GetCurrentHaltLevel() != LvNoHalt {
					t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
				}
			},
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// Setup realm
			if tc.useAdminRealm {
				testing.SetRealm(adminRealm)
			} else if tc.useGovRealm {
				testing.SetRealm(govRealm)
			}

			// When
			err := SetHalt(cross, tc.haltValue)

			// Then
			if tc.expectedFail {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				tc.verifyFn(t)
			}
		})
	}
}

func TestSetHaltWithLevel(t *testing.T) {
	tt := []struct {
		name          string
		useAdminRealm bool
		useGovRealm   bool
		useUserRealm  bool
		haltValue     bool
		haltLevel     []LevelID
		expectedFail  bool
		verifyFn      func(t *testing.T)
	}{
		{
			name:         "with non-privileged user, should fail",
			useUserRealm: true,
			haltValue:    true,
			haltLevel:    []LevelID{LvEmergencyHalt},
			expectedFail: true,
			verifyFn:     func(t *testing.T) {},
		},
		{
			name:          "admin can set EmergencyHalt",
			useAdminRealm: true,
			haltValue:     true,
			haltLevel:     []LevelID{LvEmergencyHalt},
			expectedFail:  false,
			verifyFn: func(t *testing.T) {
				if GetCurrentHaltLevel() != LvEmergencyHalt {
					t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvEmergencyHalt)
				}
				// In EmergencyHalt, only withdrawals should be allowed
				uassert.NoError(t, IsHalted(OpTypeWithdraw))
				uassert.Error(t, IsHalted(OpTypePool))
			},
		},
		{
			name:          "admin can set CompleteHalt",
			useAdminRealm: true,
			haltValue:     true,
			haltLevel:     []LevelID{LvCompleteHalt},
			expectedFail:  false,
			verifyFn: func(t *testing.T) {
				if GetCurrentHaltLevel() != LvCompleteHalt {
					t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvCompleteHalt)
				}
				// In CompleteHalt, all operations should be halted
				uassert.NoError(t, IsHalted(OpTypeWithdraw))
				uassert.Error(t, IsHalted(OpTypePool))
			},
		},
		{
			name:         "governance can set EmergencyHalt",
			useGovRealm:  true,
			haltValue:    true,
			haltLevel:    []LevelID{LvEmergencyHalt},
			expectedFail: false,
			verifyFn: func(t *testing.T) {
				if GetCurrentHaltLevel() != LvEmergencyHalt {
					t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvEmergencyHalt)
				}
			},
		},
		{
			name:         "governance can set CompleteHalt",
			useGovRealm:  true,
			haltValue:    true,
			haltLevel:    []LevelID{LvCompleteHalt},
			expectedFail: false,
			verifyFn: func(t *testing.T) {
				if GetCurrentHaltLevel() != LvCompleteHalt {
					t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvCompleteHalt)
				}
			},
		},
		{
			name:          "invalid halt level ContractHalt should fail",
			useAdminRealm: true,
			haltValue:     true,
			haltLevel:     []LevelID{LvContractHalt},
			expectedFail:  true,
			verifyFn:      func(t *testing.T) {},
		},
		{
			name:          "invalid halt level MainnetSafeMode should fail",
			useAdminRealm: true,
			haltValue:     true,
			haltLevel:     []LevelID{LvMainnetSafeMode},
			expectedFail:  true,
			verifyFn:      func(t *testing.T) {},
		},
		{
			name:          "unhalt should always set to NoHalt",
			useAdminRealm: true,
			haltValue:     false,
			haltLevel:     []LevelID{},
			expectedFail:  false,
			verifyFn: func(t *testing.T) {
				if GetCurrentHaltLevel() != LvNoHalt {
					t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
				}
			},
		},
		{
			name:          "default halt level should be CompleteHalt",
			useAdminRealm: true,
			haltValue:     true,
			haltLevel:     []LevelID{},
			expectedFail:  false,
			verifyFn: func(t *testing.T) {
				if GetCurrentHaltLevel() != LvCompleteHalt {
					t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvCompleteHalt)
				}
			},
		},
		{
			name:          "explicit NoHalt setting should work",
			useAdminRealm: true,
			haltValue:     true,
			haltLevel:     []LevelID{LvNoHalt},
			expectedFail:  false,
			verifyFn: func(t *testing.T) {
				if GetCurrentHaltLevel() != LvNoHalt {
					t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
				}
			},
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// Setup realm
			if tc.useAdminRealm {
				testing.SetRealm(adminRealm)
			} else if tc.useGovRealm {
				testing.SetRealm(govRealm)
			} else if tc.useUserRealm {
				testing.SetRealm(userRealm)
			}

			// When
			var err error
			if len(tc.haltLevel) == 0 {
				err = SetHalt(cross, tc.haltValue)
			} else {
				err = SetHalt(cross, tc.haltValue, tc.haltLevel[0])
			}

			// Then
			if tc.expectedFail {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				tc.verifyFn(t)
			}
		})
	}
}

func TestEnableOperationsForTestnet(t *testing.T) {
	tt := []struct {
		name    string
		setupFn func()
		testFn  func(t *testing.T)
	}{
		{
			name: "Enable withdrawals in MainnetSafeMode",
			setupFn: func() {
				resetToMainnetSafeMode()
				testing.SetRealm(adminRealm)
				// Set to MainnetSafeMode
				err := SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
				uassert.NoError(t, err)
			},
			testFn: func(t *testing.T) {
				// Set admin realm for this test
				testing.SetRealm(adminRealm)

				// Initially withdrawals should be disabled
				err := IsHalted(OpTypeWithdraw)
				uassert.Error(t, err)

				// Enable withdrawals
				err = EnableWithdrawalsForTestnet(cross)
				uassert.NoError(t, err)

				// Now withdrawals should be enabled
				err = IsHalted(OpTypeWithdraw)
				uassert.NoError(t, err)

				// Contract operations should be enabled
				err = IsHalted(OpTypePool)
				uassert.NoError(t, err)
				err = IsHalted(OpTypePosition)
				uassert.NoError(t, err)
			},
		},
		{
			name: "Move to NoHalt after testing",
			setupFn: func() {
				resetToMainnetSafeMode()
				testing.SetRealm(adminRealm)
				// Set to MainnetSafeMode first
				err := SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
				uassert.NoError(t, err)
				// Enable withdrawals
				err = EnableWithdrawalsForTestnet(cross)
				uassert.NoError(t, err)
			},
			testFn: func(t *testing.T) {
				// Set admin realm for this test
				testing.SetRealm(adminRealm)

				// Transition to NoHalt
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)

				// GetHalt() should return false
				uassert.False(t, GetHalt())
				if GetCurrentHaltLevel() != LvNoHalt {
					t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
				}
			},
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// Setup
			tc.setupFn()

			// Test
			tc.testFn(t)
		})
	}
}

func TestCustomOperationHalts(t *testing.T) {
	customOp1 := OpType("CUSTOM_OP_1")
	customOp2 := OpType("CUSTOM_OP_2")

	tt := []struct {
		name         string
		setupFn      func()
		operations   []OpType
		expectedFail bool
		verifyFn     func(t *testing.T, err error)
	}{
		{
			name: "Check undefined custom operations",
			setupFn: func() {
				testing.SetRealm(adminRealm)
				// Set to NoHalt first
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)
			},
			operations:   []OpType{customOp1},
			expectedFail: true,
			verifyFn:     func(t *testing.T, err error) {},
		},
		{
			name: "Multiple operations including undefined ones",
			setupFn: func() {
				testing.SetRealm(adminRealm)
				// Set to NoHalt first
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)
			},
			operations:   []OpType{OpTypeWithdraw, customOp1},
			expectedFail: true,
			verifyFn:     func(t *testing.T, err error) {},
		},
		{
			name: "Check multiple custom operations",
			setupFn: func() {
				testing.SetRealm(adminRealm)
				// Set to NoHalt first
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)
			},
			operations:   []OpType{customOp1, customOp2},
			expectedFail: true,
			verifyFn:     func(t *testing.T, err error) {},
		},
		{
			name: "Mix of valid and custom operations",
			setupFn: func() {
				testing.SetRealm(adminRealm)
				// Set to NoHalt first
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)
			},
			operations:   []OpType{OpTypeWithdraw, customOp1, customOp2},
			expectedFail: true,
			verifyFn:     func(t *testing.T, err error) {},
		},
		{
			name: "Check operation type string representation",
			setupFn: func() {
				testing.SetRealm(adminRealm)
				// Set to NoHalt first
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)
			},
			operations:   []OpType{customOp1},
			expectedFail: true,
			verifyFn: func(t *testing.T, err error) {
				// Verify error message contains the custom operation name
				if !strings.Contains(err.Error(), string(customOp1)) {
					t.Fatalf("error message should contain operation name '%s', got: %s", customOp1, err.Error())
				}
			},
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// Setup
			tc.setupFn()

			// When
			err := IsHalted(tc.operations...)

			// Then
			if tc.expectedFail {
				uassert.Error(t, err)
				tc.verifyFn(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestOperationStatusEdgeCases(t *testing.T) {
	tt := []struct {
		name    string
		setupFn func()
		testFn  func(t *testing.T)
	}{
		{
			name: "EnableOperations in non-MainnetSafeMode",
			setupFn: func() {
				testing.SetRealm(adminRealm)
				// Set to NoHalt first
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)
			},
			testFn: func(t *testing.T) {
				// Set admin realm for this test
				testing.SetRealm(adminRealm)

				// Try to enable operations in NoHalt mode - should return nil without changing state
				err := EnableWithdrawalsForTestnet(cross)
				uassert.NoError(t, err)

				// Verify operations maintain their NoHalt state
				err = IsHalted(OpTypeWithdraw)
				uassert.NoError(t, err, "should not change state in NoHalt")
			},
		},
		{
			name: "Operation state transitions during halt level changes",
			setupFn: func() {
				testing.SetRealm(adminRealm)
				// Set to MainnetSafeMode
				err := SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
				uassert.NoError(t, err)
			},
			testFn: func(t *testing.T) {
				// Set admin realm for this test
				testing.SetRealm(adminRealm)

				// Enable all operations in MainnetSafeMode
				err := EnableWithdrawalsForTestnet(cross)
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
			},
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// Setup
			tc.setupFn()

			// Test
			tc.testFn(t)
		})
	}
}

func TestModeTransitions(t *testing.T) {
	tt := []struct {
		name    string
		setupFn func()
		testFn  func(t *testing.T)
	}{
		{
			name: "MainnetSafeMode to NoHalt transition",
			setupFn: func() {
				testing.SetRealm(adminRealm)
				// Set initial state to MainnetSafeMode
				err := SetHaltLevelByAdmin(cross, LvMainnetSafeMode)
				uassert.NoError(t, err)
			},
			testFn: func(t *testing.T) {
				// Set admin realm for this test
				testing.SetRealm(adminRealm)

				// Enable all operations in MainnetSafeMode
				err := EnableWithdrawalsForTestnet(cross)
				uassert.NoError(t, err)

				// Verify current state in MainnetSafeMode
				err = IsHalted(OpTypeWithdraw)
				uassert.NoError(t, err)
				err = IsHalted(OpTypeGovernance)
				uassert.NoError(t, err)

				// Transition to NoHalt
				err = SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)
				uassert.False(t, GetHalt())
				if GetCurrentHaltLevel() != LvNoHalt {
					t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvNoHalt)
				}

				// All operations should be enabled in NoHalt
				err = IsHalted(OpTypeWithdraw)
				uassert.NoError(t, err)
			},
		},
		{
			name: "Emergency Mode transitions",
			setupFn: func() {
				testing.SetRealm(adminRealm)
				// default state: NoHalt
				err := SetHaltLevelByAdmin(cross, LvNoHalt)
				uassert.NoError(t, err)
			},
			testFn: func(t *testing.T) {
				// Set admin realm for this test
				testing.SetRealm(adminRealm)

				// NoHalt -> EmergencyHalt
				err := SetHaltLevelByAdmin(cross, LvEmergencyHalt)
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
			},
		},
		{
			name: "Mode transition edge cases",
			setupFn: func() {
				testing.SetRealm(adminRealm)
			},
			testFn: func(t *testing.T) {
				// Set admin realm for this test
				testing.SetRealm(adminRealm)

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
			},
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// Setup
			tc.setupFn()

			// Test
			tc.testFn(t)
		})
	}
}
