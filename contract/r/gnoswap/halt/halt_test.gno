package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/access"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"
)

func TestHalt_SetHaltLevel_Internal(t *testing.T) {
	tests := []struct {
		name             string
		inputLevel       HaltLevel
		expectedConfig   uint64
		expectedHasError bool
		expectedErrorMsg string
	}{
		{
			name:             "Success set none level",
			inputLevel:       HaltLevelNone,
			expectedConfig:   ConfigNone,
			expectedHasError: false,
		},
		{
			name:             "Success set safe mode level",
			inputLevel:       HaltLevelSafeMode,
			expectedConfig:   ConfigSafeMode,
			expectedHasError: false,
		},
		{
			name:             "Success set emergency level",
			inputLevel:       HaltLevelEmergency,
			expectedConfig:   ConfigEmergency,
			expectedHasError: false,
		},
		{
			name:             "Success set complete level",
			inputLevel:       HaltLevelComplete,
			expectedConfig:   ConfigComplete,
			expectedHasError: false,
		},
		{
			name:             "Fail invalid level",
			inputLevel:       HaltLevel("INVALID"),
			expectedHasError: true,
			expectedErrorMsg: "invalid halt level: INVALID",
		},
		{
			name:             "Fail empty level",
			inputLevel:       HaltLevel(""),
			expectedHasError: true,
			expectedErrorMsg: "invalid halt level: ",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// when
			err := setHaltLevel(tc.inputLevel)

			// then
			if tc.expectedHasError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tc.expectedErrorMsg)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, haltState, tc.expectedConfig)
			}
		})
	}
}

func TestHalt_GetHaltConfig(t *testing.T) {
	cleanup(t)

	// given - set a specific configuration
	err := setHaltLevel(HaltLevelSafeMode)
	uassert.NoError(t, err)

	// when
	config := GetHaltConfig()

	// then - verify expected halt states
	uassert.Equal(t, config["pool"], false)
	uassert.Equal(t, config["position"], false)
	uassert.Equal(t, config["router"], false)
	uassert.Equal(t, config["governance"], false)
	uassert.Equal(t, config["withdraw"], true)

	// Should contain all 12 operations
	uassert.Equal(t, len(config), 12)
}

func TestHalt_IsHalted(t *testing.T) {
	tests := []struct {
		name           string
		initialLevel   HaltLevel
		operations     []OpType
		expectedHalted bool
		expectedError  bool
	}{
		{
			name:           "None level - no operations halted",
			initialLevel:   HaltLevelNone,
			operations:     []OpType{OpTypePool, OpTypeRouter},
			expectedHalted: false,
			expectedError:  false,
		},
		{
			name:           "Safe mode - most operations not halted",
			initialLevel:   HaltLevelSafeMode,
			operations:     []OpType{OpTypePool, OpTypeGovernance},
			expectedHalted: false,
			expectedError:  false,
		},
		{
			name:           "Safe mode - withdraw is halted",
			initialLevel:   HaltLevelSafeMode,
			operations:     []OpType{OpTypeWithdraw},
			expectedHalted: true,
			expectedError:  false,
		},
		{
			name:           "Emergency - pool operations halted",
			initialLevel:   HaltLevelEmergency,
			operations:     []OpType{OpTypePool},
			expectedHalted: true,
			expectedError:  false,
		},
		{
			name:           "Emergency - governance not halted",
			initialLevel:   HaltLevelEmergency,
			operations:     []OpType{OpTypeGovernance},
			expectedHalted: false,
			expectedError:  false,
		},
		{
			name:           "Emergency - mixed operations",
			initialLevel:   HaltLevelEmergency,
			operations:     []OpType{OpTypePool, OpTypeGovernance},
			expectedHalted: true, // Should return true if ANY operation is halted
			expectedError:  false,
		},
		{
			name:           "Complete - all operations halted",
			initialLevel:   HaltLevelComplete,
			operations:     []OpType{OpTypePool, OpTypeGovernance},
			expectedHalted: true,
			expectedError:  false,
		},
		{
			name:           "Empty operations list",
			initialLevel:   HaltLevelComplete,
			operations:     []OpType{},
			expectedHalted: false, // No operations to check
			expectedError:  false,
		},
		{
			name:           "Invalid operation type",
			initialLevel:   HaltLevelNone,
			operations:     []OpType{OpType(0)},
			expectedHalted: true,
			expectedError:  true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			err := setHaltLevel(tc.initialLevel)
			uassert.NoError(t, err)

			// when
			halted, err := IsHalted(tc.operations...)

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
			uassert.Equal(t, halted, tc.expectedHalted)
		})
	}
}

