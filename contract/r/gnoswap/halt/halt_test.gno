package halt

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/v1/access"
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

				for op, status := range tc.expectedConfig {
					uassert.Equal(t, GetHaltConfig().get(op).access, status.access)
					uassert.Equal(t, GetHaltConfig().get(op).withdraw, status.withdraw)
				}
			}
		})
	}
}

// Test internal setAccessOperationStatus function
func TestHalt_UpdateHaltAccessOption_Internal(t *testing.T) {
	tests := []struct {
		name             string
		inputOption      *HaltOption
		inputAccess      bool
		expectedAccess   bool
		expectedWithdraw bool
		expectedHasError bool
	}{
		{
			name:             "Success enable access",
			inputOption:      &HaltOption{access: false, withdraw: true},
			inputAccess:      true,
			expectedAccess:   true,
			expectedWithdraw: true,
			expectedHasError: false,
		},
		{
			name:             "Success isable access",
			inputOption:      &HaltOption{access: true, withdraw: false},
			inputAccess:      false,
			expectedAccess:   false,
			expectedWithdraw: false,
			expectedHasError: false,
		},
		{
			name:             "Fail nil option",
			inputOption:      nil,
			inputAccess:      true,
			expectedAccess:   false,
			expectedWithdraw: false,
			expectedHasError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result, err := updateHaltAccessOption(tc.inputOption, tc.inputAccess)

			// then
			if tc.expectedHasError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, result.access, tc.expectedAccess)
				uassert.Equal(t, result.withdraw, tc.expectedWithdraw)
			}
		})
	}
}

// Test internal updateHaltWithdrawOption function
func TestHalt_UpdateHaltWithdrawOption_Internal(t *testing.T) {
	tests := []struct {
		name             string
		inputOption      *HaltOption
		inputWithdraw    bool
		expectedAccess   bool
		expectedWithdraw bool
		expectedHasError bool
	}{
		{
			name:             "Success enable withdraw",
			inputOption:      &HaltOption{access: true, withdraw: false},
			inputWithdraw:    true,
			expectedAccess:   true,
			expectedWithdraw: true,
			expectedHasError: false,
		},
		{
			name:             "Success isable withdraw",
			inputOption:      &HaltOption{access: false, withdraw: true},
			inputWithdraw:    false,
			expectedAccess:   false,
			expectedWithdraw: false,
			expectedHasError: false,
		},
		{
			name:             "Fail nil option",
			inputOption:      nil,
			inputWithdraw:    true,
			expectedAccess:   false,
			expectedWithdraw: false,
			expectedHasError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result, err := updateHaltWithdrawOption(tc.inputOption, tc.inputWithdraw)

			// then
			if tc.expectedHasError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, result.access, tc.expectedAccess)
				uassert.Equal(t, result.withdraw, tc.expectedWithdraw)
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
	for op, expectedOption := range expectedConfig {
		actualOption := config.get(op)
		uassert.Equal(t, actualOption.access, expectedOption.access)
		uassert.Equal(t, actualOption.withdraw, expectedOption.withdraw)
	}

	haltConfig.get(OpTypePool).disableAll()
	clonedConfig := GetHaltConfig()
	uassert.Equal(t, clonedConfig.get(OpTypePool).access, false)
}

// Test IsHalted function
func TestHalt_IsHalted_Internal(t *testing.T) {
	tests := []struct {
		name           string
		initialLevel   HaltLevel
		operations     []OpType
		expectedHalted bool
	}{
		{
			name:           "None level - no operations halted",
			initialLevel:   HaltLevelNone,
			operations:     []OpType{OpTypePool, OpTypeRouter},
			expectedHalted: false,
		},
		{
			name:           "Safe mode - operations not halted for access",
			initialLevel:   HaltLevelSafeMode,
			operations:     []OpType{OpTypePool, OpTypeGovernance},
			expectedHalted: false,
		},
		{
			name:           "Emergency - pool operations halted",
			initialLevel:   HaltLevelEmergency,
			operations:     []OpType{OpTypePool},
			expectedHalted: true,
		},
		{
			name:           "Emergency - governance not halted",
			initialLevel:   HaltLevelEmergency,
			operations:     []OpType{OpTypeGovernance},
			expectedHalted: false,
		},
		{
			name:           "Emergency - mixed operations",
			initialLevel:   HaltLevelEmergency,
			operations:     []OpType{OpTypePool, OpTypeGovernance},
			expectedHalted: true, // Should return true if ANY operation is halted
		},
		{
			name:           "Complete - all operations halted",
			initialLevel:   HaltLevelComplete,
			operations:     []OpType{OpTypePool, OpTypeGovernance},
			expectedHalted: true,
		},
		{
			name:           "Empty operations list",
			initialLevel:   HaltLevelComplete,
			operations:     []OpType{},
			expectedHalted: false, // No operations to check
		},
		{
			name:           "Single operation - pool halted in emergency",
			initialLevel:   HaltLevelEmergency,
			operations:     []OpType{OpTypePool},
			expectedHalted: true,
		},
		{
			name:           "Multiple operations - all allowed in none",
			initialLevel:   HaltLevelNone,
			operations:     []OpType{OpTypePool, OpTypePosition, OpTypeRouter, OpTypeStaker},
			expectedHalted: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			err := setHaltLevel(tc.initialLevel)
			uassert.NoError(t, err)

			// when
			halted := isHalted(tc.operations...)

			// then
			uassert.Equal(t, halted, tc.expectedHalted)
		})
	}
}

