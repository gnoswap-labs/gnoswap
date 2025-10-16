package v1

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"

	"gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/qux"

	_ "gno.land/r/gnoswap/rbac" // Initialize contract roles
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	adminUser     = adminAddr
	dummyRealm    = testing.NewCodeRealm("gno.land/r/dummy")
	aliceAddr     = testutils.TestAddress("alice")

	// contract paths
	poolPath      = "gno.land/r/gnoswap/v1/pool"
	positionPath  = "gno.land/r/gnoswap/v1/position"
	routerPath    = "gno.land/r/gnoswap/v1/router"
	stakerPath    = "gno.land/r/gnoswap/v1/staker"
	govStakerPath = "gno.land/r/gnoswap/v1/gov/staker"

	stakerRealm    = testing.NewCodeRealm(stakerPath)
	govStakerRealm = testing.NewCodeRealm(govStakerPath)
)

// createTestProtocolFee creates a fresh protocolFeeV1 instance for testing
func createTestProtocolFee(t *testing.T) *protocolFeeV1 {
	t.Helper()

	return &protocolFeeV1{
		store: &mockProtocolFeeStore{
			state: newProtocolFeeStateInternal(),
		},
	}
}

// func TestDistributeProtocolFee(t *testing.T) {
// 	// Create fresh instance for clean test
// 	pf := createTestProtocolFee(t)

// 	// Reset token balances
// 	testing.SetRealm(adminRealm)
// 	testing.SetOriginCaller(adminAddr)
// 	if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
// 		bar.Transfer(cross, adminAddr, balance)
// 	}
// 	if balance := qux.BalanceOf(protocolFeeAddr); balance > 0 {
// 		qux.Transfer(cross, adminAddr, balance)
// 	}
// 	if balance := bar.BalanceOf(devOpsAddr); balance > 0 {
// 		testing.SetRealm(testing.NewUserRealm(devOpsAddr))
// 		bar.Transfer(cross, adminAddr, balance)
// 		testing.SetRealm(adminRealm)
// 	}
// 	if balance := qux.BalanceOf(devOpsAddr); balance > 0 {
// 		testing.SetRealm(testing.NewUserRealm(devOpsAddr))
// 		qux.Transfer(cross, adminAddr, balance)
// 		testing.SetRealm(adminRealm)
// 	}
// 	if balance := bar.BalanceOf(govStakerAddr); balance > 0 {
// 		testing.SetRealm(testing.NewUserRealm(govStakerAddr))
// 		bar.Transfer(cross, adminAddr, balance)
// 		testing.SetRealm(adminRealm)
// 	}
// 	if balance := qux.BalanceOf(govStakerAddr); balance > 0 {
// 		testing.SetRealm(testing.NewUserRealm(govStakerAddr))
// 		qux.Transfer(cross, adminAddr, balance)
// 		testing.SetRealm(adminRealm)
// 	}

// 	// admin > protocol_fee
// 	testing.SetRealm(adminRealm)
// 	testing.SetOriginCaller(adminAddr)
// 	bar.Transfer(cross, protocolFeeAddr, 1000)
// 	qux.Transfer(cross, protocolFeeAddr, 1000)

// 	testing.SetRealm(stakerRealm)
// 	// to fix "unauthorized caller" error
// 	func (cur realm) {
// 		pf.AddToProtocolFee("gno.land/r/onbloc/bar", 1000)
// 		pf.AddToProtocolFee("gno.land/r/onbloc/qux", 1000)
// 	}(cross)

// 	uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), int64(1000))
// 	uassert.Equal(t, bar.BalanceOf(devOpsAddr), int64(0))
// 	uassert.Equal(t, bar.BalanceOf(govStakerAddr), int64(0))

// 	uassert.Equal(t, qux.BalanceOf(protocolFeeAddr), int64(1000))
// 	uassert.Equal(t, qux.BalanceOf(devOpsAddr), int64(0))
// 	uassert.Equal(t, qux.BalanceOf(govStakerAddr), int64(0))

// 	// gov/staker > protocol_fee
// 	testing.SetRealm(govStakerRealm)
// 	func(cur realm) {
// 		pf.DistributeProtocolFee()
// 	}(cross)

