package staker

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/gns"

	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
)

func TestHandleStakingRewardFee(t *testing.T) {
	tests := []struct {
		name             string
		tokenPath        string
		amount           int64
		stakerBalance    int64
		internal         bool
		expectedFee      int64
		expectedNet      int64
		expectedHasPanic bool
		expectedPanicMsg string
	}{
		{
			name:          "No fee configured",
			tokenPath:     gnsPath,
			amount:        10000,
			stakerBalance: 0,
			internal:      true,
			expectedFee:   0,
			expectedNet:   10000,
		},
		{
			name:          "Standard fee",
			tokenPath:     gnsPath,
			amount:        10000,
			stakerBalance: 100,
			internal:      false,
			expectedFee:   100,
			expectedNet:   9900,
		},
		{
			name:             "Standard fee but staker balance is insufficient",
			tokenPath:        gnsPath,
			amount:           10000,
			stakerBalance:    0,
			internal:         false,
			expectedFee:      100,
			expectedNet:      9900,
			expectedHasPanic: true,
			expectedPanicMsg: "insufficient balance",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			unstakingFee = tc.expectedFee // Set the fee globally for the test

			if tc.stakerBalance > 0 {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, stakerAddr, tc.stakerBalance)
			}

			testing.SetRealm(stakerRealm)

			if tc.expectedHasPanic {
				uassert.AbortsWithMessage(t, tc.expectedPanicMsg, func() {
					handleStakingRewardFee(tc.tokenPath, tc.amount, tc.internal)
				})

				return
			}

			netAmount, _, err := handleStakingRewardFee(tc.tokenPath, tc.amount, tc.internal)
			if err != nil {
				t.Errorf("Expected no error, got %v", err)
			}

			if netAmount != tc.expectedNet {
				t.Errorf("Expected netAmount %d, got %d", tc.expectedNet, netAmount)
			}
		})
	}
}

func TestSetUnStakingFee(t *testing.T) {
	tests := []struct {
		name           string
		caller         address
		fee            int64
		expectedFee    int64
		shouldAbort    bool
		expectedErrMsg string
	}{
		// Permission tests
		{
			name:        "admin can set valid fee",
			caller:      adminAddr,
			fee:         500,
			expectedFee: 500,
			shouldAbort: false,
		},
		{
			name:        "governance can set valid fee",
			caller:      govGovernanceAddr,
			fee:         750,
			expectedFee: 750,
			shouldAbort: false,
		},
		{
			name:           "unauthorized user cannot set fee",
			caller:         testutils.TestAddress("unauthorized"),
			fee:            500,
			expectedFee:    0,
			shouldAbort:    true,
			expectedErrMsg: ufmt.Sprintf("unauthorized: caller %s is not admin or governance", testutils.TestAddress("unauthorized")),
		},
		// Fee validation tests
		{
			name:           "admin cannot set negative fee",
			caller:         adminAddr,
			fee:            -100,
			expectedFee:    0,
			shouldAbort:    true,
			expectedErrMsg: ufmt.Sprintf("invalid unstaking fee || fee(%d) must be in range 0 ~ %d", -100, maxUnstakingFee),
		},
		{
			name:        "admin cannot set zero fee",
			caller:      adminAddr,
			fee:         0,
			expectedFee: 0,
			shouldAbort: false,
		},
		{
			name:           "admin cannot set fee above max",
			caller:         adminAddr,
			fee:            maxUnstakingFee + 1,
			expectedFee:    0,
			shouldAbort:    true,
			expectedErrMsg: ufmt.Sprintf("fee(%d) must be in range 0 ~ %d", maxUnstakingFee+1, maxUnstakingFee),
		},
		{
			name:        "admin can set max fee",
			caller:      adminAddr,
			fee:         maxUnstakingFee,
			expectedFee: maxUnstakingFee,
			shouldAbort: false,
		},
		{
			name:        "admin can set minimum valid fee",
			caller:      adminAddr,
			fee:         1,
			expectedFee: 1,
			shouldAbort: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// Reset unstaking fee before each test
			unstakingFee = 0

			// Set the caller
			testing.SetOriginCaller(tc.caller)
			testing.SetRealm(testing.NewUserRealm(tc.caller))

			// Execute the function
			if tc.shouldAbort {
				uassert.AbortsContains(t, tc.expectedErrMsg, func() {
					SetUnStakingFee(cross, tc.fee)
				})
			} else {
				SetUnStakingFee(cross, tc.fee)

				// Verify the result
				actual := GetUnstakingFee()
				uassert.Equal(t, tc.expectedFee, actual)
			}
		})
	}
}
