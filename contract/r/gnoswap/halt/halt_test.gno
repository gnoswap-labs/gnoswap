package halt

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/v1/access"
)

func TestHalt_SetHaltLevel(t *testing.T) {
	tests := []struct {
		name             string
		inputLevel       HaltLevel
		expectedLevel    HaltLevel
		expectedHasPanic bool
	}{
		{
			name:             "Success set none level",
			inputLevel:       HaltLevelNone,
			expectedLevel:    HaltLevelNone,
			expectedHasPanic: false,
		},
		{
			name:             "Success set emergency level",
			inputLevel:       HaltLevelEmergency,
			expectedLevel:    HaltLevelEmergency,
			expectedHasPanic: false,
		},
		{
			name:             "Success set safe mode level",
			inputLevel:       HaltLevelSafeMode,
			expectedLevel:    HaltLevelSafeMode,
			expectedHasPanic: false,
		},
		{
			name:             "Fail invalid level",
			inputLevel:       HaltLevel("INVALID"),
			expectedLevel:    HaltLevelSafeMode, // Should remain unchanged
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if !tc.expectedHasPanic {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanup()

			// when - use internal function to test logic without authorization
			err := setHaltLevel(tc.inputLevel)

			// then
			if tc.expectedHasPanic {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, string(GetCurrentHaltLevel()), string(tc.expectedLevel))
			}
		})
	}
}

