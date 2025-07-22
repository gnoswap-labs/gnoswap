package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestTypes_HaltLevelString(t *testing.T) {
	tests := []struct {
		name     string
		level    HaltLevel
		expected string
	}{
		{
			name:     "None level string",
			level:    HaltLevelNone,
			expected: "NONE",
		},
		{
			name:     "Safe mode level string",
			level:    HaltLevelSafeMode,
			expected: "SAFE_MODE",
		},
		{
			name:     "Emergency level string",
			level:    HaltLevelEmergency,
			expected: "EMERGENCY",
		},
		{
			name:     "Complete level string",
			level:    HaltLevelComplete,
			expected: "COMPLETE",
		},
		{
			name:     "Custom level string",
			level:    HaltLevel("CUSTOM"),
			expected: "CUSTOM",
		},
		{
			name:     "Empty level string",
			level:    HaltLevel(""),
			expected: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.level.String()

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestTypes_HaltLevelDescription(t *testing.T) {
	tests := []struct {
		name     string
		level    HaltLevel
		expected string
	}{
		{
			name:     "None level description",
			level:    HaltLevelNone,
			expected: "All operations enabled",
		},
		{
			name:     "Safe mode level description",
			level:    HaltLevelSafeMode,
			expected: "All operations enabled except withdrawals",
		},
		{
			name:     "Emergency level description",
			level:    HaltLevelEmergency,
			expected: "Only governance and withdrawal operations enabled",
		},
		{
			name:     "Complete level description",
			level:    HaltLevelComplete,
			expected: "All operations disabled",
		},
		{
			name:     "Invalid level description",
			level:    HaltLevel("INVALID"),
			expected: "Unknown halt level",
		},
		{
			name:     "Empty level description",
			level:    HaltLevel(""),
			expected: "Unknown halt level",
		},
		{
			name:     "Random level description",
			level:    HaltLevel("RANDOM"),
			expected: "Unknown halt level",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.level.Description()

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

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
		{
			name:     "Lower case level",
			level:    HaltLevel("none"),
			expected: false,
		},
		{
			name:     "Partial level",
			level:    HaltLevel("SAFE"),
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

func TestTypes_OpTypeString(t *testing.T) {
	tests := []struct {
		name     string
		op       OpType
		expected string
	}{
		{
			name:     "Pool operation string",
			op:       OpTypePool,
			expected: "pool",
		},
		{
			name:     "Position operation string",
			op:       OpTypePosition,
			expected: "position",
		},
		{
			name:     "Protocol fee operation string",
			op:       OpTypeProtocolFee,
			expected: "protocol_fee",
		},
		{
			name:     "Router operation string",
			op:       OpTypeRouter,
			expected: "router",
		},
		{
			name:     "Staker operation string",
			op:       OpTypeStaker,
			expected: "staker",
		},
		{
			name:     "Launchpad operation string",
			op:       OpTypeLaunchpad,
			expected: "launchpad",
		},
		{
			name:     "Governance operation string",
			op:       OpTypeGovernance,
			expected: "governance",
		},
		{
			name:     "Gov staker operation string",
			op:       OpTypeGovStaker,
			expected: "gov_staker",
		},
		{
			name:     "XGns operation string",
			op:       OpTypeXGns,
			expected: "xgns",
		},
		{
			name:     "Community pool operation string",
			op:       OpTypeCommunityPool,
			expected: "community_pool",
		},
		{
			name:     "Emission operation string",
			op:       OpTypeEmission,
			expected: "emission",
		},
		{
			name:     "Withdraw operation string",
			op:       OpTypeWithdraw,
			expected: "withdraw",
		},
		{
			name:     "Custom operation string",
			op:       OpType("custom"),
			expected: "custom",
		},
		{
			name:     "Empty operation string",
			op:       OpType(""),
			expected: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.op.String()

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
		{
			name:     "Case sensitive operation",
			op:       OpType("POOL"),
			expected: false,
		},
		{
			name:     "Partial operation",
			op:       OpType("poo"),
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
