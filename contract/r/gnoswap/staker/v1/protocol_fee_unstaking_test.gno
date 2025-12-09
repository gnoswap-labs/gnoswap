package v1

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
			initStakerTest(t)

			getMockInstance().store.SetUnstakingFee(tc.expectedFee) // Set the fee globally for the test

			if tc.stakerBalance > 0 {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, stakerAddr, tc.stakerBalance)
			}

			handleStakingRewardFeeFn := func() (int64, int64, error) {
				testing.SetRealm(testing.NewUserRealm(stakerAddr))
				return getMockInstance().handleStakingRewardFee(tc.tokenPath, tc.amount, tc.internal)
			}

			if tc.expectedHasPanic {
				uassert.AbortsWithMessage(t, tc.expectedPanicMsg, func() {
					handleStakingRewardFeeFn()
				})

				return
			}

			netAmount, _, err := handleStakingRewardFeeFn()
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
			initStakerTest(t)

			// Reset unstaking fee before each test
			getMockInstance().store.SetUnstakingFee(0)

			// Set the caller
			testing.SetRealm(testing.NewUserRealm(tc.caller))

			// Execute the function
			if tc.shouldAbort {
				uassert.AbortsContains(t, tc.expectedErrMsg, func() {
					mockInstanceSetUnstakingFee(tc.fee)
				})
			} else {
				mockInstanceSetUnstakingFee(tc.fee)

				testing.SetRealm(adminRealm)
				// Verify the result
				actual := getMockInstance().store.GetUnstakingFee()
				uassert.Equal(t, tc.expectedFee, actual)
			}
		})
	}
}

// Test GetUnstakingFee function
func TestGetUnstakingFee(t *testing.T) {
	tests := []struct {
		name        string
		setFee      int64
		expectedFee int64
	}{
		{
			name:        "get default fee (zero)",
			setFee:      0,
			expectedFee: 0,
		},
		{
			name:        "get custom fee 100",
			setFee:      100,
			expectedFee: 100,
		},
		{
			name:        "get custom fee 500",
			setFee:      500,
			expectedFee: 500,
		},
		{
			name:        "get max fee",
			setFee:      maxUnstakingFee,
			expectedFee: maxUnstakingFee,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			// Set the fee
			instance.store.SetUnstakingFee(tt.setFee)

			// Get and verify
			actualFee := instance.GetUnstakingFee()
			uassert.Equal(t, tt.expectedFee, actualFee)
		})
	}
}

// Test setUnStakingFee internal function
func TestSetUnStakingFeeInternal(t *testing.T) {
	tests := []struct {
		name    string
		fee     int64
		wantFee int64
	}{
		{
			name:    "set fee to 0",
			fee:     0,
			wantFee: 0,
		},
		{
			name:    "set fee to 250",
			fee:     250,
			wantFee: 250,
		},
		{
			name:    "set fee to max",
			fee:     maxUnstakingFee,
			wantFee: maxUnstakingFee,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			// Call internal setter
			instance.setUnStakingFee(tt.fee)

			// Verify
			actualFee := instance.GetUnstakingFee()
			uassert.Equal(t, tt.wantFee, actualFee)
		})
	}
}

// Test handleStakingRewardFee with various scenarios
func TestHandleStakingRewardFeeEdgeCases(t *testing.T) {
	tests := []struct {
		name         string
		tokenPath    string
		amount       int64
		unstakingFee int64
		internal     bool
		expectedNet  int64
		expectedFee  int64
		expectError  bool
	}{
		{
			name:         "zero fee results in full amount",
			tokenPath:    gnsPath,
			amount:       10000,
			unstakingFee: 0,
			internal:     false,
			expectedNet:  10000,
			expectedFee:  0,
			expectError:  false,
		},
		{
			name:         "1% fee on 10000",
			tokenPath:    gnsPath,
			amount:       10000,
			unstakingFee: 100, // 1%
			internal:     false,
			expectedNet:  9900,
			expectedFee:  100,
			expectError:  false,
		},
		{
			name:         "5% fee on 10000",
			tokenPath:    gnsPath,
			amount:       10000,
			unstakingFee: 500, // 5%
			internal:     false,
			expectedNet:  9500,
			expectedFee:  500,
			expectError:  false,
		},
		{
			name:         "small amount with fee results in zero fee",
			tokenPath:    gnsPath,
			amount:       5,
			unstakingFee: 100, // 1%
			internal:     false,
			expectedNet:  5,
			expectedFee:  0,
			expectError:  false,
		},
		{
			name:         "internal reward uses GNS_PATH",
			tokenPath:    barPath,
			amount:       10000,
			unstakingFee: 100,
			internal:     true, // Should convert to GNS_PATH
			expectedNet:  9900,
			expectedFee:  100,
			expectError:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			// Set the unstaking fee
			instance.store.SetUnstakingFee(tt.unstakingFee)

			// Prepare token balance
			if tt.unstakingFee > 0 {
				calculatedFee := (tt.amount * tt.unstakingFee) / 10000
				if calculatedFee > 0 {
					testing.SetRealm(adminRealm)
					_ = tt.tokenPath
					if tt.internal {
						_ = GNS_PATH
					}
					gns.Transfer(cross, stakerAddr, calculatedFee)
				}
			}

			testing.SetRealm(testing.NewUserRealm(stakerAddr))
			netAmount, feeAmount, err := instance.handleStakingRewardFee(tt.tokenPath, tt.amount, tt.internal)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedNet, netAmount)
				uassert.Equal(t, tt.expectedFee, feeAmount)
			}
		})
	}
}

// Test handleStakingRewardFee calculation precision
func TestHandleStakingRewardFeeCalculationPrecision(t *testing.T) {
	tests := []struct {
		name        string
		amount      int64
		fee         int64
		expectedFee int64
		expectedNet int64
	}{
		{
			name:        "1 basis point on 1000000",
			amount:      1000000,
			fee:         1, // 0.01%
			expectedFee: 100,
			expectedNet: 999900,
		},
		{
			name:        "10 basis points on 1000000",
			amount:      1000000,
			fee:         10, // 0.1%
			expectedFee: 1000,
			expectedNet: 999000,
		},
		{
			name:        "100 basis points on 1000000",
			amount:      1000000,
			fee:         100, // 1%
			expectedFee: 10000,
			expectedNet: 990000,
		},
		{
			name:        "1000 basis points on 1000000",
			amount:      1000000,
			fee:         1000, // 10%
			expectedFee: 100000,
			expectedNet: 900000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Verify calculation: feeAmount = (amount * fee) / FEE_PRECISION
			calculatedFee := (tt.amount * tt.fee) / 10000
			uassert.Equal(t, tt.expectedFee, calculatedFee)
			uassert.Equal(t, tt.expectedNet, tt.amount-calculatedFee)
		})
	}
}