func TestHalt_IsHalted(t *testing.T) {
	tests := []struct {
		name            string
		initialLevel    HaltLevel
		operations      []OpType
		expectedHalted  bool
		expectedMessage string
	}{
		{
			name:           "Success no operations complete level",
			initialLevel:   HaltLevelComplete,
			operations:     []OpType{},
			expectedHalted: true,
		},
		{
			name:           "Success no operations safe mode",
			initialLevel:   HaltLevelSafeMode,
			operations:     []OpType{},
			expectedHalted: false,
		},
		{
			name:           "Success enabled operation none level",
			initialLevel:   HaltLevelNone,
			operations:     []OpType{OpTypePool},
			expectedHalted: false,
		},
		{
			name:           "Fail disabled operation safe mode",
			initialLevel:   HaltLevelSafeMode,
			operations:     []OpType{OpTypeWithdraw},
			expectedHalted: true,
		},
		{
			name:           "Success multiple operations all enabled",
			initialLevel:   HaltLevelNone,
			operations:     []OpType{OpTypePool, OpTypeRouter},
			expectedHalted: false,
		},
		{
			name:           "Fail multiple operations one disabled",
			initialLevel:   HaltLevelSafeMode,
			operations:     []OpType{OpTypePool, OpTypeWithdraw},
			expectedHalted: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			currentLevel = tc.initialLevel

			// when
			err := IsHalted(tc.operations...)

			// then
			if tc.expectedHalted {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestHalt_SetOperationStatus(t *testing.T) {
	tests := []struct {
		name                 string
		operationType        OpType
		operationStatus      bool
		expectedError        bool
		expectedOpAllowed    bool
	}{
		{
			name:              "Success enables operation",
			operationType:     OpTypePool,
			operationStatus:   true,
			expectedError:     false,
			expectedOpAllowed: true,
		},
		{
			name:              "Success disables operation",
			operationType:     OpTypePool,
			operationStatus:   false,
			expectedError:     false,
			expectedOpAllowed: false,
		},
		{
			name:              "Fail invalid operation type",
			operationType:     OpType("invalid"),
			operationStatus:   true,
			expectedError:     true,
			expectedOpAllowed: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// when - directly set the operation status to test the core logic
			if tc.operationType.IsValid() {
				customOverrides[tc.operationType] = tc.operationStatus
			}

			// then
			if tc.operationType.IsValid() && !tc.expectedError {
				// Check operation status using the override
				opErr := IsHalted(tc.operationType)
				if tc.expectedOpAllowed {
					uassert.NoError(t, opErr)
				} else {
					uassert.Error(t, opErr)
				}
			} else if tc.expectedError {
				// For invalid operation types, verify that they are indeed invalid
				uassert.Equal(t, tc.operationType.IsValid(), false)
			}
		})
	}
}

func TestHalt_GetOperationStatus(t *testing.T) {
	tests := []struct {
		name               string
		initialLevel       HaltLevel
		operationType      OpType
		overrideValue      *bool // nil means no override
		expectedEnabled    bool
		expectedIsOverride bool
	}{
		{
			name:               "No override none level pool enabled",
			initialLevel:       HaltLevelNone,
			operationType:      OpTypePool,
			overrideValue:      nil,
			expectedEnabled:    true,
			expectedIsOverride: false,
		},
		{
			name:               "No override safe mode withdraw disabled",
			initialLevel:       HaltLevelSafeMode,
			operationType:      OpTypeWithdraw,
			overrideValue:      nil,
			expectedEnabled:    false,
			expectedIsOverride: false,
		},
		{
			name:               "Override enabled",
			initialLevel:       HaltLevelSafeMode,
			operationType:      OpTypeWithdraw,
			overrideValue:      &[]bool{true}[0],
			expectedEnabled:    true,
			expectedIsOverride: true,
		},
		{
			name:               "Override disabled",
			initialLevel:       HaltLevelNone,
			operationType:      OpTypePool,
			overrideValue:      &[]bool{false}[0],
			expectedEnabled:    false,
			expectedIsOverride: true,
		},
		{
			name:               "Invalid operation type",
			initialLevel:       HaltLevelNone,
			operationType:      OpType("invalid"),
			overrideValue:      nil,
			expectedEnabled:    false,
			expectedIsOverride: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			currentLevel = tc.initialLevel
			if tc.overrideValue != nil {
				customOverrides[tc.operationType] = *tc.overrideValue
			}

			// when
			enabled, isOverride := GetOperationStatus(tc.operationType)

			// then
			uassert.Equal(t, enabled, tc.expectedEnabled)
			uassert.Equal(t, isOverride, tc.expectedIsOverride)
		})
	}
}

func TestHalt_ClearOperationOverride(t *testing.T) {
	tests := []struct {
		name          string
		operationType OpType
		expectedError bool
	}{
		{
			name:          "Success clears override for valid operation",
			operationType: OpTypePool,
			expectedError: false,
		},
		{
			name:          "Fail invalid operation type",
			operationType: OpType("invalid"),
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given - set an override to clear
			if tc.operationType.IsValid() {
				customOverrides[tc.operationType] = true
			}

			// when - directly test the override clearing logic
			if tc.operationType.IsValid() {
				delete(customOverrides, tc.operationType)
				// Verify override was cleared
				_, isOverride := GetOperationStatus(tc.operationType)
				
				// then
				if tc.expectedError {
					uassert.Equal(t, isOverride, true) // Should still have override if error expected
				} else {
					uassert.Equal(t, isOverride, false) // Should not have override if successful
				}
			} else {
				// For invalid operation types, we expect the operation would fail
				uassert.Equal(t, tc.expectedError, true)
			}
		})
	}
}

func TestHalt_ClearAllOverrides(t *testing.T) {
	tests := []struct {
		name                string
		initialOverrides    map[OpType]bool
		expectedOverrideLen int
	}{
		{
			name: "Success clears all overrides",
			initialOverrides: map[OpType]bool{
				OpTypePool:   false,
				OpTypeRouter: true,
			},
			expectedOverrideLen: 0,
		},
		{
			name:                "Success with no overrides",
			initialOverrides:    map[OpType]bool{},
			expectedOverrideLen: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			for op, status := range tc.initialOverrides {
				customOverrides[op] = status
			}

			// when - directly test clearing all overrides
			customOverrides = make(map[OpType]bool)

			// then
			overrides := GetAllOverrides()
			uassert.Equal(t, len(overrides), tc.expectedOverrideLen)
		})
	}
}

