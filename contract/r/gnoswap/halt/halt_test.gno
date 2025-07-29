package halt

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/v1/access"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"
)

// Test internal setHaltLevel function
func TestHalt_SetHaltLevel_Internal(t *testing.T) {
	tests := []struct {
		name             string
		inputLevel       HaltLevel
		expectedConfig   HaltConfig
		expectedHasError bool
	}{
		{
			name:             "Success set none level",
			inputLevel:       HaltLevelNone,
			expectedConfig:   newNoneConfig(),
			expectedHasError: false,
		},
		{
			name:             "Success set safe mode level",
			inputLevel:       HaltLevelSafeMode,
			expectedConfig:   newSafeModeConfig(),
			expectedHasError: false,
		},
		{
			name:             "Success set emergency level",
			inputLevel:       HaltLevelEmergency,
			expectedConfig:   newEmergencyConfig(),
			expectedHasError: false,
		},
		{
			name:             "Success set complete level",
			inputLevel:       HaltLevelComplete,
			expectedConfig:   newCompleteConfig(),
			expectedHasError: false,
		},
		{
			name:             "Fail invalid level",
			inputLevel:       HaltLevel("INVALID"),
			expectedConfig:   nil,
			expectedHasError: true,
		},
		{
			name:             "Fail empty level",
			inputLevel:       HaltLevel(""),
			expectedConfig:   nil,
			expectedHasError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// when
			err := setHaltLevel(tc.inputLevel)

			// then
			if tc.expectedHasError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)

				config := GetHaltConfig()
				for op, expectedHalted := range tc.expectedConfig {
					actualHalted, err := config.get(op)
					uassert.NoError(t, err)
					uassert.Equal(t, actualHalted, expectedHalted)
				}
			}
		})
	}
}

// Test GetHaltConfig function
func TestHalt_GetHaltConfig(t *testing.T) {
	cleanup()

	// given - set a specific configuration
	err := setHaltLevel(HaltLevelSafeMode)
	uassert.NoError(t, err)

	// when
	config := GetHaltConfig()

	// then
	expectedConfig := newSafeModeConfig()
	for op, expectedHalted := range expectedConfig {
		actualHalted, err := config.get(op)
		uassert.NoError(t, err)
		uassert.Equal(t, actualHalted, expectedHalted)
	}

	// Test that returned config is a copy (independence)
	clonedConfig := GetHaltConfig()

	// Modify internal state
	haltConfig.set(OpTypePool, true)

	// Check that the clone is independent
	halted, err := clonedConfig.get(OpTypePool)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, false) // Should still be false (not halted) in the clone
}

// Test IsHalted function
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
			operations:     []OpType{OpType("invalid")},
			expectedHalted: true,
			expectedError:  true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

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

// Test individual operation halt status functions
func TestHalt_IndividualOperationStatus(t *testing.T) {
	tests := []struct {
		name             string
		initialLevel     HaltLevel
		operation        OpType
		expectedHalted   bool
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name:           "None level - pool not halted",
			initialLevel:   HaltLevelNone,
			operation:      OpTypePool,
			expectedHalted: false,
			expectedPanic:  false,
		},
		{
			name:           "Safe mode - pool not halted",
			initialLevel:   HaltLevelSafeMode,
			operation:      OpTypePool,
			expectedHalted: false,
			expectedPanic:  false,
		},
		{
			name:           "Safe mode - withdraw halted",
			initialLevel:   HaltLevelSafeMode,
			operation:      OpTypeWithdraw,
			expectedHalted: true,
			expectedPanic:  false,
		},
		{
			name:           "Emergency - pool halted",
			initialLevel:   HaltLevelEmergency,
			operation:      OpTypePool,
			expectedHalted: true,
			expectedPanic:  false,
		},
		{
			name:           "Emergency - governance not halted",
			initialLevel:   HaltLevelEmergency,
			operation:      OpTypeGovernance,
			expectedHalted: false,
			expectedPanic:  false,
		},
		{
			name:           "Complete - governance halted",
			initialLevel:   HaltLevelComplete,
			operation:      OpTypeGovernance,
			expectedHalted: true,
			expectedPanic:  false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			err := setHaltLevel(tc.initialLevel)
			uassert.NoError(t, err)

			// when/then
			if tc.expectedPanic {
				uassert.AbortsWithMessage(t, tc.expectedPanicMsg, func() {
					isHaltedOperation(tc.operation)
				})
			} else {
				halted := isHaltedOperation(tc.operation)
				uassert.Equal(t, halted, tc.expectedHalted)
			}
		})
	}
}

