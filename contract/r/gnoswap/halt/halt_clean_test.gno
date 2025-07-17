package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// resetHaltState resets the halt state to initial conditions for testing
func resetHaltState() {
	currentHaltLevel = HaltLevelSafeMode
	operationOverrides = make(map[string]bool)
}

func TestHalt_CoreLogicOnly(t *testing.T) {
	// Clean test with state reset
	resetHaltState()

	t.Run("Basic level operations", func(t *testing.T) {
		// Test initial state
		level := GetCurrentHaltLevel()
		uassert.Equal(t, level.String(), "SAFE_MODE")

		// Test level setting without authorization (logic only)
		currentHaltLevel = HaltLevelNone
		uassert.Equal(t, GetCurrentHaltLevel().String(), "NONE")

		currentHaltLevel = HaltLevelComplete
		uassert.Equal(t, GetCurrentHaltLevel().String(), "COMPLETE")

		// Reset for next tests
		currentHaltLevel = HaltLevelSafeMode
	})

	t.Run("Operation status logic", func(t *testing.T) {
		resetHaltState()

		// Test SAFE_MODE behavior
		currentHaltLevel = HaltLevelSafeMode
		uassert.Equal(t, GetOperationStatus("pool"), true)
		uassert.Equal(t, GetOperationStatus("withdraw"), false)

		// Test NONE behavior
		currentHaltLevel = HaltLevelNone
		uassert.Equal(t, GetOperationStatus("pool"), true)
		uassert.Equal(t, GetOperationStatus("withdraw"), true)

		// Test COMPLETE behavior
		currentHaltLevel = HaltLevelComplete
		uassert.Equal(t, GetOperationStatus("pool"), false)
		uassert.Equal(t, GetOperationStatus("withdraw"), false)
	})

	t.Run("Override system logic", func(t *testing.T) {
		resetHaltState()
		currentHaltLevel = HaltLevelSafeMode

		// Test override setting (logic only, no authorization)
		operationOverrides["withdraw"] = true
		uassert.Equal(t, GetOperationStatus("withdraw"), true)

		// Test clearing overrides
		delete(operationOverrides, "withdraw")
		uassert.Equal(t, GetOperationStatus("withdraw"), false)
	})

	t.Run("IsHalted logic", func(t *testing.T) {
		resetHaltState()

		// Test SAFE_MODE
		currentHaltLevel = HaltLevelSafeMode
		err := IsHalted()
		uassert.NoError(t, err) // Should not error with no operations

		err = IsHalted("pool")
		uassert.NoError(t, err) // Pool allowed in SAFE_MODE

		err = IsHalted("withdraw")
		uassert.Error(t, err) // Withdraw blocked in SAFE_MODE

		// Test COMPLETE
		currentHaltLevel = HaltLevelComplete
		err = IsHalted()
		uassert.Error(t, err) // Should error

		err = IsHalted("pool")
		uassert.Error(t, err) // All operations blocked
	})

	t.Run("Backward compatibility logic", func(t *testing.T) {
		resetHaltState()

		// Test NONE level
		currentHaltLevel = HaltLevelNone
		uassert.Equal(t, GetHalt(), false)
		uassert.Equal(t, IsContractHalted("pool"), false)
		uassert.Equal(t, GetContractStatus("pool"), true)

		// Test SAFE_MODE level
		currentHaltLevel = HaltLevelSafeMode
		uassert.Equal(t, GetHalt(), false) // Not completely halted
		uassert.Equal(t, IsContractHalted("pool"), false)
		uassert.Equal(t, GetContractStatus("pool"), true)
		uassert.Equal(t, IsContractHalted("withdraw"), true)
		uassert.Equal(t, GetContractStatus("withdraw"), false)

		// Test COMPLETE level
		currentHaltLevel = HaltLevelComplete
		uassert.Equal(t, GetHalt(), true)
		uassert.Equal(t, IsContractHalted("pool"), true)
		uassert.Equal(t, GetContractStatus("pool"), false)
	})

	t.Run("Type validation", func(t *testing.T) {
		resetHaltState()

		// Test valid operations
		validOps := []string{"pool", "position", "router", "staker", "launchpad", "withdraw", "governance", "emergency"}
		for _, op := range validOps {
			status := GetOperationStatus(op)
			// Should not panic, status can be true or false
			_ = status
		}

		// Test invalid operations (should use default behavior)
		status := GetOperationStatus("invalid_operation")
		_ = status // Should not panic
	})

	t.Run("String methods", func(t *testing.T) {
		resetHaltState()

		levels := []HaltLevel{HaltLevelNone, HaltLevelSafeMode, HaltLevelEmergency, HaltLevelComplete}
		for _, level := range levels {
			str := level.String()
			uassert.NotEqual(t, str, "")
		}
	})

	t.Run("All operations coverage", func(t *testing.T) {
		resetHaltState()

		// Test all operation types work with different halt levels
		operations := []string{"pool", "position", "router", "staker", "launchpad", "withdraw", "governance", "emergency"}
		levels := []HaltLevel{HaltLevelNone, HaltLevelSafeMode, HaltLevelEmergency, HaltLevelComplete}

		for _, level := range levels {
			currentHaltLevel = level
			for _, op := range operations {
				// Should not panic
				status := GetOperationStatus(op)
				_ = status

				// Should not panic
				err := IsHalted(op)
				_ = err
			}
		}
	})

	// Final reset
	resetHaltState()
}

func TestHalt_ConfigurationConsistency(t *testing.T) {
	testCases := []struct {
		name  string
		level HaltLevel
	}{
		{"NONE", HaltLevelNone},
		{"SAFE_MODE", HaltLevelSafeMode},
		{"EMERGENCY", HaltLevelEmergency},
		{"COMPLETE", HaltLevelComplete},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			resetHaltState()
			currentHaltLevel = tc.level

			// Get configuration
			config := getHaltLevelConfig(tc.level)

			// Test each operation matches expected status
			operations := []string{"pool", "position", "router", "staker", "launchpad", "withdraw", "governance", "emergency"}
			for _, op := range operations {
				expectedStatus := config[op]
				actualStatus := GetOperationStatus(op)
				if expectedStatus != actualStatus {
					t.Errorf("Operation %s: expected %v, got %v for level %s", op, expectedStatus, actualStatus, tc.name)
				}
			}

			// Test description is not empty
			description := GetHaltLevelDescription(tc.level)
			if description == "" {
				t.Errorf("Description for level %s should not be empty", tc.name)
			}
		})
	}
}