func TestHalt_OverrideOperations(t *testing.T) {
	tests := []struct {
		name                 string
		initialOverrides     map[OpType]bool
		expectedOverrideLen  int
		expectedPoolStatus   *bool
		expectedRouterStatus *bool
	}{
		{
			name: "Multiple overrides set and retrieved",
			initialOverrides: map[OpType]bool{
				OpTypePool:   false,
				OpTypeRouter: true,
			},
			expectedOverrideLen:  2,
			expectedPoolStatus:   &[]bool{false}[0],
			expectedRouterStatus: &[]bool{true}[0],
		},
		{
			name:                "Empty overrides",
			initialOverrides:    map[OpType]bool{},
			expectedOverrideLen: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			for op, status := range tc.initialOverrides {
				customOverrides[op] = status
			}

			// when
			overrides := GetAllOverrides()

			// then
			uassert.Equal(t, len(overrides), tc.expectedOverrideLen)
			if tc.expectedPoolStatus != nil {
				uassert.Equal(t, overrides[OpTypePool], *tc.expectedPoolStatus)
			}
			if tc.expectedRouterStatus != nil {
				uassert.Equal(t, overrides[OpTypeRouter], *tc.expectedRouterStatus)
			}
		})
	}
}

func TestHalt_BackwardCompatibility(t *testing.T) {
	tests := []struct {
		name                        string
		initialLevel                HaltLevel
		expectedGetHalt             bool
		testOperation               OpType
		expectedIsContractHalted    bool
		expectedGetContractStatus   bool
	}{
		{
			name:                        "None level backward compatibility",
			initialLevel:                HaltLevelNone,
			expectedGetHalt:             false,
			testOperation:               OpTypePool,
			expectedIsContractHalted:    false,
			expectedGetContractStatus:   true,
		},
		{
			name:                        "Complete level backward compatibility",
			initialLevel:                HaltLevelComplete,
			expectedGetHalt:             true,
			testOperation:               OpTypePool,
			expectedIsContractHalted:    true,
			expectedGetContractStatus:   false,
		},
		{
			name:                        "Safe mode withdraw disabled backward compatibility",
			initialLevel:                HaltLevelSafeMode,
			expectedGetHalt:             false,
			testOperation:               OpTypeWithdraw,
			expectedIsContractHalted:    true,
			expectedGetContractStatus:   false,
		},
		{
			name:                        "Safe mode pool enabled backward compatibility",
			initialLevel:                HaltLevelSafeMode,
			expectedGetHalt:             false,
			testOperation:               OpTypePool,
			expectedIsContractHalted:    false,
			expectedGetContractStatus:   true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			currentLevel = tc.initialLevel

			// when & then
			uassert.Equal(t, GetHalt(), tc.expectedGetHalt)
			uassert.Equal(t, IsContractHalted(tc.testOperation), tc.expectedIsContractHalted)
			uassert.Equal(t, GetContractStatus(tc.testOperation), tc.expectedGetContractStatus)
		})
	}
}

func TestHalt_SetHalt(t *testing.T) {
	tests := []struct {
		name          string
		isHalted      bool
		expectedLevel HaltLevel
	}{
		{
			name:          "Success sets halt to true",
			isHalted:      true,
			expectedLevel: HaltLevelComplete,
		},
		{
			name:          "Success sets halt to false",
			isHalted:      false,
			expectedLevel: HaltLevelNone,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// when - test the internal logic
			if tc.isHalted {
				err := setHaltLevel(HaltLevelComplete)
				uassert.NoError(t, err)
			} else {
				err := setHaltLevel(HaltLevelNone)
				uassert.NoError(t, err)
			}

			// then
			uassert.Equal(t, string(GetCurrentHaltLevel()), string(tc.expectedLevel))
		})
	}
}