// Test GetHaltConfigJson function
func TestHalt_GetHaltConfigJson(t *testing.T) {
	tests := []struct {
		name         string
		initialLevel HaltLevel
	}{
		{
			name:         "None level JSON",
			initialLevel: HaltLevelNone,
		},
		{
			name:         "Safe mode JSON",
			initialLevel: HaltLevelSafeMode,
		},
		{
			name:         "Emergency JSON",
			initialLevel: HaltLevelEmergency,
		},
		{
			name:         "Complete JSON",
			initialLevel: HaltLevelComplete,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			err := setHaltLevel(tc.initialLevel)
			uassert.NoError(t, err)

			// when
			jsonStr := GetHaltConfigJson()

			// then
			uassert.True(t, len(jsonStr) > 0)
			// The returned string should contain JSON structure
			uassert.True(t, jsonStr[0] == '{' && jsonStr[len(jsonStr)-1] == '}')
		})
	}
}

// Test SetHaltLevel with authorization
func TestHalt_SetHaltLevel_WithAuthorization(t *testing.T) {
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
	govAddr, _ := access.GetAddress(prbac.ROLE_GOVERNANCE.String())

	tests := []struct {
		name                 string
		callerAddress        std.Address
		inputLevel           HaltLevel
		expectedLevel        HaltLevel
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:                 "Success with admin realm",
			callerAddress:        adminAddr,
			inputLevel:           HaltLevelEmergency,
			expectedLevel:        HaltLevelEmergency,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "Success with governance realm",
			callerAddress:        govAddr,
			inputLevel:           HaltLevelNone,
			expectedLevel:        HaltLevelNone,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "Fail with unauthorized realm",
			callerAddress:        std.Address("g1unauthorized"),
			inputLevel:           HaltLevelComplete,
			expectedLevel:        HaltLevelNone, // Should remain unchanged
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1unauthorized is not admin or governance",
		},
		{
			name:                 "Fail with invalid level",
			callerAddress:        adminAddr,
			inputLevel:           HaltLevel("INVALID"),
			expectedLevel:        HaltLevelNone,
			expectedHasAbort:     true,
			expectedAbortMessage: "invalid halt level: INVALID",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			testing.SetRealm(std.NewUserRealm(tc.callerAddress))

			// when/then
			if tc.expectedHasAbort {
				uassert.AbortsWithMessage(t, tc.expectedAbortMessage, func() {
					SetHaltLevel(cross, tc.inputLevel)
				})
			} else {
				SetHaltLevel(cross, tc.inputLevel)

				// Verify the level was set correctly by checking specific operations
				config := GetHaltConfig()
				expectedConfig := newNoneConfig()
				switch tc.expectedLevel {
				case HaltLevelNone:
					expectedConfig = newNoneConfig()
				case HaltLevelSafeMode:
					expectedConfig = newSafeModeConfig()
				case HaltLevelEmergency:
					expectedConfig = newEmergencyConfig()
				case HaltLevelComplete:
					expectedConfig = newCompleteConfig()
				}

				for op, expectedHalted := range expectedConfig {
					actualHalted, err := config.get(op)
					uassert.NoError(t, err)
					uassert.Equal(t, actualHalted, expectedHalted)
				}
			}
		})
	}
}

