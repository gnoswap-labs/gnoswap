package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestConfig_GetOperationDefaultStatus(t *testing.T) {
	tests := []struct {
		name     string
		level    HaltLevel
		op       OpType
		expected bool
	}{
		// HaltLevelNone - all operations enabled
		{
			name:     "None level pool enabled",
			level:    HaltLevelNone,
			op:       OpTypePool,
			expected: true,
		},
		{
			name:     "None level withdraw enabled",
			level:    HaltLevelNone,
			op:       OpTypeWithdraw,
			expected: true,
		},
		{
			name:     "None level governance enabled",
			level:    HaltLevelNone,
			op:       OpTypeGovernance,
			expected: true,
		},

		// HaltLevelSafeMode - all enabled except withdrawal
		{
			name:     "Safe mode pool enabled",
			level:    HaltLevelSafeMode,
			op:       OpTypePool,
			expected: true,
		},
		{
			name:     "Safe mode withdraw disabled",
			level:    HaltLevelSafeMode,
			op:       OpTypeWithdraw,
			expected: false,
		},
		{
			name:     "Safe mode governance enabled",
			level:    HaltLevelSafeMode,
			op:       OpTypeGovernance,
			expected: true,
		},
		{
			name:     "Safe mode router enabled",
			level:    HaltLevelSafeMode,
			op:       OpTypeRouter,
			expected: true,
		},

		// HaltLevelEmergency - only governance and withdrawal enabled
		{
			name:     "Emergency governance enabled",
			level:    HaltLevelEmergency,
			op:       OpTypeGovernance,
			expected: true,
		},
		{
			name:     "Emergency withdraw enabled",
			level:    HaltLevelEmergency,
			op:       OpTypeWithdraw,
			expected: true,
		},
		{
			name:     "Emergency pool disabled",
			level:    HaltLevelEmergency,
			op:       OpTypePool,
			expected: false,
		},
		{
			name:     "Emergency router disabled",
			level:    HaltLevelEmergency,
			op:       OpTypeRouter,
			expected: false,
		},
		{
			name:     "Emergency staker disabled",
			level:    HaltLevelEmergency,
			op:       OpTypeStaker,
			expected: false,
		},

		// HaltLevelComplete - all operations disabled
		{
			name:     "Complete governance disabled",
			level:    HaltLevelComplete,
			op:       OpTypeGovernance,
			expected: false,
		},
		{
			name:     "Complete withdraw disabled",
			level:    HaltLevelComplete,
			op:       OpTypeWithdraw,
			expected: false,
		},
		{
			name:     "Complete pool disabled",
			level:    HaltLevelComplete,
			op:       OpTypePool,
			expected: false,
		},

		// Invalid level
		{
			name:     "Invalid level defaults disabled",
			level:    HaltLevel("INVALID"),
			op:       OpTypePool,
			expected: false,
		},

		// Test all operation types with None level
		{
			name:     "None level position enabled",
			level:    HaltLevelNone,
			op:       OpTypePosition,
			expected: true,
		},
		{
			name:     "None level protocol fee enabled",
			level:    HaltLevelNone,
			op:       OpTypeProtocolFee,
			expected: true,
		},
		{
			name:     "None level staker enabled",
			level:    HaltLevelNone,
			op:       OpTypeStaker,
			expected: true,
		},
		{
			name:     "None level launchpad enabled",
			level:    HaltLevelNone,
			op:       OpTypeLaunchpad,
			expected: true,
		},
		{
			name:     "None level gov staker enabled",
			level:    HaltLevelNone,
			op:       OpTypeGovStaker,
			expected: true,
		},
		{
			name:     "None level xgns enabled",
			level:    HaltLevelNone,
			op:       OpTypeXGns,
			expected: true,
		},
		{
			name:     "None level community pool enabled",
			level:    HaltLevelNone,
			op:       OpTypeCommunityPool,
			expected: true,
		},
		{
			name:     "None level emission enabled",
			level:    HaltLevelNone,
			op:       OpTypeEmission,
			expected: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := getOperationDefaultStatus(tc.level, tc.op)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestConfig_AllOperationsEnabled(t *testing.T) {
	// when
	result := allOperationsEnabled()

	// then
	uassert.Equal(t, len(result), 12) // Should have all 12 operations

	// Verify all operations are enabled
	uassert.Equal(t, result[OpTypePool], true)
	uassert.Equal(t, result[OpTypePosition], true)
	uassert.Equal(t, result[OpTypeProtocolFee], true)
	uassert.Equal(t, result[OpTypeRouter], true)
	uassert.Equal(t, result[OpTypeStaker], true)
	uassert.Equal(t, result[OpTypeLaunchpad], true)
	uassert.Equal(t, result[OpTypeGovernance], true)
	uassert.Equal(t, result[OpTypeGovStaker], true)
	uassert.Equal(t, result[OpTypeXGns], true)
	uassert.Equal(t, result[OpTypeCommunityPool], true)
	uassert.Equal(t, result[OpTypeEmission], true)
	uassert.Equal(t, result[OpTypeWithdraw], true)
}
