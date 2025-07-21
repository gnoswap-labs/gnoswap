package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// Test HaltConfig methods
func TestHaltConfig_IsEnabled(t *testing.T) {
	tests := []struct {
		name     string
		config   HaltConfig
		op       OpType
		expected bool
	}{
		{
			name:     "Enable operation",
			config:   HaltConfig{OpTypePool: newEnabledOption()},
			op:       OpTypePool,
			expected: true,
		},
		{
			name:     "Access only operation",
			config:   HaltConfig{OpTypePool: newAccessOnlyOption()},
			op:       OpTypePool,
			expected: false,
		},
		{
			name:     "Withdraw only operation",
			config:   HaltConfig{OpTypePool: newWithdrawOnlyOption()},
			op:       OpTypePool,
			expected: false,
		},
		{
			name:     "Disabled operation",
			config:   HaltConfig{OpTypePool: newDisabledOption()},
			op:       OpTypePool,
			expected: false,
		},
		{
			name:     "Nil operation",
			config:   HaltConfig{},
			op:       OpTypePool,
			expected: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.config.IsEnabled(tc.op)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestHaltConfig_IsEnabledAccess(t *testing.T) {
	tests := []struct {
		name     string
		config   HaltConfig
		op       OpType
		expected bool
	}{
		{
			name:     "Enable access",
			config:   HaltConfig{OpTypePool: newEnabledOption()},
			op:       OpTypePool,
			expected: true,
		},
		{
			name:     "Access only operation",
			config:   HaltConfig{OpTypePool: newAccessOnlyOption()},
			op:       OpTypePool,
			expected: true,
		},
		{
			name:     "Withdraw only operation",
			config:   HaltConfig{OpTypePool: newWithdrawOnlyOption()},
			op:       OpTypePool,
			expected: false,
		},
		{
			name:     "Disabled operation",
			config:   HaltConfig{OpTypePool: newDisabledOption()},
			op:       OpTypePool,
			expected: false,
		},
		{
			name:     "Nil operation",
			config:   HaltConfig{},
			op:       OpTypePool,
			expected: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.config.IsEnabledAccess(tc.op)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestHaltConfig_IsEnabledWithdraw(t *testing.T) {
	tests := []struct {
		name     string
		config   HaltConfig
		op       OpType
		expected bool
	}{
		{
			name:     "Enable withdraw",
			config:   HaltConfig{OpTypePool: newEnabledOption()},
			op:       OpTypePool,
			expected: true,
		},
		{
			name:     "Access only operation",
			config:   HaltConfig{OpTypePool: newAccessOnlyOption()},
			op:       OpTypePool,
			expected: false,
		},
		{
			name:     "Withdraw only operation",
			config:   HaltConfig{OpTypePool: newWithdrawOnlyOption()},
			op:       OpTypePool,
			expected: true,
		},
		{
			name:     "Disabled operation",
			config:   HaltConfig{OpTypePool: newDisabledOption()},
			op:       OpTypePool,
			expected: false,
		},
		{
			name:     "Nil operation",
			config:   HaltConfig{},
			op:       OpTypePool,
			expected: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.config.IsEnabledWithdraw(tc.op)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestHaltConfig_Clone(t *testing.T) {
	// given
	original := HaltConfig{
		OpTypePool:   newEnabledOption(),
		OpTypeRouter: newAccessOnlyOption(),
		OpTypeStaker: newEnabledOption(),
	}

	// when
	cloned := original.Clone()

	// then
	uassert.Equal(t, len(cloned), len(original))

	for op, option := range original {
		clonedOption := cloned[op]
		uassert.Equal(t, clonedOption.access, option.access)
		uassert.Equal(t, clonedOption.withdraw, option.withdraw)
	}

	// Verify independence by modifying original
	original[OpTypePool].disableAll()
	uassert.Equal(t, cloned[OpTypePool].access, true)
	uassert.Equal(t, cloned[OpTypePool].withdraw, true)
}

// Test HaltOption methods
func TestHaltOption_isableed(t *testing.T) {
	tests := []struct {
		name     string
		option   *HaltOption
		expected bool
	}{
		{
			name:     "Both access and withdraw allowed",
			option:   &HaltOption{access: true, withdraw: true},
			expected: true,
		},
		{
			name:     "Only access allowed",
			option:   &HaltOption{access: true, withdraw: false},
			expected: false,
		},
		{
			name:     "Only withdraw allowed",
			option:   &HaltOption{access: false, withdraw: true},
			expected: false,
		},
		{
			name:     "Neither allowed",
			option:   &HaltOption{access: false, withdraw: false},
			expected: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.option.IsEnabled()

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestHaltOption_IsEnabledAccess(t *testing.T) {
	tests := []struct {
		name     string
		option   *HaltOption
		expected bool
	}{
		{
			name:     "Access allowed",
			option:   &HaltOption{access: true, withdraw: false},
			expected: true,
		},
		{
			name:     "Access not allowed",
			option:   &HaltOption{access: false, withdraw: true},
			expected: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.option.IsEnabledAccess()

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestHaltOption_IsEnabledWithdraw(t *testing.T) {
	tests := []struct {
		name     string
		option   *HaltOption
		expected bool
	}{
		{
			name:     "Withdraw allowed",
			option:   &HaltOption{access: false, withdraw: true},
			expected: true,
		},
		{
			name:     "Withdraw not allowed",
			option:   &HaltOption{access: true, withdraw: false},
			expected: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.option.IsEnabledWithdraw()

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestHaltOption_Clone(t *testing.T) {
	// given
	original := &HaltOption{access: true, withdraw: false}

	// when
	cloned := original.Clone()

	// then
	uassert.Equal(t, cloned.access, original.access)
	uassert.Equal(t, cloned.withdraw, original.withdraw)

	// Verify independence
	original.access = false
	uassert.Equal(t, cloned.access, true)
}

func TestHaltOption_AllowDisableMethods(t *testing.T) {
	option := &HaltOption{access: false, withdraw: false}

	// Test allowAll
	option.enableAll()
	uassert.Equal(t, option.access, true)
	uassert.Equal(t, option.withdraw, true)

	// Test disableAll
	option.disableAll()
	uassert.Equal(t, option.access, false)
	uassert.Equal(t, option.withdraw, false)

	// Test allowAccess
	option.enableAccess()
	uassert.Equal(t, option.access, true)
	uassert.Equal(t, option.withdraw, false)

	// Test disableAccess
	option.disableAccess()
	uassert.Equal(t, option.access, false)
	uassert.Equal(t, option.withdraw, false)

	// Test allowWithdraw
	option.enableWithdraw()
	uassert.Equal(t, option.access, false)
	uassert.Equal(t, option.withdraw, true)

	// Test disableWithdraw
	option.disableWithdraw()
	uassert.Equal(t, option.access, false)
	uassert.Equal(t, option.withdraw, false)
}

// Test factory functions
func TestNewHaltOption(t *testing.T) {
	tests := []struct {
		name             string
		access           bool
		withdraw         bool
		expectedAccess   bool
		expectedWithdraw bool
	}{
		{
			name:             "Both true",
			access:           true,
			withdraw:         true,
			expectedAccess:   true,
			expectedWithdraw: true,
		},
		{
			name:             "Both false",
			access:           false,
			withdraw:         false,
			expectedAccess:   false,
			expectedWithdraw: false,
		},
		{
			name:             "Access only",
			access:           true,
			withdraw:         false,
			expectedAccess:   true,
			expectedWithdraw: false,
		},
		{
			name:             "Withdraw only",
			access:           false,
			withdraw:         true,
			expectedAccess:   false,
			expectedWithdraw: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			option := newHaltOption(tc.access, tc.withdraw)

			// then
			uassert.Equal(t, option.access, tc.expectedAccess)
			uassert.Equal(t, option.withdraw, tc.expectedWithdraw)
		})
	}
}

func TestNewIsEnabledOption(t *testing.T) {
	// when
	option := newEnabledOption()

	// then
	uassert.Equal(t, option.access, true)
	uassert.Equal(t, option.withdraw, true)
}

func TestNewAccessOnlyOption(t *testing.T) {
	// when
	option := newAccessOnlyOption()

	// then
	uassert.Equal(t, option.access, true)
	uassert.Equal(t, option.withdraw, false)
}

func TestNewWithdrawOnlyOption(t *testing.T) {
	// when
	option := newWithdrawOnlyOption()

	// then
	uassert.Equal(t, option.access, false)
	uassert.Equal(t, option.withdraw, true)
}

func TestNewDisabledOption(t *testing.T) {
	// when
	option := newDisabledOption()

	// then
	uassert.Equal(t, option.access, false)
	uassert.Equal(t, option.withdraw, false)
}

// Test config factory functions
func TestNewNoneConfig(t *testing.T) {
	// when
	config := newNoneConfig()

	// then
	allOperations := []OpType{
		OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter,
		OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance, OpTypeGovStaker,
		OpTypeXGns, OpTypeCommunityPool, OpTypeEmission,
	}

	for _, op := range allOperations {
		option := config.get(op)
		uassert.Equal(t, option.access, true)
		uassert.Equal(t, option.withdraw, true)
	}
}

func TestNewSafeModeConfig(t *testing.T) {
	// when
	config := newSafeModeConfig()

	// then
	allOperations := []OpType{
		OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter,
		OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance, OpTypeGovStaker,
		OpTypeXGns, OpTypeCommunityPool, OpTypeEmission,
	}

	for _, op := range allOperations {
		option := config.get(op)
		uassert.Equal(t, option.access, true)
		uassert.Equal(t, option.withdraw, false)
	}
}

func TestNewEmergencyConfig(t *testing.T) {
	// when
	config := newEmergencyConfig()

	// then
	// Governance should allow all operations
	govOption := config.get(OpTypeGovernance)
	uassert.Equal(t, govOption.access, true)
	uassert.Equal(t, govOption.withdraw, true)

	// All other operations should allow only withdraw
	otherOperations := []OpType{
		OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter,
		OpTypeStaker, OpTypeLaunchpad, OpTypeGovStaker,
		OpTypeXGns, OpTypeCommunityPool, OpTypeEmission,
	}

	for _, op := range otherOperations {
		option := config.get(op)
		uassert.Equal(t, option.access, false)
		uassert.Equal(t, option.withdraw, true)
	}
}

func TestNewCompleteConfig(t *testing.T) {
	// when
	config := newCompleteConfig()

	// then
	allOperations := []OpType{
		OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter,
		OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance, OpTypeGovStaker,
		OpTypeXGns, OpTypeCommunityPool, OpTypeEmission,
	}

	for _, op := range allOperations {
		option := config.get(op)
		uassert.Equal(t, option.access, false)
		uassert.Equal(t, option.withdraw, false)
	}
}

func TestConfig_AllConfigLevelsIntegration(t *testing.T) {
	tests := []struct {
		name             string
		configFunc       func() HaltConfig
		expectedAccess   map[OpType]bool
		expectedWithdraw map[OpType]bool
	}{
		{
			name:       "None config allows all",
			configFunc: newNoneConfig,
			expectedAccess: map[OpType]bool{
				OpTypePool:       true,
				OpTypeGovernance: true,
				OpTypeRouter:     true,
			},
			expectedWithdraw: map[OpType]bool{
				OpTypePool:       true,
				OpTypeGovernance: true,
				OpTypeRouter:     true,
			},
		},
		{
			name:       "Safe mode allows access only",
			configFunc: newSafeModeConfig,
			expectedAccess: map[OpType]bool{
				OpTypePool:       true,
				OpTypeGovernance: true,
				OpTypeRouter:     true,
			},
			expectedWithdraw: map[OpType]bool{
				OpTypePool:       false,
				OpTypeGovernance: false,
				OpTypeRouter:     false,
			},
		},
		{
			name:       "Emergency allows governance all, others withdraw only",
			configFunc: newEmergencyConfig,
			expectedAccess: map[OpType]bool{
				OpTypePool:       false,
				OpTypeGovernance: true,
				OpTypeRouter:     false,
			},
			expectedWithdraw: map[OpType]bool{
				OpTypePool:       true,
				OpTypeGovernance: true,
				OpTypeRouter:     true,
			},
		},
		{
			name:       "Complete disables all",
			configFunc: newCompleteConfig,
			expectedAccess: map[OpType]bool{
				OpTypePool:       false,
				OpTypeGovernance: false,
				OpTypeRouter:     false,
			},
			expectedWithdraw: map[OpType]bool{
				OpTypePool:       false,
				OpTypeGovernance: false,
				OpTypeRouter:     false,
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			config := tc.configFunc()

			// then
			for op, expected := range tc.expectedAccess {
				uassert.Equal(t, config.IsEnabledAccess(op), expected)
			}
			for op, expected := range tc.expectedWithdraw {
				uassert.Equal(t, config.IsEnabledWithdraw(op), expected)
			}
		})
	}
}
