package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestTypes_HaltLevelIsValid(t *testing.T) {
	tests := []struct {
		name     string
		level    HaltLevel
		expected bool
	}{
		{
			name:     "Valid none level",
			level:    HaltLevelNone,
			expected: true,
		},
		{
			name:     "Valid safe mode level",
			level:    HaltLevelSafeMode,
			expected: true,
		},
		{
			name:     "Valid emergency level",
			level:    HaltLevelEmergency,
			expected: true,
		},
		{
			name:     "Valid complete level",
			level:    HaltLevelComplete,
			expected: true,
		},
		{
			name:     "Invalid level",
			level:    HaltLevel("INVALID"),
			expected: false,
		},
		{
			name:     "Empty level",
			level:    HaltLevel(""),
			expected: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.level.IsValid()

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestTypes_OpTypeIsValid(t *testing.T) {
	tests := []struct {
		name     string
		op       OpType
		expected bool
	}{
		{
			name:     "Valid pool operation",
			op:       OpTypePool,
			expected: true,
		},
		{
			name:     "Valid position operation",
			op:       OpTypePosition,
			expected: true,
		},
		{
			name:     "Valid protocol fee operation",
			op:       OpTypeProtocolFee,
			expected: true,
		},
		{
			name:     "Valid router operation",
			op:       OpTypeRouter,
			expected: true,
		},
		{
			name:     "Valid staker operation",
			op:       OpTypeStaker,
			expected: true,
		},
		{
			name:     "Valid launchpad operation",
			op:       OpTypeLaunchpad,
			expected: true,
		},
		{
			name:     "Valid governance operation",
			op:       OpTypeGovernance,
			expected: true,
		},
		{
			name:     "Valid gov staker operation",
			op:       OpTypeGovStaker,
			expected: true,
		},
		{
			name:     "Valid xgns operation",
			op:       OpTypeXGns,
			expected: true,
		},
		{
			name:     "Valid community pool operation",
			op:       OpTypeCommunityPool,
			expected: true,
		},
		{
			name:     "Valid emission operation",
			op:       OpTypeEmission,
			expected: true,
		},
		{
			name:     "Valid withdraw operation",
			op:       OpTypeWithdraw,
			expected: true,
		},
		{
			name:     "Invalid operation",
			op:       OpType("invalid"),
			expected: false,
		},
		{
			name:     "Empty operation",
			op:       OpType(""),
			expected: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.op.IsValid()

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}