// 	uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), int64(0))
// 	uassert.Equal(t, bar.BalanceOf(devOpsAddr), int64(0))
// 	uassert.Equal(t, bar.BalanceOf(govStakerAddr), int64(1000))

// 	uassert.Equal(t, qux.BalanceOf(protocolFeeAddr), int64(0))
// 	uassert.Equal(t, qux.BalanceOf(devOpsAddr), int64(0))
// 	uassert.Equal(t, qux.BalanceOf(govStakerAddr), int64(1000))
// }

func TestAddToProtocolFee(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
		amount    int64
		want      int64
	}{
		{
			name:      "add foo to protocol fee",
			tokenPath: "gno.land/r/foo",
			amount:    100,
			want:      100,
		},
		{
			name:      "add baz to protocol fee",
			tokenPath: "gno.land/r/baz",
			amount:    50,
			want:      50,
		},
		{
			name:      "add more baz to protocol fee",
			tokenPath: "gno.land/r/baz",
			amount:    10,
			want:      60,
		},
	}

	// Create fresh instance once for all subtests
	pf := createTestProtocolFee(t)

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			testing.SetRealm(testing.NewCodeRealm(poolPath))
			func (cur realm) {
				pf.AddToProtocolFee(test.tokenPath, test.amount)
			}(cross)
			uassert.Equal(t, pf.getProtocolFeeState().tokenListWithAmount[test.tokenPath], test.want)
		})
	}
}

func TestClearTokenListWithAmount(t *testing.T) {
	tests := []struct {
		name        string
		prevRealm   runtime.Realm
		want        map[string]int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "no permission to clear",
			prevRealm:   dummyRealm,
			shouldPanic: true,
			panicMsg:    "is not gov_staker",
		},
		{
			name:      "clear protocol fee",
			prevRealm: govStakerRealm,
			want: make(map[string]int64, 0),
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Reset and setup test data for each test case
			pf := createTestProtocolFee(t)
			pf.getProtocolFeeState().tokenListWithAmount = map[string]int64{
				"gno.land/r/foo": 100,
				"gno.land/r/baz": 200,
			}

			testing.SetRealm(test.prevRealm)

			if test.shouldPanic {
				uassert.AbortsContains(t, test.panicMsg, func() {
					func(cur realm) {
						pf.ClearTokenListWithAmount()
					}(cross)
				})
			} else {
				func(cur realm) {
					pf.ClearTokenListWithAmount()
				}(cross)
				uassert.Equal(t, len(pf.getProtocolFeeState().tokenListWithAmount), len(test.want))
			}
		})
	}
}

func TestAssertIsPoolOrPositionOrRouterOrStaker(t *testing.T) {
	tests := []struct {
		name        string
		prevRealm   runtime.Realm
		shouldPanic bool
		panicMsg    string
	}{
		// Allowed realms
		{
			name:      "caller is pool contract",
			prevRealm: testing.NewCodeRealm(poolPath),
		},
		{
			name:      "caller is position contract",
			prevRealm: testing.NewCodeRealm(positionPath),
		},
		{
			name:      "caller is router contract",
			prevRealm: testing.NewCodeRealm(routerPath),
		},
		{
			name:      "caller is staker contract",
			prevRealm: stakerRealm,
		},
		// Restricted realms
		{
			name:        "caller is unknown contract",
			prevRealm:   testing.NewCodeRealm("gno.land/r/unknown/contract"),
			shouldPanic: true,
			panicMsg:    "unauthorized: caller",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// When a function is defined to accept realm as a parameter,
			// there's no need to wrap it with an anonymous function,
			// but since the assertIsPoolOrPositionOrRouterOrStaker function doesn't accept a realm parameter,
			// it appears that a separate execution scope needs to be set up to distinguish realms,
			// and this anonymous function wrapping pattern must be maintained for the tests to pass.
			if test.shouldPanic {
				uassert.PanicsContains(t, test.panicMsg, func() {
					caller := test.prevRealm.Address()
					assertIsPoolOrPositionOrRouterOrStaker(caller)
				})
			} else {
				uassert.NotPanics(t, func() {
					caller := test.prevRealm.Address()
					assertIsPoolOrPositionOrRouterOrStaker(caller)
				})
			}
		})
	}
}