// Test SetOperationStatus with authorization
func TestHalt_SetOperationStatus_WithAuthorization(t *testing.T) {
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
	govAddr, _ := access.GetAddress(prbac.ROLE_GOVERNANCE.String())

	tests := []struct {
		name                 string
		callerAddress        std.Address
		operationType        OpType
		halted               bool
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:                 "Success with admin realm - halt pool",
			callerAddress:        adminAddr,
			operationType:        OpTypePool,
			halted:               true,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "Success with governance realm - unhalt router",
			callerAddress:        govAddr,
			operationType:        OpTypeRouter,
			halted:               false,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "Fail with unauthorized realm",
			callerAddress:        std.Address("g1unauthorized"),
			operationType:        OpTypePool,
			halted:               true,
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1unauthorized is not admin or governance",
		},
		{
			name:                 "Fail with invalid operation type",
			callerAddress:        adminAddr,
			operationType:        OpType("invalid"),
			halted:               true,
			expectedHasAbort:     true,
			expectedAbortMessage: "invalid operation type: invalid",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			testing.SetRealm(std.NewUserRealm(tc.callerAddress))

			// when/then
			if tc.expectedHasAbort {
				uassert.AbortsWithMessage(t, tc.expectedAbortMessage, func() {
					SetOperationStatus(cross, tc.operationType, tc.halted)
				})
			} else {
				SetOperationStatus(cross, tc.operationType, tc.halted)

				// Verify the operation status was set correctly
				config := GetHaltConfig()
				halted, err := config.get(tc.operationType)
				uassert.NoError(t, err)
				uassert.Equal(t, halted, tc.halted)
			}
		})
	}
}

// Test comprehensive integration scenarios
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
			cleanup()

			// Set initial level
			err := setHaltLevel(tc.initialLevel)
			uassert.NoError(t, err)

			// Apply custom overrides
			for op, halted := range tc.customOperations {
				err := haltConfig.set(op, halted)
				uassert.NoError(t, err)
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

// Test edge cases
func TestHalt_EdgeCases(t *testing.T) {
	t.Run("GetHaltConfig independence", func(t *testing.T) {
		cleanup()

		// Get initial config
		haltConfig = newNoneConfig()

		configByGetter := GetHaltConfig()

		// Modify internal state
		err := haltConfig.set(OpTypePool, true)
		uassert.NoError(t, err)

		// Both should be independent of internal state and each other
		internalHalted, err := haltConfig.get(OpTypePool)
		uassert.NoError(t, err)
		uassert.Equal(t, internalHalted, true)

		getterHalted, err := configByGetter.get(OpTypePool)
		uassert.NoError(t, err)
		uassert.Equal(t, getterHalted, false)
	})

	t.Run("IsHalted with no operations", func(t *testing.T) {
		cleanup()
		err := setHaltLevel(HaltLevelComplete)
		uassert.NoError(t, err)

		// Empty operation list should return false
		halted, err := IsHalted()
		uassert.NoError(t, err)
		uassert.Equal(t, halted, false)
	})

	t.Run("Multiple halt level changes", func(t *testing.T) {
		cleanup()

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

	t.Run("HaltConfig Clone method", func(t *testing.T) {
		cleanup()

		original := newSafeModeConfig()
		cloned := original.Clone()

		// Modify original
		err := original.set(OpTypePool, true)
		uassert.NoError(t, err)

		// Cloned should remain unchanged
		originalHalted, err := original.get(OpTypePool)
		uassert.NoError(t, err)
		uassert.Equal(t, originalHalted, true)

		clonedHalted, err := cloned.get(OpTypePool)
		uassert.NoError(t, err)
		uassert.Equal(t, clonedHalted, false)
	})

	t.Run("HaltConfig IsHalted method", func(t *testing.T) {
		cleanup()

		config := newNoneConfig()

		// Test with existing operation
		uassert.Equal(t, config.IsHalted(OpTypePool), false)

		// Test with non-existing operation (this should not happen in practice)
		config = make(HaltConfig)
		uassert.Equal(t, config.IsHalted(OpTypePool), false)
	})
}

// Test helpers
func cleanup() {
	haltConfig = newNoneConfig()
}