// Test isableedAccess function
func TestHalt_IsAllowedAccess(t *testing.T) {
	tests := []struct {
		name            string
		initialLevel    HaltLevel
		operation       OpType
		expectedAllowed bool
	}{
		{
			name:            "None level allows all access",
			initialLevel:    HaltLevelNone,
			operation:       OpTypePool,
			expectedAllowed: true,
		},
		{
			name:            "Safe mode allows access",
			initialLevel:    HaltLevelSafeMode,
			operation:       OpTypePool,
			expectedAllowed: true,
		},
		{
			name:            "Emergency disables pool access",
			initialLevel:    HaltLevelEmergency,
			operation:       OpTypePool,
			expectedAllowed: false,
		},
		{
			name:            "Emergency allows governance access",
			initialLevel:    HaltLevelEmergency,
			operation:       OpTypeGovernance,
			expectedAllowed: true,
		},
		{
			name:            "Complete disables all access",
			initialLevel:    HaltLevelComplete,
			operation:       OpTypeGovernance,
			expectedAllowed: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			err := setHaltLevel(tc.initialLevel)
			uassert.NoError(t, err)

			// when
			allowed := IsAllowedAccess(tc.operation)

			// then
			uassert.Equal(t, allowed, tc.expectedAllowed)
		})
	}
}

// Test isableedWithdraw function
func TestHalt_IsAllowedWithdraw(t *testing.T) {
	tests := []struct {
		name            string
		initialLevel    HaltLevel
		operation       OpType
		expectedAllowed bool
	}{
		{
			name:            "None level allows all withdraw",
			initialLevel:    HaltLevelNone,
			operation:       OpTypePool,
			expectedAllowed: true,
		},
		{
			name:            "Safe mode disables withdraw",
			initialLevel:    HaltLevelSafeMode,
			operation:       OpTypePool,
			expectedAllowed: false,
		},
		{
			name:            "Emergency allows withdraw",
			initialLevel:    HaltLevelEmergency,
			operation:       OpTypePool,
			expectedAllowed: true,
		},
		{
			name:            "Emergency allows governance withdraw",
			initialLevel:    HaltLevelEmergency,
			operation:       OpTypeGovernance,
			expectedAllowed: true,
		},
		{
			name:            "Complete disables all withdraw",
			initialLevel:    HaltLevelComplete,
			operation:       OpTypeGovernance,
			expectedAllowed: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			err := setHaltLevel(tc.initialLevel)
			uassert.NoError(t, err)

			// when
			allowed := IsAllowedWithdraw(tc.operation)

			// then
			uassert.Equal(t, allowed, tc.expectedAllowed)
		})
	}
}

// Test SetHaltLevel with authorization
func TestHalt_SetHaltLevel_WithAuthorization(t *testing.T) {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)

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
			expectedAbortMessage: "caller g1unauthorized is not admin or governance",
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

				for op, expectedOption := range expectedConfig {
					actualOption := config.get(op)
					uassert.Equal(t, actualOption.access, expectedOption.access)
					uassert.Equal(t, actualOption.withdraw, expectedOption.withdraw)
				}
			}
		})
	}
}

