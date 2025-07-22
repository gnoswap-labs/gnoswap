package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// Test HaltConfig methods
func TestHaltConfig_IsHalted(t *testing.T) {
	tests := []struct {
		name     string
		config   HaltConfig
		op       OpType
		expected bool
	}{
		{
			name:     "Halted operation",
			config:   HaltConfig{OpTypePool: true},
			op:       OpTypePool,
			expected: true,
		},
		{
			name:     "Not halted operation",
			config:   HaltConfig{OpTypePool: false},
			op:       OpTypePool,
			expected: false,
		},
		{
			name:     "Non-existing operation",
			config:   HaltConfig{},
			op:       OpTypePool,
			expected: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.config.IsHalted(tc.op)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestHaltConfig_Get(t *testing.T) {
	tests := []struct {
		name          string
		config        HaltConfig
		op            OpType
		expectedValue bool
		expectedError bool
	}{
		{
			name:          "Get halted operation",
			config:        HaltConfig{OpTypePool: true},
			op:            OpTypePool,
			expectedValue: true,
			expectedError: false,
		},
		{
			name:          "Get not halted operation",
			config:        HaltConfig{OpTypePool: false},
			op:            OpTypePool,
			expectedValue: false,
			expectedError: false,
		},
		{
			name:          "Get non-existing operation",
			config:        HaltConfig{},
			op:            OpTypePool,
			expectedValue: false,
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result, err := tc.config.get(tc.op)

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, result, tc.expectedValue)
			}
		})
	}
}

func TestHaltConfig_Set(t *testing.T) {
	tests := []struct {
		name          string
		config        HaltConfig
		op            OpType
		value         bool
		expectedError bool
	}{
		{
			name:          "Set valid operation to halted",
			config:        make(HaltConfig),
			op:            OpTypePool,
			value:         true,
			expectedError: false,
		},
		{
			name:          "Set valid operation to not halted",
			config:        make(HaltConfig),
			op:            OpTypePool,
			value:         false,
			expectedError: false,
		},
		{
			name:          "Set invalid operation",
			config:        make(HaltConfig),
			op:            OpType("invalid"),
			value:         true,
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			err := tc.config.set(tc.op, tc.value)

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				// Verify the value was set correctly
				actualValue, getErr := tc.config.get(tc.op)
				uassert.NoError(t, getErr)
				uassert.Equal(t, actualValue, tc.value)
			}
		})
	}
}

func TestHaltConfig_Clone(t *testing.T) {
	// given
	original := HaltConfig{
		OpTypePool:   true,
		OpTypeRouter: false,
		OpTypeStaker: true,
	}

	// when
	cloned := original.Clone()

	// then
	uassert.Equal(t, len(cloned), len(original))

	for op, halted := range original {
		clonedValue, err := cloned.get(op)
		uassert.NoError(t, err)
		uassert.Equal(t, clonedValue, halted)
	}

	// Verify independence by modifying original
	err := original.set(OpTypePool, false)
	uassert.NoError(t, err)
	
	clonedValue, err := cloned.get(OpTypePool)
	uassert.NoError(t, err)
	uassert.Equal(t, clonedValue, true) // Should still be true (halted) in the clone
}

// Test config factory functions
func TestNewNoneConfig(t *testing.T) {
	// when
	config := newNoneConfig()

	// then
	allOperations := []OpType{
		OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter,
		OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance, OpTypeGovStaker,
		OpTypeXGns, OpTypeCommunityPool, OpTypeEmission, OpTypeWithdraw,
	}

	for _, op := range allOperations {
		halted, err := config.get(op)
		uassert.NoError(t, err)
		uassert.Equal(t, halted, false) // None config: nothing is halted
	}
}

func TestNewSafeModeConfig(t *testing.T) {
	// when
	config := newSafeModeConfig()

	// then
	// Most operations should not be halted
	notHaltedOperations := []OpType{
		OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter,
		OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance, OpTypeGovStaker,
		OpTypeXGns, OpTypeCommunityPool, OpTypeEmission,
	}

	for _, op := range notHaltedOperations {
		halted, err := config.get(op)
		uassert.NoError(t, err)
		uassert.Equal(t, halted, false)
	}

	// Withdraw should be halted
	withdrawHalted, err := config.get(OpTypeWithdraw)
	uassert.NoError(t, err)
	uassert.Equal(t, withdrawHalted, true)
}