// func TestDistributeWithDifferentDevOpsPct(t *testing.T) {
// 	tests := []struct {
// 		name                    string
// 		devOpsPct               int64
// 		tokenAmount             int64
// 		expectedDevOpsAmount    int64
// 		expectedGovStakerAmount int64
// 	}{
// 		{
// 			name:                    "0% to DevOps",
// 			devOpsPct:               0,
// 			tokenAmount:             1000,
// 			expectedDevOpsAmount:    0,
// 			expectedGovStakerAmount: 1000,
// 		},
// 		{
// 			name:                    "25% to DevOps",
// 			devOpsPct:               2500,
// 			tokenAmount:             1000,
// 			expectedDevOpsAmount:    250,
// 			expectedGovStakerAmount: 750,
// 		},
// 		{
// 			name:                    "50% to DevOps",
// 			devOpsPct:               5000,
// 			tokenAmount:             1000,
// 			expectedDevOpsAmount:    500,
// 			expectedGovStakerAmount: 500,
// 		},
// 		{
// 			name:                    "100% to DevOps",
// 			devOpsPct:               10000,
// 			tokenAmount:             1000,
// 			expectedDevOpsAmount:    1000,
// 			expectedGovStakerAmount: 0,
// 		},
// 		{
// 			name:                    "33.33% to DevOps",
// 			devOpsPct:               3333,
// 			tokenAmount:             1000,
// 			expectedDevOpsAmount:    333,
// 			expectedGovStakerAmount: 667,
// 		},
// 	}

// 	for _, tt := range tests {
// 		t.Run(tt.name, func(t *testing.T) {
// 			pf := createTestProtocolFee(t)

// 			if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
// 				bar.Transfer(cross, adminAddr, balance)
// 			}
// 			if balance := bar.BalanceOf(devOpsAddr); balance > 0 {
// 				testing.SetRealm(testing.NewUserRealm(devOpsAddr))
// 				bar.Transfer(cross, adminAddr, balance)
// 				testing.SetRealm(adminRealm)
// 			}
// 			if balance := bar.BalanceOf(govStakerAddr); balance > 0 {
// 				testing.SetRealm(testing.NewUserRealm(govStakerAddr))
// 				bar.Transfer(cross, adminAddr, balance)
// 				testing.SetRealm(adminRealm)
// 			}

// 			testing.SetRealm(adminRealm)
// 			pf.SetDevOpsPct(tt.devOpsPct)
// 			uassert.Equal(t, pf.GetDevOpsPct(), tt.devOpsPct)

// 			testing.SetOriginCaller(adminAddr)
// 			bar.Transfer(cross, protocolFeeAddr, int64(tt.tokenAmount))

// 			// record the amount in protocol fee
// 			testing.SetRealm(stakerRealm)
// 			pf.AddToProtocolFee("gno.land/r/onbloc/bar", tt.tokenAmount)

// 			// initial state
// 			uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), int64(tt.tokenAmount))
// 			uassert.Equal(t, bar.BalanceOf(devOpsAddr), int64(0))
// 			uassert.Equal(t, bar.BalanceOf(govStakerAddr), int64(0))

// 			// distribute protocol fee
// 			testing.SetRealm(govStakerRealm)
// 			testing.SetOriginCaller(govStakerAddr)
// 			result := pf.DistributeProtocolFee()

// 			// final state
// 			uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), int64(0))
// 			uassert.Equal(t, bar.BalanceOf(devOpsAddr), int64(tt.expectedDevOpsAmount))
// 			uassert.Equal(t, bar.BalanceOf(govStakerAddr), int64(tt.expectedGovStakerAmount))

// 			if tt.expectedGovStakerAmount > 0 {
// 				uassert.Equal(t, result["gno.land/r/onbloc/bar"], tt.expectedGovStakerAmount)
// 			}

// 			uassert.Equal(t, len(pf.getProtocolFeeState().tokenListWithAmount), 0)
// 		})
// 	}
// }

