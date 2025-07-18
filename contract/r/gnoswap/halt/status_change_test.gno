// This tests for changing halt status and permissions
package halt

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
)

func TestStatusChange_SetHalt(t *testing.T) {
	var (
		adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
		adminRealm   = std.NewUserRealm(adminAddr)
	)

	tests := []struct {
		name                 string
		executorRealm        std.Realm
		initialHaltLevel     LevelID
		isHalted             bool
		haltLevels           []LevelID
		operationType        OpType
		preOpStatus          bool
		expectedHasPanic     bool
		expectedPanicMessage string
		expectedError        bool
		expectedFinalLevel   LevelID
		expectedOpAllowed    bool
	}{
		{
			name:               "Success transition from NoHalt to EmergencyHalt",
			executorRealm:      adminRealm,
			initialHaltLevel:   LvNoHalt,
			isHalted:           true,
			haltLevels:         []LevelID{LvEmergencyHalt},
			operationType:      OpTypeWithdraw,
			preOpStatus:        true,
			expectedError:      false,
			expectedFinalLevel: LvEmergencyHalt,
			expectedOpAllowed:  true,
		},
		{
			name:               "Success complex transition sequence with operation status preservation",
			executorRealm:      adminRealm,
			initialHaltLevel:   LvNoHalt,
			isHalted:           false,
			haltLevels:         []LevelID{LvEmergencyHalt, LvNoHalt},
			operationType:      OpTypeWithdraw,
			preOpStatus:        true,
			expectedError:      false,
			expectedFinalLevel: LvNoHalt,
			expectedOpAllowed:  true,
		},
		{
			name:               "Success operation status inheritance through multiple levels",
			executorRealm:      adminRealm,
			initialHaltLevel:   LvNoHalt,
			isHalted:           false,
			haltLevels:         []LevelID{LvEmergencyHalt, LvCompleteHalt, LvNoHalt},
			operationType:      OpTypePool,
			preOpStatus:        false,
			expectedError:      false,
			expectedFinalLevel: LvNoHalt,
			expectedOpAllowed:  false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanupHalt()

			// given
			testing.SetRealm(tc.executorRealm)
			err := SetHalt(cross, false)
			uassert.NoError(t, err)

			// Set pre-operation status
			err = SetOperationStatusByAdmin(cross, tc.operationType, tc.preOpStatus)
			uassert.NoError(t, err)

			// when
			var finalErr error
			for _, level := range tc.haltLevels {
				if level == LvNoHalt {
					finalErr = SetHalt(cross, false)
				} else {
					finalErr = SetHalt(cross, true, level)
				}
				if finalErr != nil {
					break
				}
			}

			// then
			if tc.expectedHasPanic {
				t.Errorf("[%s] expected panic but none occurred", tc.name)
			} else if tc.expectedError {
				uassert.Error(t, finalErr)
			} else {
				uassert.NoError(t, finalErr)
				uassert.True(t, GetCurrentHaltLevel() == tc.expectedFinalLevel)

				// Check operation status
				err = IsHalted(tc.operationType)
				if tc.expectedOpAllowed {
					uassert.NoError(t, err)
				} else {
					uassert.Error(t, err)
				}
			}
		})
	}
}