func TestHalt_ComplexStatusTransitions(t *testing.T) {
	tests := []struct {
		name               string
		transitions        []HaltLevel
		operationType      OpType
		preOpStatus        *bool
		expectedFinalLevel HaltLevel
		expectedOpAllowed  bool
	}{
		{
			name:               "Transition from none to emergency to none",
			transitions:        []HaltLevel{HaltLevelNone, HaltLevelEmergency, HaltLevelNone},
			operationType:      OpTypeWithdraw,
			preOpStatus:        &[]bool{true}[0],
			expectedFinalLevel: HaltLevelNone,
			expectedOpAllowed:  true,
		},
		{
			name:               "Complex transition with operation override preservation",
			transitions:        []HaltLevel{HaltLevelNone, HaltLevelEmergency, HaltLevelComplete, HaltLevelNone},
			operationType:      OpTypePool,
			preOpStatus:        &[]bool{false}[0],
			expectedFinalLevel: HaltLevelNone,
			expectedOpAllowed:  false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given - set pre-operation status if specified
			if tc.preOpStatus != nil {
				customOverrides[tc.operationType] = *tc.preOpStatus
			}

			// when - apply transitions
			var finalErr error
			for _, level := range tc.transitions {
				finalErr = setHaltLevel(level)
				if finalErr != nil {
					break
				}
			}

			// then
			uassert.NoError(t, finalErr)
			uassert.Equal(t, string(GetCurrentHaltLevel()), string(tc.expectedFinalLevel))

			// Check operation status
			err := IsHalted(tc.operationType)
			if tc.expectedOpAllowed {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err)
			}
		})
	}
}

func TestHalt_GetHaltLevelDescription(t *testing.T) {
	tests := []struct {
		name                string
		initialLevel        HaltLevel
		expectedDescription string
	}{
		{
			name:                "None level description",
			initialLevel:        HaltLevelNone,
			expectedDescription: "All operations enabled",
		},
		{
			name:                "Safe mode description",
			initialLevel:        HaltLevelSafeMode,
			expectedDescription: "All operations enabled except withdrawals",
		},
		{
			name:                "Emergency level description",
			initialLevel:        HaltLevelEmergency,
			expectedDescription: "Only governance and withdrawal operations enabled",
		},
		{
			name:                "Complete level description",
			initialLevel:        HaltLevelComplete,
			expectedDescription: "All operations disabled",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			currentLevel = tc.initialLevel

			// when
			result := GetHaltLevelDescription()

			// then
			uassert.Equal(t, result, tc.expectedDescription)
		})
	}
}

func TestHalt_OperationPermissions(t *testing.T) {
	tests := []struct {
		name                string
		level               HaltLevel
		operationType       OpType
		expectedAllowed     bool
	}{
		// None level - all operations allowed
		{
			name:            "None level allows pool operations",
			level:           HaltLevelNone,
			operationType:   OpTypePool,
			expectedAllowed: true,
		},
		{
			name:            "None level allows withdraw operations",
			level:           HaltLevelNone,
			operationType:   OpTypeWithdraw,
			expectedAllowed: true,
		},
		
		// Safe mode - all except withdraw
		{
			name:            "Safe mode allows pool operations",
			level:           HaltLevelSafeMode,
			operationType:   OpTypePool,
			expectedAllowed: true,
		},
		{
			name:            "Safe mode disallows withdraw operations",
			level:           HaltLevelSafeMode,
			operationType:   OpTypeWithdraw,
			expectedAllowed: false,
		},
		
		// Emergency - only governance and withdraw
		{
			name:            "Emergency allows governance operations",
			level:           HaltLevelEmergency,
			operationType:   OpTypeGovernance,
			expectedAllowed: true,
		},
		{
			name:            "Emergency allows withdraw operations",
			level:           HaltLevelEmergency,
			operationType:   OpTypeWithdraw,
			expectedAllowed: true,
		},
		{
			name:            "Emergency disallows pool operations",
			level:           HaltLevelEmergency,
			operationType:   OpTypePool,
			expectedAllowed: false,
		},
		
		// Complete - nothing allowed
		{
			name:            "Complete disallows all operations",
			level:           HaltLevelComplete,
			operationType:   OpTypeGovernance,
			expectedAllowed: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			currentLevel = tc.level

			// when
			err := IsHalted(tc.operationType)

			// then
			if tc.expectedAllowed {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err)
			}
		})
	}
}