// func TestBalanceAmountMismatch_Fix(t *testing.T) {
// 	tests := []struct {
// 		name                      string
// 		setupFunc                 func()
// 		tokenPath                 string
// 		recordedAmount            int64 // Amount recorded in TokenListWithAmount
// 		actualBalance             int64 // Actual token balance in protocol_fee
// 		externalTransferAmount    int64 // Amount transferred externally
// 		devOpsPct                 int64 // DevOps percentage (basis points)
// 		expectedDevOpsReceived    int64 // Expected amount DevOps should receive
// 		expectedGovStakerReceived int64 // Expected amount GovStaker should receive
// 		expectPanic               bool
// 		panicMsg                  string
// 	}{
// 		{
// 			name: "exact match - balance equals recorded amount",
// 			setupFunc: func() {
// 				// reset balances
// 				if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
// 					bar.Transfer(cross, adminAddr, balance)
// 				}
// 				if balance := bar.BalanceOf(devOpsAddr); balance > 0 {
// 					testing.SetRealm(testing.NewUserRealm(devOpsAddr))
// 					bar.Transfer(cross, adminAddr, balance)
// 					testing.SetRealm(adminRealm)
// 				}
// 				if balance := bar.BalanceOf(govStakerAddr); balance > 0 {
// 					testing.SetRealm(testing.NewUserRealm(govStakerAddr))
// 					bar.Transfer(cross, adminAddr, balance)
// 					testing.SetRealm(adminRealm)
// 				}

// 				// Admin transfers tokens to protocol_fee
// 				testing.SetRealm(adminRealm)
// 				testing.SetOriginCaller(adminAddr)
// 				bar.Transfer(cross, protocolFeeAddr, 1000)
// 			},
// 			tokenPath:                 "gno.land/r/onbloc/bar",
// 			recordedAmount:            1000,
// 			actualBalance:             1000,
// 			externalTransferAmount:    0,
// 			devOpsPct:                 2000, // 20%
// 			expectedDevOpsReceived:    200,
// 			expectedGovStakerReceived: 800,
// 			expectPanic:               false,
// 		},
// 		// {
// 		// 	name: "external transfer - balance exceeds recorded amount",
// 		// 	setupFunc: func() {
// 		// 		// Reset balances
// 		// 		if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 		}
// 		// 		if balance := bar.BalanceOf(devOpsAddr); balance > 0 {
// 		// 			testing.SetRealm(testing.NewUserRealm(devOpsAddr))
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 			testing.SetRealm(adminRealm)
// 		// 		}
// 		// 		if balance := bar.BalanceOf(govStakerAddr); balance > 0 {
// 		// 			testing.SetRealm(testing.NewUserRealm(govStakerAddr))
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 			testing.SetRealm(adminRealm)
// 		// 		}

// 		// 		// Admin transfers initial amount
// 		// 		testing.SetRealm(adminRealm)
// 		// 		testing.SetOriginCaller(adminAddr)
// 		// 		bar.Transfer(cross, protocolFeeAddr, 1000)

// 		// 		// External user sends additional tokens
// 		// 		bar.Transfer(cross, protocolFeeAddr, 500)
// 		// 	},
// 		// 	tokenPath:                 "gno.land/r/onbloc/bar",
// 		// 	recordedAmount:            1000,
// 		// 	actualBalance:             1500,
// 		// 	externalTransferAmount:    500,
// 		// 	devOpsPct:                 2000, // 20%
// 		// 	expectedDevOpsReceived:    200,  // 20% of 1000 (recorded amount only)
// 		// 	expectedGovStakerReceived: 800,  // 80% of 1000 (recorded amount only)
// 		// 	expectPanic:               false,
// 		// },
// 		// {
// 		// 	name: "recorded exceeds balance - should panic",
// 		// 	setupFunc: func() {
// 		// 		// Reset balances
// 		// 		if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 		}
// 		// 		if balance := bar.BalanceOf(devOpsAddr); balance > 0 {
// 		// 			testing.SetRealm(testing.NewUserRealm(devOpsAddr))
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 			testing.SetRealm(adminRealm)
// 		// 		}
// 		// 		if balance := bar.BalanceOf(govStakerAddr); balance > 0 {
// 		// 			testing.SetRealm(testing.NewUserRealm(govStakerAddr))
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 			testing.SetRealm(adminRealm)
// 		// 		}