func TestStatusChange_SetOperationStatus(t *testing.T) {
	var (
		adminAddr, _      = access.GetAddress(access.ROLE_ADMIN)
		adminRealm        = std.NewUserRealm(adminAddr)
		govRealm          = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
		unauthorizedRealm = std.NewCodeRealm("gno.land/r/demo/unauthorized")
	)

	tests := []struct {
		name                 string
		executorRealm        std.Realm
		initialHaltLevel     LevelID
		operationType        OpType
		operationStatus      bool
		useAdminMethod       bool
		expectedHasPanic     bool
		expectedPanicMessage string
		expectedError        bool
		expectedOpAllowed    bool
	}{
		{
			name:              "Success admin disables operation",
			executorRealm:     adminRealm,
			initialHaltLevel:  LvNoHalt,
			operationType:     OpTypePool,
			operationStatus:   false,
			useAdminMethod:    true,
			expectedError:     false,
			expectedOpAllowed: false,
		},
		{
			name:              "Success governance enables operation",
			executorRealm:     govRealm,
			initialHaltLevel:  LvNoHalt,
			operationType:     OpTypePool,
			operationStatus:   true,
			useAdminMethod:    false,
			expectedError:     false,
			expectedOpAllowed: true,
		},
		{
			name:              "Success admin overrides governance",
			executorRealm:     adminRealm,
			initialHaltLevel:  LvNoHalt,
			operationType:     OpTypePool,
			operationStatus:   false,
			useAdminMethod:    true,
			expectedError:     false,
			expectedOpAllowed: false,
		},
		{
			name:              "Fail unauthorized user tries to enable operation",
			executorRealm:     unauthorizedRealm,
			initialHaltLevel:  LvNoHalt,
			operationType:     OpTypePool,
			operationStatus:   true,
			useAdminMethod:    false,
			expectedError:     true,
			expectedOpAllowed: false,
		},
		{
			name:              "Fail unauthorized user tries to set halt level",
			executorRealm:     unauthorizedRealm,
			initialHaltLevel:  LvNoHalt,
			operationType:     OpTypePool,
			operationStatus:   true,
			useAdminMethod:    true,
			expectedError:     true,
			expectedOpAllowed: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanupHalt()

			// given
			testing.SetRealm(adminRealm)
			err := SetHalt(cross, false)
			uassert.NoError(t, err)

			testing.SetRealm(tc.executorRealm)

			// when
			var operationErr error
			if tc.useAdminMethod {
				operationErr = SetOperationStatusByAdmin(cross, tc.operationType, tc.operationStatus)
			} else {
				operationErr = SetOperationStatus(cross, tc.operationType, tc.operationStatus)
			}

			// then
			if tc.expectedHasPanic {
				t.Errorf("[%s] expected panic but none occurred", tc.name)
			} else if tc.expectedError {
				uassert.Error(t, operationErr)
			} else {
				uassert.NoError(t, operationErr)

				// Check operation status
				err = IsHalted(tc.operationType)
				if tc.expectedOpAllowed {
					uassert.NoError(t, err)
				} else {
					uassert.Error(t, err)
				}
			}
		})
	}
}

func TestStatusChange_EnableWithdrawalsForTestnet(t *testing.T) {
	var (
		adminAddr, _      = access.GetAddress(access.ROLE_ADMIN)
		adminRealm        = std.NewUserRealm(adminAddr)
		unauthorizedRealm = std.NewCodeRealm("gno.land/r/demo/unauthorized")
	)

	tests := []struct {
		name                    string
		executorRealm           std.Realm
		initialHaltLevel        LevelID
		expectedHasPanic        bool
		expectedPanicMessage    string
		expectedError           bool
		expectedWithdrawAllowed bool
	}{
		{
			name:                    "Success admin enables withdrawals for testnet",
			executorRealm:           adminRealm,
			initialHaltLevel:        LvNoHalt,
			expectedError:           false,
			expectedWithdrawAllowed: true,
		},
		{
			name:                    "Fail unauthorized user tries to enable withdrawals",
			executorRealm:           unauthorizedRealm,
			initialHaltLevel:        LvNoHalt,
			expectedError:           true,
			expectedWithdrawAllowed: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanupHalt()

			// given
			testing.SetRealm(adminRealm)
			err := SetHalt(cross, false)
			uassert.NoError(t, err)

			testing.SetRealm(tc.executorRealm)

			// when
			err = EnableWithdrawalsForTestnet(cross)

			// then
			if tc.expectedHasPanic {
				t.Errorf("[%s] expected panic but none occurred", tc.name)
			} else if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)

				// Check withdraw operation status
				err = IsHalted(OpTypeWithdraw)
				if tc.expectedWithdrawAllowed {
					uassert.NoError(t, err)
				} else {
					uassert.Error(t, err)
				}
			}
		})
	}
}

// Helper functions
func cleanupHalt() {
	// Reset halt manager to default state
	haltManager = DefaultManager()
}

func setupHaltTest() {
	cleanupHalt()
}

func verifyHaltLevel(expectedLevel LevelID) bool {
	return GetCurrentHaltLevel() == expectedLevel
}

func verifyOperationAllowed(opType OpType) bool {
	err := IsHalted(opType)
	return err == nil
}