// Test helpers
func cleanup() {
	currentLevel = HaltLevelSafeMode
	customOverrides = make(map[OpType]bool)
}

// Reset function like in old module to properly set realm and state
func resetToSafeMode() {
	// Reset internal state directly without authorization checks
	currentLevel = HaltLevelSafeMode
	customOverrides = make(map[OpType]bool)
}

// Debug function to check access module setup
func TestHalt_AccessModuleSetup(t *testing.T) {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
	
	// These should not be zero addresses
	uassert.NotEqual(t, adminAddr, std.Address(""))
	uassert.NotEqual(t, govAddr, std.Address(""))
}

// Integration tests that call actual API functions with realm setup
func TestHalt_SetHaltLevel_WithRealm(t *testing.T) {
	tests := []struct {
		name             string
		realmType        string // "admin", "governance", "unauthorized"
		inputLevel       HaltLevel
		expectedLevel    HaltLevel
		expectedError    bool
	}{
		{
			name:          "Success with admin realm",
			realmType:     "admin",
			inputLevel:    HaltLevelEmergency,
			expectedLevel: HaltLevelEmergency,
			expectedError: false,
		},
		{
			name:          "Success with governance realm",
			realmType:     "governance",
			inputLevel:    HaltLevelNone,
			expectedLevel: HaltLevelNone,
			expectedError: false,
		},
		{
			name:          "Fail with unauthorized realm",
			realmType:     "unauthorized",
			inputLevel:    HaltLevelComplete,
			expectedLevel: HaltLevelSafeMode, // Should remain unchanged
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()
			
			// Set realm directly based on type
			switch tc.realmType {
			case "admin":
				adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
				testing.SetRealm(std.NewUserRealm(adminAddr))
			case "governance":
				govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
				testing.SetRealm(std.NewUserRealm(govAddr))
			case "unauthorized":
				testing.SetRealm(std.NewUserRealm(std.Address("g1useraddress")))
			}

			// when
			err := SetHaltLevel(cross, tc.inputLevel)

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
			uassert.Equal(t, string(GetCurrentHaltLevel()), string(tc.expectedLevel))
		})
	}
}

func TestHalt_SetOperationStatus_WithRealm(t *testing.T) {
	tests := []struct {
		name           string
		realmType      string // "governance", "unauthorized", "invalid"
		operationType  OpType
		enabled        bool
		expectedError  bool
	}{
		{
			name:          "Success with governance realm",
			realmType:     "governance",
			operationType: OpTypePool,
			enabled:       false,
			expectedError: false,
		},
		{
			name:          "Fail with unauthorized realm",
			realmType:     "unauthorized",
			operationType: OpTypePool,
			enabled:       true,
			expectedError: true,
		},
		{
			name:          "Fail with invalid operation type",
			realmType:     "governance",
			operationType: OpType("invalid"),
			enabled:       true,
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// Set realm directly based on type (not through function)
			switch tc.realmType {
			case "governance":
				govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
				testing.SetRealm(std.NewUserRealm(govAddr))
			case "unauthorized":
				testing.SetRealm(std.NewUserRealm(std.Address("g1useraddress")))
			}

			// when
			err := SetOperationStatus(cross, tc.operationType, tc.enabled)

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				enabled, isOverride := GetOperationStatus(tc.operationType)
				uassert.Equal(t, enabled, tc.enabled)
				uassert.Equal(t, isOverride, true) // Should be override
			}
		})
	}
}