// Test SetOperationStatus with authorization
func TestHalt_SetOperationStatus_WithAuthorization(t *testing.T) {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)

	tests := []struct {
		name                 string
		callerAddress        std.Address
		operationType        OpType
		enabled              bool
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:                 "Success with admin realm",
			callerAddress:        adminAddr,
			operationType:        OpTypePool,
			enabled:              false,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "Success with governance realm",
			callerAddress:        govAddr,
			operationType:        OpTypeRouter,
			enabled:              true,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "Fail with unauthorized realm",
			callerAddress:        std.Address("g1unauthorized"),
			operationType:        OpTypePool,
			enabled:              true,
			expectedHasAbort:     true,
			expectedAbortMessage: "caller g1unauthorized is not admin or governance",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			testing.SetRealm(std.NewUserRealm(tc.callerAddress))

			// when/then
			if tc.expectedHasAbort {
				uassert.AbortsWithMessage(t, tc.expectedAbortMessage, func() {
					SetOperationStatus(cross, tc.operationType, tc.enabled)
				})
			} else {
				SetOperationStatus(cross, tc.operationType, tc.enabled)

				// Verify the operation status was set correctly
				config := GetHaltConfig()
				option := config.get(tc.operationType)
				uassert.Equal(t, option.access, tc.enabled)
				uassert.Equal(t, option.withdraw, tc.enabled)
			}
		})
	}
}

// Test SetOperationAccessStatus with authorization
func TestHalt_SetOperationAccessStatus_WithAuthorization(t *testing.T) {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)

	tests := []struct {
		name                 string
		callerAddress        std.Address
		operationType        OpType
		enabled              bool
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:                 "Success with admin realm",
			callerAddress:        adminAddr,
			operationType:        OpTypePool,
			enabled:              false,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "Success with governance realm",
			callerAddress:        govAddr,
			operationType:        OpTypeRouter,
			enabled:              true,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "Fail with unauthorized realm",
			callerAddress:        std.Address("g1unauthorized"),
			operationType:        OpTypePool,
			enabled:              true,
			expectedHasAbort:     true,
			expectedAbortMessage: "caller g1unauthorized is not admin or governance",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			testing.SetRealm(std.NewUserRealm(tc.callerAddress))

			// when/then
			if tc.expectedHasAbort {
				uassert.AbortsWithMessage(t, tc.expectedAbortMessage, func() {
					SetOperationAccessStatus(cross, tc.operationType, tc.enabled)
				})
			} else {
				// Set initial state
				initialOption := &HaltOption{access: !tc.enabled, withdraw: true}
				haltConfig.set(tc.operationType, initialOption)

				SetOperationAccessStatus(cross, tc.operationType, tc.enabled)

				// Verify only access status was changed
				config := GetHaltConfig()
				option := config.get(tc.operationType)
				uassert.Equal(t, option.access, tc.enabled)
				uassert.Equal(t, option.withdraw, true) // Should remain unchanged
			}
		})
	}
}

// Test SetOperationWithdrawStatus with authorization
func TestHalt_SetOperationWithdrawStatus_WithAuthorization(t *testing.T) {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)

	tests := []struct {
		name                 string
		callerAddress        std.Address
		operationType        OpType
		enabled              bool
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:                 "Success with admin realm",
			callerAddress:        adminAddr,
			operationType:        OpTypePool,
			enabled:              false,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "Success with governance realm",
			callerAddress:        govAddr,
			operationType:        OpTypeRouter,
			enabled:              true,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "Fail with unauthorized realm",
			callerAddress:        std.Address("g1unauthorized"),
			operationType:        OpTypePool,
			enabled:              true,
			expectedHasAbort:     true,
			expectedAbortMessage: "caller g1unauthorized is not admin or governance",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			testing.SetRealm(std.NewUserRealm(tc.callerAddress))

			// when/then
			if tc.expectedHasAbort {
				uassert.AbortsWithMessage(t, tc.expectedAbortMessage, func() {
					SetOperationWithdrawStatus(cross, tc.operationType, tc.enabled)
				})
			} else {
				// Set initial state
				initialOption := &HaltOption{access: true, withdraw: !tc.enabled}
				haltConfig.set(tc.operationType, initialOption)

				SetOperationWithdrawStatus(cross, tc.operationType, tc.enabled)

				// Verify only withdraw status was changed
				config := GetHaltConfig()
				option := config.get(tc.operationType)
				uassert.Equal(t, option.access, true) // Should remain unchanged
				uassert.Equal(t, option.withdraw, tc.enabled)
			}
		})
	}
}

