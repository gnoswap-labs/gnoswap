package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestGetters_IndividualGetters(t *testing.T) {
	type getterFunc func() bool

	// Operations halted in Emergency+Complete but not in None+SafeMode
	standardOps := []struct {
		name   string
		getter getterFunc
	}{
		{"Pool", IsHaltedPool},
		{"Position", IsHaltedPosition},
		{"ProtocolFee", IsHaltedProtocolFee},
		{"Router", IsHaltedRouter},
		{"Staker", IsHaltedStaker},
		{"Launchpad", IsHaltedLaunchpad},
		{"GovStaker", IsHaltedGovStaker},
		{"XGns", IsHaltedXGns},
		{"CommunityPool", IsHaltedCommunityPool},
		{"Emission", IsHaltedEmission},
	}

	for _, op := range standardOps {
		t.Run(op.name, func(t *testing.T) {
			for _, tc := range []struct {
				level    HaltLevel
				expected bool
			}{
				{HaltLevelNone, false},
				{HaltLevelSafeMode, false},
				{HaltLevelEmergency, true},
				{HaltLevelComplete, true},
			} {
				err := setHaltLevel(tc.level)
				uassert.NoError(t, err)
				uassert.Equal(t, op.getter(), tc.expected)
			}
		})
	}

	// Governance: only halted in Complete
	t.Run("Governance", func(t *testing.T) {
		for _, tc := range []struct {
			level    HaltLevel
			expected bool
		}{
			{HaltLevelNone, false},
			{HaltLevelSafeMode, false},
			{HaltLevelEmergency, false},
			{HaltLevelComplete, true},
		} {
			err := setHaltLevel(tc.level)
			uassert.NoError(t, err)
			uassert.Equal(t, IsHaltedGovernance(), tc.expected)
		}
	})

	// Withdraw: halted in SafeMode+Complete, not in None+Emergency
	t.Run("Withdraw", func(t *testing.T) {
		for _, tc := range []struct {
			level    HaltLevel
			expected bool
		}{
			{HaltLevelNone, false},
			{HaltLevelSafeMode, true},
			{HaltLevelEmergency, false},
			{HaltLevelComplete, true},
		} {
			err := setHaltLevel(tc.level)
			uassert.NoError(t, err)
			uassert.Equal(t, IsHaltedWithdraw(), tc.expected)
		}
	})
}

func TestGetters_IsHalted_InvalidOpType(t *testing.T) {
	tests := []struct {
		name             string
		opTypes          []OpType
		expectedError    bool
		expectedErrorMsg string
		expectedHalted   bool
	}{
		{
			name:             "Single invalid OpType (zero)",
			opTypes:          []OpType{OpType(0)},
			expectedError:    true,
			expectedErrorMsg: "invalid operation type: unknown",
			expectedHalted:   true,
		},
		{
			name:             "Valid and invalid OpTypes mixed",
			opTypes:          []OpType{OpTypePool, OpType(0)},
			expectedError:    true,
			expectedErrorMsg: "invalid operation type: unknown",
			expectedHalted:   true,
		},
		{
			name:           "All valid OpTypes",
			opTypes:        []OpType{OpTypePool, OpTypePosition},
			expectedError:  false,
			expectedHalted: false,
		},
		{
			name:           "Empty OpTypes list",
			opTypes:        []OpType{},
			expectedError:  false,
			expectedHalted: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := setHaltLevel(HaltLevelNone)
			uassert.NoError(t, err)
			halted, err := IsHalted(tt.opTypes...)

			if tt.expectedError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.expectedErrorMsg)
			} else {
				uassert.NoError(t, err)
			}
			uassert.Equal(t, halted, tt.expectedHalted)
		})
	}
}