func TestHalt_IndividualOperationStatus(t *testing.T) {
	tests := []struct {
		name           string
		initialLevel   HaltLevel
		operation      OpType
		expectedHalted bool
	}{
		{
			name:           "None level - pool not halted",
			initialLevel:   HaltLevelNone,
			operation:      OpTypePool,
			expectedHalted: false,
		},
		{
			name:           "Safe mode - pool not halted",
			initialLevel:   HaltLevelSafeMode,
			operation:      OpTypePool,
			expectedHalted: false,
		},
		{
			name:           "Safe mode - withdraw halted",
			initialLevel:   HaltLevelSafeMode,
			operation:      OpTypeWithdraw,
			expectedHalted: true,
		},
		{
			name:           "Emergency - pool halted",
			initialLevel:   HaltLevelEmergency,
			operation:      OpTypePool,
			expectedHalted: true,
		},
		{
			name:           "Emergency - governance not halted",
			initialLevel:   HaltLevelEmergency,
			operation:      OpTypeGovernance,
			expectedHalted: false,
		},
		{
			name:           "Complete - governance halted",
			initialLevel:   HaltLevelComplete,
			operation:      OpTypeGovernance,
			expectedHalted: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			err := setHaltLevel(tc.initialLevel)
			uassert.NoError(t, err)

			// when/then
			halted := isHaltedOperation(tc.operation)
			uassert.Equal(t, halted, tc.expectedHalted)
		})
	}
}

func TestHalt_GetHaltConfigJson(t *testing.T) {
	tests := []struct {
		name         string
		initialLevel HaltLevel
	}{
		{"None level JSON", HaltLevelNone},
		{"Safe mode JSON", HaltLevelSafeMode},
		{"Emergency JSON", HaltLevelEmergency},
		{"Complete JSON", HaltLevelComplete},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			err := setHaltLevel(tc.initialLevel)
			uassert.NoError(t, err)

			jsonStr := GetHaltConfigJson()

			uassert.True(t, len(jsonStr) > 0)
			uassert.True(t, jsonStr[0] == '{' && jsonStr[len(jsonStr)-1] == '}')
		})
	}
}

func TestHalt_SetHaltLevel_WithAuthorization(t *testing.T) {
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govAddr := access.MustGetAddress(prbac.ROLE_GOVERNANCE.String())

	tests := []struct {
		name                 string
		callerAddress        address
		inputLevel           HaltLevel
		expectedConfig       uint64
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:             "Success with admin realm",
			callerAddress:    adminAddr,
			inputLevel:       HaltLevelEmergency,
			expectedConfig:   ConfigEmergency,
			expectedHasAbort: false,
		},
		{
			name:             "Success with governance realm",
			callerAddress:    govAddr,
			inputLevel:       HaltLevelNone,
			expectedConfig:   ConfigNone,
			expectedHasAbort: false,
		},
		{
			name:                 "Fail with unauthorized realm",
			callerAddress:        address("g1unauthorized"),
			inputLevel:           HaltLevelComplete,
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1unauthorized is not admin or governance",
		},
		{
			name:                 "Fail with invalid level",
			callerAddress:        adminAddr,
			inputLevel:           HaltLevel("INVALID"),
			expectedHasAbort:     true,
			expectedAbortMessage: "invalid halt level: INVALID",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			testing.SetRealm(testing.NewUserRealm(tc.callerAddress))

			// when/then
			if tc.expectedHasAbort {
				uassert.AbortsWithMessage(t, tc.expectedAbortMessage, func() {
					SetHaltLevel(cross, tc.inputLevel)
				})
			} else {
				SetHaltLevel(cross, tc.inputLevel)
				uassert.Equal(t, haltState, tc.expectedConfig)
			}
		})
	}
}

func TestHalt_SetOperationStatus_WithAuthorization(t *testing.T) {
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govAddr := access.MustGetAddress(prbac.ROLE_GOVERNANCE.String())

	tests := []struct {
		name                 string
		callerAddress        address
		operationType        OpType
		halted               bool
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:             "Success with admin realm - halt pool",
			callerAddress:    adminAddr,
			operationType:    OpTypePool,
			halted:           true,
			expectedHasAbort: false,
		},
		{
			name:             "Success with governance realm - unhalt router",
			callerAddress:    govAddr,
			operationType:    OpTypeRouter,
			halted:           false,
			expectedHasAbort: false,
		},
		{
			name:                 "Fail with unauthorized realm",
			callerAddress:        address("g1unauthorized"),
			operationType:        OpTypePool,
			halted:               true,
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1unauthorized is not admin or governance",
		},
		{
			name:                 "Fail with invalid operation type",
			callerAddress:        adminAddr,
			operationType:        OpType(0),
			halted:               true,
			expectedHasAbort:     true,
			expectedAbortMessage: "invalid operation type: unknown",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			testing.SetRealm(testing.NewUserRealm(tc.callerAddress))

			// when/then
			if tc.expectedHasAbort {
				uassert.AbortsWithMessage(t, tc.expectedAbortMessage, func() {
					SetOperationStatus(cross, tc.operationType, tc.halted)
				})
			} else {
				SetOperationStatus(cross, tc.operationType, tc.halted)

				// Verify the operation status was set correctly
				halted := isHaltedOperation(tc.operationType)
				uassert.Equal(t, halted, tc.halted)
			}
		})
	}
}