// Test comprehensive integration scenarios
func TestHalt_IntegrationScenarios(t *testing.T) {
	tests := []struct {
		name                    string
		initialLevel            HaltLevel
		customOperations        map[OpType]*HaltOption
		testOperations          []OpType
		expectedHalted          bool
		expectedAccessAllowed   map[OpType]bool
		expectedWithdrawAllowed map[OpType]bool
	}{
		{
			name:         "Emergency with custom overrides",
			initialLevel: HaltLevelEmergency,
			customOperations: map[OpType]*HaltOption{
				OpTypePool: &HaltOption{access: true, withdraw: false}, // Override to allow access
			},
			testOperations: []OpType{OpTypePool, OpTypeRouter},
			expectedHalted: true, // Router is still halted
			expectedAccessAllowed: map[OpType]bool{
				OpTypePool:   true,  // Custom override
				OpTypeRouter: false, // Emergency default
			},
			expectedWithdrawAllowed: map[OpType]bool{
				OpTypePool:   false, // Custom override
				OpTypeRouter: true,  // Emergency default
			},
		},
		{
			name:         "Safe mode with selective disabling",
			initialLevel: HaltLevelSafeMode,
			customOperations: map[OpType]*HaltOption{
				OpTypeGovernance: &HaltOption{access: false, withdraw: false}, // isable governance
			},
			testOperations: []OpType{OpTypeGovernance},
			expectedHalted: true, // Governance isabled
			expectedAccessAllowed: map[OpType]bool{
				OpTypeGovernance: false, // Custom override
				OpTypePool:       true,  // Safe mode default
			},
			expectedWithdrawAllowed: map[OpType]bool{
				OpTypeGovernance: false, // Custom override
				OpTypePool:       false, // Safe mode default
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
			for op, option := range tc.customOperations {
				haltConfig.set(op, option)
			}

			// Test IsHalted
			halted := isHalted(tc.testOperations...)
			uassert.Equal(t, halted, tc.expectedHalted)

			// Test individual access permissions
			for op, expected := range tc.expectedAccessAllowed {
				allowed := IsAllowedAccess(op)
				uassert.Equal(t, allowed, expected)
			}

			// Test individual withdraw permissions
			for op, expected := range tc.expectedWithdrawAllowed {
				allowed := IsAllowedWithdraw(op)
				uassert.Equal(t, allowed, expected)
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
		haltConfig.get(OpTypePool).disableAll()

		// Both should be independent of internal state and each other
		uassert.Equal(t, haltConfig.get(OpTypePool).access, false)
		uassert.Equal(t, configByGetter.get(OpTypePool).access, true)
	})

	t.Run("IsHalted with no operations", func(t *testing.T) {
		cleanup()
		err := setHaltLevel(HaltLevelComplete)
		uassert.NoError(t, err)

		// Empty operation list should return false
		halted := isHalted()
		uassert.Equal(t, halted, false)
	})

	t.Run("Multiple halt level changes", func(t *testing.T) {
		cleanup()

		// Start with emergency
		err := setHaltLevel(HaltLevelEmergency)
		uassert.NoError(t, err)
		uassert.Equal(t, IsAllowedAccess(OpTypePool), false)

		// Change to none
		err = setHaltLevel(HaltLevelNone)
		uassert.NoError(t, err)
		uassert.Equal(t, IsAllowedAccess(OpTypePool), true)

		// Change to complete
		err = setHaltLevel(HaltLevelComplete)
		uassert.NoError(t, err)
		uassert.Equal(t, IsAllowedAccess(OpTypePool), false)
		uassert.Equal(t, IsAllowedWithdraw(OpTypePool), false)
	})
}

// Test helpers
func cleanup() {
	haltConfig = newNoneConfig()
}