// 		// 		// Admin transfers tokens
// 		// 		testing.SetRealm(adminRealm)
// 		// 		testing.SetOriginCaller(adminAddr)
// 		// 		bar.Transfer(cross, protocolFeeAddr, 500)
// 		// 	},
// 		// 	tokenPath:                 "gno.land/r/onbloc/bar",
// 		// 	recordedAmount:            1000, // More than actual balance
// 		// 	actualBalance:             500,
// 		// 	externalTransferAmount:    0,
// 		// 	devOpsPct:                 2000,
// 		// 	expectedDevOpsReceived:    0,
// 		// 	expectedGovStakerReceived: 0,
// 		// 	expectPanic:               true,
// 		// 	panicMsg:                  "[GNOSWAP-PROTOCOL_FEE-003] invalid amount || amount: 1000 should be less than or equal to balance: 500",
// 		// },
// 		// {
// 		// 	name: "multiple external transfers - all distributed",
// 		// 	setupFunc: func() {
// 		// 		// Reset balances
// 		// 		if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 		}
// 		// 		if balance := bar.BalanceOf(devOpsAddr); balance > 0 {
// 		// 			testing.SetRealm(testing.NewUserRealm(devOpsAddr))
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 			testing.SetRealm(adminRealm)
// 		// 		}
// 		// 		if balance := bar.BalanceOf(govStakerAddr); balance > 0 {
// 		// 			testing.SetRealm(testing.NewUserRealm(govStakerAddr))
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 			testing.SetRealm(adminRealm)
// 		// 		}

// 		// 		// Admin transfers initial amount
// 		// 		testing.SetRealm(adminRealm)
// 		// 		testing.SetOriginCaller(adminAddr)
// 		// 		bar.Transfer(cross, protocolFeeAddr, 100)

// 		// 		// Multiple external transfers
// 		// 		bar.Transfer(cross, protocolFeeAddr, 200)
// 		// 		bar.Transfer(cross, protocolFeeAddr, 300)
// 		// 		bar.Transfer(cross, protocolFeeAddr, 400)
// 		// 	},
// 		// 	tokenPath:                 "gno.land/r/onbloc/bar",
// 		// 	recordedAmount:            100,  // Only the recorded amount
// 		// 	actualBalance:             1000, // Total including external transfers
// 		// 	externalTransferAmount:    900,
// 		// 	devOpsPct:                 1000, // 10%
// 		// 	expectedDevOpsReceived:    10,   // 10% of 100 (recorded amount only)
// 		// 	expectedGovStakerReceived: 90,   // 90% of 100 (recorded amount only)
// 		// 	expectPanic:               false,
// 		// },
// 		// {
// 		// 	name: "zero recorded amount with external balance",
// 		// 	setupFunc: func() {
// 		// 		// Reset balances
// 		// 		if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 		}
// 		// 		if balance := bar.BalanceOf(devOpsAddr); balance > 0 {
// 		// 			testing.SetRealm(testing.NewUserRealm(devOpsAddr))
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 			testing.SetRealm(adminRealm)
// 		// 		}
// 		// 		if balance := bar.BalanceOf(govStakerAddr); balance > 0 {
// 		// 			testing.SetRealm(testing.NewUserRealm(govStakerAddr))
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 			testing.SetRealm(adminRealm)
// 		// 		}

// 		// 		// Only external transfer, no recorded amount
// 		// 		testing.SetRealm(adminRealm)
// 		// 		testing.SetOriginCaller(adminAddr)
// 		// 		bar.Transfer(cross, protocolFeeAddr, 1000)
// 		// 	},
// 		// 	tokenPath:                 "gno.land/r/onbloc/bar",
// 		// 	recordedAmount:            0,    // Nothing recorded
// 		// 	actualBalance:             1000, // But balance exists
// 		// 	externalTransferAmount:    1000,
// 		// 	devOpsPct:                 5000, // 50%
// 		// 	expectedDevOpsReceived:    0,    // Nothing distributed as recorded is 0
// 		// 	expectedGovStakerReceived: 0,    // Nothing distributed as recorded is 0
// 		// 	expectPanic:               false,
// 		// },
// 		// {
// 		// 	name: "100% to DevOps with external transfer",
// 		// 	setupFunc: func() {
// 		// 		// Reset balances
// 		// 		if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 		}
// 		// 		if balance := bar.BalanceOf(devOpsAddr); balance > 0 {
// 		// 			testing.SetRealm(testing.NewUserRealm(devOpsAddr))
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 			testing.SetRealm(adminRealm)
// 		// 		}
// 		// 		if balance := bar.BalanceOf(govStakerAddr); balance > 0 {
// 		// 			testing.SetRealm(testing.NewUserRealm(govStakerAddr))
// 		// 			bar.Transfer(cross, adminAddr, balance)
// 		// 			testing.SetRealm(adminRealm)
// 		// 		}