func TestHalt_IntegrationScenarios(t *testing.T) {
	tests := []struct {
		name                 string
		initialLevel         HaltLevel
		customOperations     map[OpType]bool
		testOperations       []OpType
		expectedHalted       bool
		expectedStatusChecks map[OpType]bool
	}{
		{
			name:         "Emergency with custom overrides",
			initialLevel: HaltLevelEmergency,
			customOperations: map[OpType]bool{
				OpTypePool: false, // Override to not halt pool
			},
			testOperations: []OpType{OpTypePool, OpTypeRouter},
			expectedHalted: true, // Router is still halted
			expectedStatusChecks: map[OpType]bool{
				OpTypePool:   false, // Custom override - not halted
				OpTypeRouter: true,  // Emergency default - halted
			},
		},
		{
			name:         "Safe mode with selective halting",
			initialLevel: HaltLevelSafeMode,
			customOperations: map[OpType]bool{
				OpTypeGovernance: true, // Halt governance
			},
			testOperations: []OpType{OpTypeGovernance},
			expectedHalted: true, // Governance halted
			expectedStatusChecks: map[OpType]bool{
				OpTypeGovernance: true,  // Custom override - halted
				OpTypePool:       false, // Safe mode default - not halted
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// Set initial level
			err := setHaltLevel(tc.initialLevel)
			uassert.NoError(t, err)

			// Apply custom overrides via bitmask operations
			for op, halted := range tc.customOperations {
				if halted {
					haltState |= uint64(op)
				} else {
					haltState &^= uint64(op)
				}
			}

			// Test IsHalted
			halted, err := IsHalted(tc.testOperations...)
			uassert.NoError(t, err)
			uassert.Equal(t, halted, tc.expectedHalted)

			// Test individual status checks
			for op, expected := range tc.expectedStatusChecks {
				halted := isHaltedOperation(op)
				uassert.Equal(t, halted, expected)
			}
		})
	}
}

func TestHalt_EdgeCases(t *testing.T) {
	t.Run("GetHaltConfig independence", func(t *testing.T) {
		cleanup(t)

		config := GetHaltConfig()

		// Modify internal state
		haltState |= uint64(OpTypePool)

		// Config snapshot should be independent of internal state
		uassert.Equal(t, config["pool"], false)

		// Internal state should reflect the change
		uassert.Equal(t, isHaltedOperation(OpTypePool), true)
	})

	t.Run("IsHalted with no operations", func(t *testing.T) {
		cleanup(t)
		err := setHaltLevel(HaltLevelComplete)
		uassert.NoError(t, err)

		// Empty operation list should return false
		halted, err := IsHalted()
		uassert.NoError(t, err)
		uassert.Equal(t, halted, false)
	})

	t.Run("Multiple halt level changes", func(t *testing.T) {
		cleanup(t)

		// Start with emergency
		err := setHaltLevel(HaltLevelEmergency)
		uassert.NoError(t, err)
		uassert.Equal(t, isHaltedOperation(OpTypePool), true)

		// Change to none
		err = setHaltLevel(HaltLevelNone)
		uassert.NoError(t, err)
		uassert.Equal(t, isHaltedOperation(OpTypePool), false)

		// Change to complete
		err = setHaltLevel(HaltLevelComplete)
		uassert.NoError(t, err)
		uassert.Equal(t, isHaltedOperation(OpTypePool), true)
		uassert.Equal(t, isHaltedOperation(OpTypeGovernance), true)
	})

	t.Run("Bitmask operations are atomic", func(t *testing.T) {
		cleanup(t)

		// Set individual operations
		haltState |= uint64(OpTypePool)
		haltState |= uint64(OpTypeRouter)
		uassert.Equal(t, isHaltedOperation(OpTypePool), true)
		uassert.Equal(t, isHaltedOperation(OpTypeRouter), true)
		uassert.Equal(t, isHaltedOperation(OpTypeStaker), false)

		// Clear one operation
		haltState &^= uint64(OpTypePool)
		uassert.Equal(t, isHaltedOperation(OpTypePool), false)
		uassert.Equal(t, isHaltedOperation(OpTypeRouter), true)
	})

	t.Run("SetHaltLevel overwrites all bits", func(t *testing.T) {
		cleanup(t)

		// Set some individual operations
		haltState |= uint64(OpTypePool)
		haltState |= uint64(OpTypeRouter)

		// Setting halt level should overwrite completely
		err := setHaltLevel(HaltLevelNone)
		uassert.NoError(t, err)
		uassert.Equal(t, haltState, ConfigNone)
		uassert.Equal(t, isHaltedOperation(OpTypePool), false)
		uassert.Equal(t, isHaltedOperation(OpTypeRouter), false)
	})
}

func cleanup(t *testing.T) {
	t.Helper()
	haltState = ConfigNone
}
