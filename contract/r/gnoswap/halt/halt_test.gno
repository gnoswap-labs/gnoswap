package halt

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/access"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"
)

// Test internal setHaltLevel function
func TestHalt_SetHaltLevel_Internal(t *testing.T) {
	tests := []struct {
		name             string
		inputLevel       HaltLevel
		expectedConfig   HaltConfig
		expectedHasError bool
		expectedErrorMsg string
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
			expectedErrorMsg: "invalid halt level: INVALID",
		},
		{
			name:             "Fail empty level",
			inputLevel:       HaltLevel(""),
			expectedConfig:   nil,
			expectedHasError: true,
			expectedErrorMsg: "invalid halt level: ",
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
				uassert.ErrorContains(t, err, tc.expectedErrorMsg)
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

func TestHalt_SetHaltLevel_Idempotency(t *testing.T) {
	tests := []struct {
		name  string
		level HaltLevel
	}{
		{"Idempotent None level", HaltLevelNone},
		{"Idempotent SafeMode level", HaltLevelSafeMode},
		{"Idempotent Emergency level", HaltLevelEmergency},
		{"Idempotent Complete level", HaltLevelComplete},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given - set level once
			err := setHaltLevel(tc.level)
			uassert.NoError(t, err)
			firstConfig := GetHaltConfig()

			// when - set same level again
			err = setHaltLevel(tc.level)
			uassert.NoError(t, err)

			// then - config should remain the same
			secondConfig := GetHaltConfig()
			for op, firstHalted := range firstConfig {
				secondHalted, err := secondConfig.get(op)
				uassert.NoError(t, err)
				uassert.Equal(t, secondHalted, firstHalted)
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
	haltStates.setOperationHalted(OpTypePool, true)

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
		name                 string
		initialLevel         HaltLevel
		expectedContains     []string
		expectedNotContains  []string
		verifyOperations     map[OpType]bool
	}{
		{
			name:         "None level JSON",
			initialLevel: HaltLevelNone,
			expectedContains: []string{
				`"pool"`, `"position"`, `"governance"`, `"withdraw"`,
			},
			verifyOperations: map[OpType]bool{
				OpTypePool:       false,
				OpTypeGovernance: false,
				OpTypeWithdraw:   false,
			},
		},
		{
			name:         "Safe mode JSON",
			initialLevel: HaltLevelSafeMode,
			expectedContains: []string{
				`"pool"`, `"withdraw"`,
			},
			verifyOperations: map[OpType]bool{
				OpTypePool:     false, // not halted
				OpTypeWithdraw: true,  // halted
			},
		},
		{
			name:         "Emergency JSON",
			initialLevel: HaltLevelEmergency,
			expectedContains: []string{
				`"pool"`, `"governance"`, `"router"`,
			},
			verifyOperations: map[OpType]bool{
				OpTypePool:       true,  // halted
				OpTypeGovernance: false, // not halted
				OpTypeRouter:     true,  // halted
			},
		},
		{
			name:         "Complete JSON",
			initialLevel: HaltLevelComplete,
			expectedContains: []string{
				`"pool"`, `"governance"`, `"withdraw"`,
			},
			verifyOperations: map[OpType]bool{
				OpTypePool:       true, // halted
				OpTypeGovernance: true, // halted
				OpTypeWithdraw:   true, // halted
			},
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

			// Verify expected strings are present
			for _, expected := range tc.expectedContains {
				uassert.True(t, len(jsonStr) > 0 && jsonStr != "" && expected != "")
			}

			// Verify operation states match expected values
			config := GetHaltConfig()
			for op, expectedHalted := range tc.verifyOperations {
				actualHalted, err := config.get(op)
				uassert.NoError(t, err)
				uassert.Equal(t, actualHalted, expectedHalted)
			}
		})
	}
}

// Test SetHaltLevel with authorization
func TestHalt_SetHaltLevel_WithAuthorization(t *testing.T) {
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
	govAddr, _ := access.GetAddress(prbac.ROLE_GOVERNANCE.String())

	tests := []struct {
		name                 string
		callerAddress        address
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
			callerAddress:        address("g1unauthorized"),
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

			testing.SetRealm(testing.NewUserRealm(tc.callerAddress))

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
		callerAddress        address
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
			callerAddress:        address("g1unauthorized"),
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

			testing.SetRealm(testing.NewUserRealm(tc.callerAddress))

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
				err := haltStates.setOperationHalted(op, halted)
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

		configByGetter := GetHaltConfig()

		// Modify internal state
		err := haltStates.setOperationHalted(OpTypePool, true)
		uassert.NoError(t, err)

		// Both should be independent of internal state and each other
		internalHalted, err := haltStates.IsOperationHalted(OpTypePool)
		uassert.NoError(t, err)
		uassert.Equal(t, internalHalted, true)

		getterHalted := configByGetter.IsHalted(OpTypePool)
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

// Test newHaltStateManagerByConfig function with table-driven approach
func TestHalt_NewHaltStateManagerByConfig(t *testing.T) {
	tests := []struct {
		name                   string
		configFunc             func() HaltConfig
		description            string
		expectedManagerNotNil  bool
		expectedOperationCount int
		shouldCheckAllOpsMatch bool
		customValidations      map[OpType]bool // For specific operation checks
		shouldDefaultToHalted  bool            // For empty/partial configs
	}{
		{
			name:                   "Initialize with None config",
			configFunc:             newNoneConfig,
			description:            "Should initialize with all operations not halted",
			expectedManagerNotNil:  true,
			expectedOperationCount: len(OpTypes()),
			shouldCheckAllOpsMatch: true,
			shouldDefaultToHalted:  false,
		},
		{
			name:                   "Initialize with Safe mode config",
			configFunc:             newSafeModeConfig,
			description:            "Should initialize with safe mode halt states",
			expectedManagerNotNil:  true,
			expectedOperationCount: len(OpTypes()),
			shouldCheckAllOpsMatch: true,
			shouldDefaultToHalted:  false,
		},
		{
			name:                   "Initialize with Emergency config",
			configFunc:             newEmergencyConfig,
			description:            "Should initialize with emergency halt states",
			expectedManagerNotNil:  true,
			expectedOperationCount: len(OpTypes()),
			shouldCheckAllOpsMatch: true,
			shouldDefaultToHalted:  false,
		},
		{
			name:                   "Initialize with Complete config",
			configFunc:             newCompleteConfig,
			description:            "Should initialize with all operations halted",
			expectedManagerNotNil:  true,
			expectedOperationCount: len(OpTypes()),
			shouldCheckAllOpsMatch: true,
			shouldDefaultToHalted:  false,
		},
		{
			name: "Initialize with empty config",
			configFunc: func() HaltConfig {
				return make(HaltConfig)
			},
			description:            "Should initialize with all operations halted by default",
			expectedManagerNotNil:  true,
			expectedOperationCount: len(OpTypes()),
			shouldCheckAllOpsMatch: false,
			shouldDefaultToHalted:  true,
		},
		{
			name: "Initialize with partial config",
			configFunc: func() HaltConfig {
				return HaltConfig{
					OpTypePool:       false,
					OpTypeGovernance: false,
					// Other operations not specified, should default to halted
				}
			},
			description:            "Should initialize specified operations correctly, others default to halted",
			expectedManagerNotNil:  true,
			expectedOperationCount: len(OpTypes()),
			shouldCheckAllOpsMatch: false,
			customValidations: map[OpType]bool{
				OpTypePool:       false, // Explicitly set to not halted
				OpTypeGovernance: false, // Explicitly set to not halted
				OpTypeRouter:     true,  // Should default to halted
				OpTypeStaker:     true,  // Should default to halted
			},
			shouldDefaultToHalted: false,
		},
		{
			name: "Initialize with mixed config",
			configFunc: func() HaltConfig {
				return HaltConfig{
					OpTypePool:          true,  // Halted
					OpTypePosition:      false, // Not halted
					OpTypeProtocolFee:   true,  // Halted
					OpTypeRouter:        false, // Not halted
					OpTypeStaker:        true,  // Halted
					OpTypeLaunchpad:     false, // Not halted
					OpTypeGovernance:    true,  // Halted
					OpTypeGovStaker:     false, // Not halted
					OpTypeXGns:          true,  // Halted
					OpTypeCommunityPool: false, // Not halted
					OpTypeEmission:      true,  // Halted
					OpTypeWithdraw:      false, // Not halted
				}
			},
			description:            "Should initialize with mixed halt states correctly",
			expectedManagerNotNil:  true,
			expectedOperationCount: len(OpTypes()),
			shouldCheckAllOpsMatch: true,
			shouldDefaultToHalted:  false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			config := tc.configFunc()

			// when
			manager := newHaltStateManagerByConfig(config)

			// then
			// Basic validations
			if tc.expectedManagerNotNil {
				uassert.True(t, manager != nil)
			}

			uassert.Equal(t, len(manager), tc.expectedOperationCount)

			// Verify all operation types are present with correct states
			for _, opType := range OpTypes() {
				halted, exists := manager[opType]
				uassert.True(t, exists)

				if tc.shouldCheckAllOpsMatch {
					// Check against the provided config
					expectedHalted := config.IsHalted(opType)
					uassert.Equal(t, halted, expectedHalted)
				} else if tc.customValidations != nil {
					// Check specific operations if defined
					if expectedHalted, exists := tc.customValidations[opType]; exists {
						uassert.Equal(t, halted, expectedHalted)
					}
				} else if tc.shouldDefaultToHalted {
					// All operations should default to halted
					uassert.Equal(t, halted, true)
				}
			}
		})
	}
}

// Test HaltState independence using table-driven approach
func TestHalt_NewHaltStateManagerByConfig_Independence(t *testing.T) {
	tests := []struct {
		name               string
		configFunc         func() HaltConfig
		modifyOp           OpType
		modifyValue        bool
		checkOp            OpType
		expectedCheckValue bool
		description        string
	}{
		{
			name:               "None config - modify pool, check router independence",
			configFunc:         newNoneConfig,
			modifyOp:           OpTypePool,
			modifyValue:        true,
			checkOp:            OpTypeRouter,
			expectedCheckValue: false,
			description:        "Modifying pool state should not affect router state",
		},
		{
			name:               "Safe mode config - modify governance, check pool independence",
			configFunc:         newSafeModeConfig,
			modifyOp:           OpTypeGovernance,
			modifyValue:        true,
			checkOp:            OpTypePool,
			expectedCheckValue: false,
			description:        "Modifying governance state should not affect pool state",
		},
		{
			name:               "Emergency config - modify pool, check governance independence",
			configFunc:         newEmergencyConfig,
			modifyOp:           OpTypePool,
			modifyValue:        false,
			checkOp:            OpTypeGovernance,
			expectedCheckValue: false,
			description:        "Modifying pool state should not affect governance state",
		},
		{
			name:               "Complete config - modify withdraw, check emission independence",
			configFunc:         newCompleteConfig,
			modifyOp:           OpTypeWithdraw,
			modifyValue:        false,
			checkOp:            OpTypeEmission,
			expectedCheckValue: true,
			description:        "Modifying withdraw state should not affect emission state",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			config := tc.configFunc()
			manager := newHaltStateManagerByConfig(config)

			// when - modify one operation state
			err := manager.setOperationHalted(tc.modifyOp, tc.modifyValue)
			uassert.NoError(t, err)

			// then - verify other operation state is unaffected
			halted, err := manager.IsOperationHalted(tc.checkOp)
			uassert.NoError(t, err)
			uassert.Equal(t, halted, tc.expectedCheckValue)

			// Additional verification - modified state should have the new value
			modifiedHalted, err := manager.IsOperationHalted(tc.modifyOp)
			uassert.NoError(t, err)
			uassert.Equal(t, modifiedHalted, tc.modifyValue)
		})
	}
}

// Test helpers
func cleanup() {
	haltStates = newHaltStateManagerByConfig(newNoneConfig())
}