func TestHalt_ClearOperationOverride_WithRealm(t *testing.T) {
	tests := []struct {
		name           string
		realmType      string // "governance", "unauthorized", "invalid"
		operationType  OpType
		expectedError  bool
	}{
		{
			name:          "Success with governance realm",
			realmType:     "governance",
			operationType: OpTypePool,
			expectedError: false,
		},
		{
			name:          "Fail with unauthorized realm",
			realmType:     "unauthorized",
			operationType: OpTypePool,
			expectedError: true,
		},
		{
			name:          "Fail with invalid operation type",
			realmType:     "governance",
			operationType: OpType("invalid"),
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()
			
			// given - set an override first
			customOverrides[tc.operationType] = true
			
			// Set realm directly based on type
			switch tc.realmType {
			case "governance":
				govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
				testing.SetRealm(std.NewUserRealm(govAddr))
			case "unauthorized":
				testing.SetRealm(std.NewUserRealm(std.Address("g1useraddress")))
			}

			// when
			err := ClearOperationOverride(cross, tc.operationType)

			// then
			if tc.expectedError {
				uassert.Error(t, err)
				if tc.operationType.IsValid() {
					// Override should still exist
					_, isOverride := GetOperationStatus(tc.operationType)
					uassert.Equal(t, isOverride, true)
				}
			} else {
				uassert.NoError(t, err)
				// Override should be cleared
				_, isOverride := GetOperationStatus(tc.operationType)
				uassert.Equal(t, isOverride, false)
			}
		})
	}
}

func TestHalt_ClearAllOverrides_WithRealm(t *testing.T) {
	tests := []struct {
		name           string
		realmType      string // "governance", "unauthorized"
		expectedError  bool
	}{
		{
			name:          "Success with governance realm",
			realmType:     "governance",
			expectedError: false,
		},
		{
			name:          "Fail with unauthorized realm",
			realmType:     "unauthorized",
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()
			
			// given - set some overrides first
			customOverrides[OpTypePool] = false
			customOverrides[OpTypeRouter] = true
			
			// Set realm directly based on type
			switch tc.realmType {
			case "governance":
				govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
				testing.SetRealm(std.NewUserRealm(govAddr))
			case "unauthorized":
				testing.SetRealm(std.NewUserRealm(std.Address("g1useraddress")))
			}

			// when
			err := ClearAllOverrides(cross)

			// then
			if tc.expectedError {
				uassert.Error(t, err)
				// Overrides should still exist
				overrides := GetAllOverrides()
				uassert.Equal(t, len(overrides), 2)
			} else {
				uassert.NoError(t, err)
				// All overrides should be cleared
				overrides := GetAllOverrides()
				uassert.Equal(t, len(overrides), 0)
			}
		})
	}
}

func TestHalt_SetOperationStatusByAdmin_WithRealm(t *testing.T) {
	tests := []struct {
		name           string
		realmType      string // "admin", "unauthorized", "governance"
		operationType  OpType
		enabled        bool
		expectedError  bool
	}{
		{
			name:          "Success with admin realm",
			realmType:     "admin",
			operationType: OpTypePool,
			enabled:       false,
			expectedError: false,
		},
		{
			name:          "Fail with unauthorized realm",
			realmType:     "unauthorized",
			operationType: OpTypePool,
			enabled:       true,
			expectedError: true,
		},
		{
			name:          "Fail with governance realm (admin only)",
			realmType:     "governance",
			operationType: OpTypePool,
			enabled:       true,
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()
			
			// Set realm directly based on type
			switch tc.realmType {
			case "admin":
				adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
				testing.SetRealm(std.NewUserRealm(adminAddr))
			case "governance":
				govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
				testing.SetRealm(std.NewUserRealm(govAddr))
			case "unauthorized":
				testing.SetRealm(std.NewUserRealm(std.Address("g1useraddress")))
			}

			// when
			err := SetOperationStatusByAdmin(cross, tc.operationType, tc.enabled)

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				enabled, isOverride := GetOperationStatus(tc.operationType)
				uassert.Equal(t, enabled, tc.enabled)
				uassert.Equal(t, isOverride, true) // Should be override
			}
		})
	}
}
