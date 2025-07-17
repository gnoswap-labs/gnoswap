package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestHalt_SetHaltLevelInternal(t *testing.T) {
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
			name:             "Fail invalid level",
			inputLevel:       HaltLevel("INVALID"),
			expectedLevel:    HaltLevelSafeMode, // Should remain unchanged
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				recover() // Just recover, don't check message for simplicity
			}()

			cleanup()

			// when
			setHaltLevel(tc.inputLevel)

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, string(GetCurrentHaltLevel()), string(tc.expectedLevel))
			}
		})
	}
}

func TestHalt_IsHalted(t *testing.T) {
	cleanup()

	// Test no operations check complete level
	currentLevel = HaltLevelComplete
	err := IsHalted()
	uassert.NotEqual(t, err, nil)

	// Test no operations check safe mode
	currentLevel = HaltLevelSafeMode
	err = IsHalted()
	uassert.Equal(t, err, nil)

	// Test enabled operation
	currentLevel = HaltLevelNone
	err = IsHalted(OpTypePool)
	uassert.Equal(t, err, nil)

	// Test disabled operation safe mode
	currentLevel = HaltLevelSafeMode
	err = IsHalted(OpTypeWithdraw)
	uassert.NotEqual(t, err, nil)
}

func TestHalt_GetOperationStatus(t *testing.T) {
	cleanup()

	// Test no override, none level, pool enabled
	currentLevel = HaltLevelNone
	enabled, isOverride := GetOperationStatus(OpTypePool)
	uassert.Equal(t, enabled, true)
	uassert.Equal(t, isOverride, false)

	// Test no override, safe mode, withdraw disabled
	currentLevel = HaltLevelSafeMode
	enabled, isOverride = GetOperationStatus(OpTypeWithdraw)
	uassert.Equal(t, enabled, false)
	uassert.Equal(t, isOverride, false)

	// Test override enabled
	customOverrides[OpTypeWithdraw] = true
	enabled, isOverride = GetOperationStatus(OpTypeWithdraw)
	uassert.Equal(t, enabled, true)
	uassert.Equal(t, isOverride, true)

	// Test override disabled
	currentLevel = HaltLevelNone
	customOverrides[OpTypePool] = false
	enabled, isOverride = GetOperationStatus(OpTypePool)
	uassert.Equal(t, enabled, false)
	uassert.Equal(t, isOverride, true)
}

func TestHalt_OverrideOperations(t *testing.T) {
	cleanup()

	// Test setting overrides directly
	customOverrides[OpTypePool] = false
	customOverrides[OpTypeRouter] = true

	// Test GetAllOverrides
	overrides := GetAllOverrides()
	uassert.Equal(t, len(overrides), 2)
	uassert.Equal(t, overrides[OpTypePool], false)
	uassert.Equal(t, overrides[OpTypeRouter], true)

	// Test clearing all overrides
	customOverrides = make(map[OpType]bool)
	overrides = GetAllOverrides()
	uassert.Equal(t, len(overrides), 0)
}

func TestHalt_BackwardCompatibility(t *testing.T) {
	cleanup()

	// Test GetHalt with different levels
	currentLevel = HaltLevelNone
	uassert.Equal(t, GetHalt(), false)

	currentLevel = HaltLevelComplete
	uassert.Equal(t, GetHalt(), true)

	// Test IsContractHalted
	currentLevel = HaltLevelSafeMode
	uassert.Equal(t, IsContractHalted(OpTypeWithdraw), true) // disabled in safe mode
	uassert.Equal(t, IsContractHalted(OpTypePool), false)    // enabled in safe mode

	// Test GetContractStatus
	enabled := GetContractStatus(OpTypeWithdraw)
	uassert.Equal(t, enabled, false) // disabled in safe mode

	enabled = GetContractStatus(OpTypePool)
	uassert.Equal(t, enabled, true) // enabled in safe mode
}

func TestHalt_GetHaltLevelDescription(t *testing.T) {
	cleanup()

	currentLevel = HaltLevelNone
	result := GetHaltLevelDescription()
	uassert.Equal(t, result, "All operations enabled")

	currentLevel = HaltLevelSafeMode
	result = GetHaltLevelDescription()
	uassert.Equal(t, result, "All operations enabled except withdrawals")

	currentLevel = HaltLevelEmergency
	result = GetHaltLevelDescription()
	uassert.Equal(t, result, "Only governance and withdrawal operations enabled")

	currentLevel = HaltLevelComplete
	result = GetHaltLevelDescription()
	uassert.Equal(t, result, "All operations disabled")
}

// Test helpers
func cleanup() {
	currentLevel = HaltLevelSafeMode
	customOverrides = make(map[OpType]bool)
}
