package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
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
			name:     "Unknown operation string",
			op:       OpType(1 << 20),
			expected: "unknown(0x100000)",
		},
		{
			name:     "Zero operation string",
			op:       OpType(0),
			expected: "unknown(0x0)",
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
			name:     "Invalid zero value",
			op:       OpType(0),
			expected: false,
		},
		{
			name:     "Invalid multi-bit value",
			op:       OpTypePool | OpTypeRouter,
			expected: false,
		},
		{
			name:     "Invalid out of range bit",
			op:       OpType(1 << 20),
			expected: false,
		},
		{
			name:     "Invalid all bits",
			op:       OpTypeAll,
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

func TestTypes_OpTypes(t *testing.T) {
	ops := OpTypes()

	// Should return all 12 operation types
	uassert.Equal(t, len(ops), 12)

	// Should be in deterministic order matching opTypeList
	expected := []OpType{
		OpTypePool, OpTypePosition, OpTypeProtocolFee, OpTypeRouter,
		OpTypeStaker, OpTypeLaunchpad, OpTypeGovernance, OpTypeGovStaker,
		OpTypeXGns, OpTypeCommunityPool, OpTypeEmission, OpTypeWithdraw,
	}

	for i, op := range ops {
		uassert.Equal(t, uint64(op), uint64(expected[i]))
	}

	// Verify returned slice is a copy (independence)
	ops[0] = OpType(0)
	freshOps := OpTypes()
	uassert.Equal(t, uint64(freshOps[0]), uint64(OpTypePool))
}

func TestTypes_OpTypeFromString(t *testing.T) {
	tests := []struct {
		name       string
		input      string
		expectedOp OpType
		expectedOk bool
	}{
		{"pool", "pool", OpTypePool, true},
		{"position", "position", OpTypePosition, true},
		{"protocol_fee", "protocol_fee", OpTypeProtocolFee, true},
		{"router", "router", OpTypeRouter, true},
		{"staker", "staker", OpTypeStaker, true},
		{"launchpad", "launchpad", OpTypeLaunchpad, true},
		{"governance", "governance", OpTypeGovernance, true},
		{"gov_staker", "gov_staker", OpTypeGovStaker, true},
		{"xgns", "xgns", OpTypeXGns, true},
		{"community_pool", "community_pool", OpTypeCommunityPool, true},
		{"emission", "emission", OpTypeEmission, true},
		{"withdraw", "withdraw", OpTypeWithdraw, true},
		{"invalid string", "invalid", OpType(0), false},
		{"empty string", "", OpType(0), false},
		{"uppercase", "POOL", OpType(0), false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			op, ok := OpTypeFromString(tc.input)
			uassert.Equal(t, ok, tc.expectedOk)
			uassert.Equal(t, uint64(op), uint64(tc.expectedOp))
		})
	}
}

func TestTypes_OpTypeConsistency(t *testing.T) {
	ops := OpTypes()

	var combined OpType
	for _, op := range ops {
		name := op.String()
		roundTripped, ok := OpTypeFromString(name)
		if !ok {
			t.Errorf("OpTypeFromString(%q) failed for %d", name, uint64(op))
		}
		uassert.Equal(t, uint64(roundTripped), uint64(op))

		if op&OpTypeAll != op {
			t.Errorf("OpType %s (0x%x) is not included in OpTypeAll", name, uint64(op))
		}

		combined |= op
	}

	uassert.Equal(t, uint64(combined), uint64(OpTypeAll))
}