func TestNewEmergencyConfig(t *testing.T) {
	// when
	config := newEmergencyConfig()

	// then
	// Governance should not be halted
	govHalted, err := config.get(OpTypeGovernance)
	uassert.NoError(t, err)
	uassert.Equal(t, govHalted, false)

	// Withdraw should not be halted
	withdrawHalted, err := config.get(OpTypeWithdraw)
	uassert.NoError(t, err)
	uassert.Equal(t, withdrawHalted, false)

	// All other operations should be halted
	haltedOperations := []OpType{
		OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter,
		OpTypeStaker, OpTypeLaunchpad, OpTypeGovStaker,
		OpTypeXGns, OpTypeCommunityPool, OpTypeEmission,
	}

	for _, op := range haltedOperations {
		halted, err := config.get(op)
		uassert.NoError(t, err)
		uassert.Equal(t, halted, true)
	}
}

func TestNewCompleteConfig(t *testing.T) {
	// when
	config := newCompleteConfig()

	// then
	allOperations := []OpType{
		OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter,
		OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance, OpTypeGovStaker,
		OpTypeXGns, OpTypeCommunityPool, OpTypeEmission, OpTypeWithdraw,
	}

	for _, op := range allOperations {
		halted, err := config.get(op)
		uassert.NoError(t, err)
		uassert.Equal(t, halted, true) // Complete config: everything is halted
	}
}

func TestConfig_AllConfigLevelsIntegration(t *testing.T) {
	tests := []struct {
		name          string
		configFunc    func() HaltConfig
		expectedState map[OpType]bool
	}{
		{
			name:       "None config halts nothing",
			configFunc: newNoneConfig,
			expectedState: map[OpType]bool{
				OpTypePool:       false,
				OpTypeGovernance: false,
				OpTypeRouter:     false,
				OpTypeWithdraw:   false,
			},
		},
		{
			name:       "Safe mode halts withdraw only",
			configFunc: newSafeModeConfig,
			expectedState: map[OpType]bool{
				OpTypePool:       false,
				OpTypeGovernance: false,
				OpTypeRouter:     false,
				OpTypeWithdraw:   true,
			},
		},
		{
			name:       "Emergency halts most except governance and withdraw",
			configFunc: newEmergencyConfig,
			expectedState: map[OpType]bool{
				OpTypePool:       true,
				OpTypeGovernance: false,
				OpTypeRouter:     true,
				OpTypeWithdraw:   false,
			},
		},
		{
			name:       "Complete halts all",
			configFunc: newCompleteConfig,
			expectedState: map[OpType]bool{
				OpTypePool:       true,
				OpTypeGovernance: true,
				OpTypeRouter:     true,
				OpTypeWithdraw:   true,
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			config := tc.configFunc()

			// then
			for op, expected := range tc.expectedState {
				halted, err := config.get(op)
				uassert.NoError(t, err)
				uassert.Equal(t, halted, expected)
			}
		})
	}
}

// Test edge cases and validation
func TestHaltConfig_EdgeCases(t *testing.T) {
	t.Run("Empty config", func(t *testing.T) {
		config := make(HaltConfig)
		
		// Non-existing operation should return false and error
		halted, err := config.get(OpTypePool)
		uassert.Error(t, err)
		uassert.Equal(t, halted, false)
	})

	t.Run("IsHalted with non-existing operation", func(t *testing.T) {
		config := make(HaltConfig)
		
		// IsHalted should return false for non-existing operations
		halted := config.IsHalted(OpTypePool)
		uassert.Equal(t, halted, false)
	})

	t.Run("Set and get consistency", func(t *testing.T) {
		config := make(HaltConfig)
		
		// Set a value to halted
		err := config.set(OpTypePool, true)
		uassert.NoError(t, err)
		
		// Get the value back
		halted, err := config.get(OpTypePool)
		uassert.NoError(t, err)
		uassert.Equal(t, halted, true)
		
		// Check with IsHalted
		uassert.Equal(t, config.IsHalted(OpTypePool), true)
	})

	t.Run("Override existing value", func(t *testing.T) {
		config := HaltConfig{OpTypePool: true}
		
		// Override with false (not halted)
		err := config.set(OpTypePool, false)
		uassert.NoError(t, err)
		
		// Verify the change
		halted, err := config.get(OpTypePool)
		uassert.NoError(t, err)
		uassert.Equal(t, halted, false)
	})

	t.Run("Clone independence", func(t *testing.T) {
		original := HaltConfig{
			OpTypePool:   true,
			OpTypeRouter: false,
		}
		
		cloned := original.Clone()
		
		// Modify original
		err := original.set(OpTypePool, false)
		uassert.NoError(t, err)
		
		err = original.set(OpTypeRouter, true)
		uassert.NoError(t, err)
		
		// Cloned should remain unchanged
		poolHalted, err := cloned.get(OpTypePool)
		uassert.NoError(t, err)
		uassert.Equal(t, poolHalted, true)
		
		routerHalted, err := cloned.get(OpTypeRouter)
		uassert.NoError(t, err)
		uassert.Equal(t, routerHalted, false)
	})
}