// 		// 		// Admin transfers
// 		// 		testing.SetRealm(adminRealm)
// 		// 		testing.SetOriginCaller(adminAddr)
// 		// 		bar.Transfer(cross, protocolFeeAddr, 800)

// 		// 		// External transfer
// 		// 		bar.Transfer(cross, protocolFeeAddr, 200)
// 		// 	},
// 		// 	tokenPath:                 "gno.land/r/onbloc/bar",
// 		// 	recordedAmount:            800,
// 		// 	actualBalance:             1000,
// 		// 	externalTransferAmount:    200,
// 		// 	devOpsPct:                 10000, // 100%
// 		// 	expectedDevOpsReceived:    800,   // All recorded amount goes to DevOps
// 		// 	expectedGovStakerReceived: 0,
// 		// 	expectPanic:               false,
// 		// },
// 	}

// 	for _, tt := range tests {
// 		t.Run(tt.name, func(t *testing.T) {
// 			tt.setupFunc()

// 			pf := createTestProtocolFee(t)

// 			testing.SetRealm(adminRealm)
// 			func(_ realm) {
// 				pf.SetDevOpsPct(tt.devOpsPct)
// 			}(cross)

// 			// record the amount in protocol fee
// 			if tt.recordedAmount > 0 {
// 				testing.SetRealm(stakerRealm)
// 				func(cur realm) {
// 					pf.AddToProtocolFee(tt.tokenPath, tt.recordedAmount)
// 				}(cross)
// 			}

// 			// check initial state
// 			uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), int64(tt.actualBalance))
// 			uassert.Equal(t, pf.getProtocolFeeState().tokenListWithAmount[tt.tokenPath], tt.recordedAmount)

// 			// distribute protocol fee
// 			testing.SetRealm(govStakerRealm)
// 			testing.SetOriginCaller(govStakerAddr)

// 			if tt.expectPanic {
// 				uassert.AbortsContains(t, tt.panicMsg, func() {
// 					func(_ realm) {
// 						pf.DistributeProtocolFee()
// 					}(cross)
// 				})
// 			} else {
// 				// func(_ realm) {
// 				// 	// record initial balances before distribution
// 				// 	prevDevOpsBalance := bar.BalanceOf(devOpsAddr)
// 				// 	prevGovStakerBalance := bar.BalanceOf(govStakerAddr)

// 				// 	result := pf.DistributeProtocolFee()

// 				// 	// check the actual amounts received (delta from previous balance)
// 				// 	actualDevOpsReceived := bar.BalanceOf(devOpsAddr) - prevDevOpsBalance
// 				// 	actualGovStakerReceived := bar.BalanceOf(govStakerAddr) - prevGovStakerBalance

// 				// 	// verify balances after distribution
// 				// 	if tt.recordedAmount == 0 {
// 				// 		// If recorded amount is 0, nothing should be distributed even if balance exists
// 				// 		uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), int64(tt.actualBalance))
// 				// 	} else {
// 				// 		// Only recorded amount should be distributed, external transfers remain
// 				// 		expectedRemaining := int64(tt.actualBalance) - int64(tt.recordedAmount)
// 				// 		uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), expectedRemaining)
// 				// 	}

// 				// 	uassert.Equal(t, actualDevOpsReceived, int64(tt.expectedDevOpsReceived))
// 				// 	uassert.Equal(t, actualGovStakerReceived, int64(tt.expectedGovStakerReceived))

// 				// 	// verify returned result
// 				// 	if tt.expectedGovStakerReceived > 0 {
// 				// 		uassert.Equal(t, result[tt.tokenPath], tt.expectedGovStakerReceived)
// 				// 	}

// 				// 	// verify TokenListWithAmount is cleared
// 				// 	uassert.Equal(t, len(pf.getProtocolFeeState().tokenListWithAmount), 0)
// 				// }(cross)
// 			}
// 		})
// 	}
// }
