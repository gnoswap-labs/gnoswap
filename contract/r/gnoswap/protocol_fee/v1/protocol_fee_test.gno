package v1

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"

	_ "gno.land/r/gnoswap/rbac" // Initialize contract roles
)

var (
	adminAddr, _      = access.GetAddress(prbac.ROLE_ADMIN.String())
	stakerAddr, _     = access.GetAddress(prbac.ROLE_STAKER.String())
	governanceAddr, _ = access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	adminRealm        = testing.NewUserRealm(adminAddr)
	adminUser         = adminAddr
	dummyRealm        = testing.NewCodeRealm("gno.land/r/dummy")
	aliceAddr         = testutils.TestAddress("alice")

	// contract paths
	poolPath       = "gno.land/r/gnoswap/pool"
	positionPath   = "gno.land/r/gnoswap/position"
	routerPath     = "gno.land/r/gnoswap/router"
	stakerPath     = "gno.land/r/gnoswap/staker"
	govStakerPath  = "gno.land/r/gnoswap/gov/staker"
	governancePath = "gno.land/r/gnoswap/gov/governance"

	stakerRealm     = testing.NewCodeRealm(stakerPath)
	govStakerRealm  = testing.NewCodeRealm(govStakerPath)
	governanceRealm = testing.NewCodeRealm(governancePath)
)

// createTestProtocolFee creates a fresh protocolFeeV1 instance for testing
func createTestProtocolFee(t *testing.T) *protocolFeeV1 {
	t.Helper()

	return &protocolFeeV1{
		store: newMockProtocolFeeStore(),
	}
}

func TestDistributeProtocolFee(t *testing.T) {
	barPath := "gno.land/r/onbloc/bar"
	quxPath := "gno.land/r/onbloc/qux"

	tests := []struct {
		name                    string
		prevRealm               runtime.Realm
		devOpsPct               int64
		depositedBalances       map[string]int64
		devOpsBalanceChanges    map[string]int64
		govStakerBalanceChanges map[string]int64
		shouldPanic             bool
		panicMsg                string
	}{
		{
			name:                    "success - no tokens to distribute",
			prevRealm:               govStakerRealm,
			devOpsPct:               0,
			depositedBalances:       make(map[string]int64),
			devOpsBalanceChanges:    make(map[string]int64),
			govStakerBalanceChanges: make(map[string]int64),
		},
		{
			name:      "success - distribute protocol fee with 0% devOps (100% to govStaker)",
			prevRealm: govStakerRealm,
			devOpsPct: 0,
			depositedBalances: map[string]int64{
				barPath: 100,
				quxPath: 200,
			},
			devOpsBalanceChanges: map[string]int64{
				barPath: 0,
				quxPath: 0,
			},
			govStakerBalanceChanges: map[string]int64{
				barPath: 100,
				quxPath: 200,
			},
		},
		{
			name:      "success - distribute protocol fee with 10% devOps",
			prevRealm: govStakerRealm,
			devOpsPct: 1_000, // 10%
			depositedBalances: map[string]int64{
				barPath: 100,
				quxPath: 200,
			},
			devOpsBalanceChanges: map[string]int64{
				barPath: 10,
				quxPath: 20,
			},
			govStakerBalanceChanges: map[string]int64{
				barPath: 90,
				quxPath: 180,
			},
		},
		{
			name:      "success - distribute protocol fee with 50% devOps",
			prevRealm: govStakerRealm,
			devOpsPct: 5_000, // 50%
			depositedBalances: map[string]int64{
				barPath: 100,
				quxPath: 200,
			},
			devOpsBalanceChanges: map[string]int64{
				barPath: 50,
				quxPath: 100,
			},
			govStakerBalanceChanges: map[string]int64{
				barPath: 50,
				quxPath: 100,
			},
		},
		{
			name:      "success - distribute protocol fee with tiny amount 50% devOps",
			prevRealm: govStakerRealm,
			devOpsPct: 5_000, // 50%
			depositedBalances: map[string]int64{
				barPath: 1,
				quxPath: 3,
			},
			devOpsBalanceChanges: map[string]int64{
				barPath: 0,
				quxPath: 1,
			},
			govStakerBalanceChanges: map[string]int64{
				barPath: 1,
				quxPath: 2,
			},
		},
		{
			name:        "failure - caller is not admin or gov/staker",
			prevRealm:   testing.NewCodeRealm("gno.land/r/unknown/contract"),
			shouldPanic: true,
			panicMsg:    "unauthorized: caller g1pxn2ve8l38svvke6wzpvhkhld8xjktk66qpn5h is not admin or gov/staker",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			positionRealm := testing.NewCodeRealm("gno.land/r/gnoswap/position")
			protocolFeeRealm := testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee")

			pf := createTestProtocolFee(t)
			testing.SetRealm(adminRealm)

			func(cur realm) {
				testing.SetRealm(protocolFeeRealm)
				pf.SetDevOpsPct(test.devOpsPct)
			}(cross)

			for token, amount := range test.depositedBalances {
				testing.SetRealm(positionRealm)
				func(cur realm) {
					testing.SetRealm(protocolFeeRealm)
					pf.AddToProtocolFee(token, amount)
				}(cross)

				testing.SetRealm(adminRealm)
				common.SafeGRC20Transfer(cross, token, protocolFeeAddr, amount)
			}

			testing.SetRealm(test.prevRealm)

			beforeDevOpsBalances := make(map[string]int64)
			beforeGovStakerBalances := make(map[string]int64)

			for token := range test.depositedBalances {
				beforeDevOpsBalances[token] = common.BalanceOf(token, devOpsAddr)
				beforeGovStakerBalances[token] = common.BalanceOf(token, govStakerAddr)
			}

			if test.shouldPanic {
				uassert.AbortsContains(t, test.panicMsg, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
						pf.DistributeProtocolFee()
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
					pf.DistributeProtocolFee()
				}(cross)
			}

			for token, beforeDevOpsBalance := range beforeDevOpsBalances {
				afterDevOpsBalance := common.BalanceOf(token, devOpsAddr)
				uassert.Equal(
					t,
					afterDevOpsBalance-beforeDevOpsBalance,
					test.devOpsBalanceChanges[token],
					ufmt.Sprintf("token: %s, beforeDevOpsBalance: %d, afterDevOpsBalance: %d, test.devOpsBalanceChanges[token]: %d", token, beforeDevOpsBalance, afterDevOpsBalance, test.devOpsBalanceChanges[token]),
				)
			}

			for token, beforeGovStakerBalance := range beforeGovStakerBalances {
				afterGovStakerBalance := common.BalanceOf(token, govStakerAddr)
				uassert.Equal(
					t,
					afterGovStakerBalance-beforeGovStakerBalance,
					test.govStakerBalanceChanges[token],
					ufmt.Sprintf("token: %s, beforeGovStakerBalance: %d, afterGovStakerBalance: %d, test.govStakerBalanceChanges[token]: %d", token, beforeGovStakerBalance, afterGovStakerBalance, test.govStakerBalanceChanges[token]),
				)
			}
		})
	}
}

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
			func(cur realm) {
				pf.AddToProtocolFee(test.tokenPath, test.amount)
			}(cross)

			tokenListWithAmount := pf.store.GetTokenListWithAmounts()
			amountAny, ok := tokenListWithAmount.Get(test.tokenPath)
			uassert.True(t, ok)
			uassert.Equal(t, amountAny.(int64), test.want)
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
			want:      make(map[string]int64, 0),
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Reset and setup test data for each test case
			pf := createTestProtocolFee(t)
			tokenList := avl.NewTree()
			tokenList.Set("gno.land/r/foo", int64(100))
			tokenList.Set("gno.land/r/baz", int64(200))
			pf.store.SetTokenListWithAmounts(tokenList)

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

				tokenListWithAmount := pf.store.GetTokenListWithAmounts()
				uassert.Equal(t, tokenListWithAmount.Size(), len(test.want))
			}
		})
	}
}

func TestProtocolFee_AddToProtocolFee_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		tokenPath   string
		amount      int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "error - negative amount",
			tokenPath:   "gno.land/r/foo",
			amount:      -1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid amount || amount(-1) should not be negative",
		},
		{
			name:        "error - negative large amount",
			tokenPath:   "gno.land/r/foo",
			amount:      -999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid amount || amount(-999999) should not be negative",
		},
		{
			name:      "success - zero amount",
			tokenPath: "gno.land/r/foo",
			amount:    0,
		},
		{
			name:      "success - minimum positive amount",
			tokenPath: "gno.land/r/foo",
			amount:    1,
		},
		{
			name:      "success - large amount",
			tokenPath: "gno.land/r/foo",
			amount:    9223372036854775806, // MAX_INT64 - 1
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			testing.SetRealm(testing.NewCodeRealm(poolPath))

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.AddToProtocolFee(tt.tokenPath, tt.amount)
					}(cross)
				})
			} else {
				func(cur realm) {
					pf.AddToProtocolFee(tt.tokenPath, tt.amount)
				}(cross)
				if tt.amount > 0 {
					value, ok := pf.getProtocolFeeState().TokenListWithAmounts().Get(tt.tokenPath)
					uassert.True(t, ok)
					uassert.Equal(t, value.(int64), tt.amount)
				}
			}
		})
	}
}

func TestProtocolFee_AddToProtocolFee_Overflow(t *testing.T) {
	tests := []struct {
		name         string
		tokenPath    string
		initialValue int64
		addAmount    int64
		shouldPanic  bool
		panicMsg     string
	}{
		{
			name:         "error - overflow at boundary",
			tokenPath:    "gno.land/r/foo",
			initialValue: 9223372036854775806, // MAX_INT64 - 1
			addAmount:    2,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "error - overflow with large values",
			tokenPath:    "gno.land/r/foo",
			initialValue: 9223372036854775800,
			addAmount:    10,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "success - at exact boundary",
			tokenPath:    "gno.land/r/foo",
			initialValue: 9223372036854775806, // MAX_INT64 - 1
			addAmount:    1,
			shouldPanic:  false,
		},
		{
			name:         "success - normal addition",
			tokenPath:    "gno.land/r/foo",
			initialValue: 1000,
			addAmount:    500,
			shouldPanic:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			pf.getProtocolFeeState().TokenListWithAmounts().Set(tt.tokenPath, tt.initialValue)
			testing.SetRealm(testing.NewCodeRealm(poolPath))

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.AddToProtocolFee(tt.tokenPath, tt.addAmount)
					}(cross)
				})
			} else {
				func(cur realm) {
					pf.AddToProtocolFee(tt.tokenPath, tt.addAmount)
				}(cross)
				expectedTotal := tt.initialValue + tt.addAmount
				value, ok := pf.getProtocolFeeState().TokenListWithAmounts().Get(tt.tokenPath)
				uassert.True(t, ok)
				uassert.Equal(t, value.(int64), expectedTotal)
			}
		})
	}
}

func TestProtocolFee_AddToProtocolFee_UnauthorizedCaller(t *testing.T) {
	tests := []struct {
		name        string
		prevRealm   runtime.Realm
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "error - unauthorized user realm",
			prevRealm:   testing.NewUserRealm(aliceAddr),
			shouldPanic: true,
			panicMsg:    "unauthorized: caller",
		},
		{
			name:        "error - unauthorized code realm",
			prevRealm:   testing.NewCodeRealm("gno.land/r/unknown/contract"),
			shouldPanic: true,
			panicMsg:    "unauthorized: caller",
		},
		{
			name:        "success - pool contract",
			prevRealm:   testing.NewCodeRealm(poolPath),
			shouldPanic: false,
		},
		{
			name:        "success - position contract",
			prevRealm:   testing.NewCodeRealm(positionPath),
			shouldPanic: false,
		},
		{
			name:        "success - router contract",
			prevRealm:   testing.NewCodeRealm(routerPath),
			shouldPanic: false,
		},
		{
			name:        "success - staker contract",
			prevRealm:   stakerRealm,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			testing.SetRealm(tt.prevRealm)

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.AddToProtocolFee("gno.land/r/foo", 100)
					}(cross)
				})
			} else {
				uassert.NotPanics(t, func() {
					func(cur realm) {
						pf.AddToProtocolFee("gno.land/r/foo", 100)
					}(cross)
				})
			}
		})
	}
}

func TestProtocolFee_ClearAccuTransferToGovStaker(t *testing.T) {
	tests := []struct {
		name        string
		prevRealm   runtime.Realm
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "error - unauthorized caller",
			prevRealm:   dummyRealm,
			shouldPanic: true,
			panicMsg:    "is not gov_staker",
		},
		{
			name:        "error - admin cannot clear",
			prevRealm:   adminRealm,
			shouldPanic: true,
			panicMsg:    "is not gov_staker",
		},
		{
			name:        "success - gov staker can clear",
			prevRealm:   govStakerRealm,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			pf.store.SetAccuToGovStakerItem("gno.land/r/foo", int64(1000))
			testing.SetRealm(tt.prevRealm)

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.ClearAccuTransferToGovStaker()
					}(cross)
				})
			} else {
				func(cur realm) {
					pf.ClearAccuTransferToGovStaker()
				}(cross)
				// Verify tree was cleared
				uassert.Equal(t, pf.store.GetAccuToGovStaker().Size(), 0)
			}
		})
	}
}

func TestProtocolFee_SetDevOpsPct_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		pct         int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "error - negative percentage",
			pct:         -1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(-1) should not be smaller than 0",
		},
		{
			name:        "error - very large negative",
			pct:         -999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(-999999) should not be smaller than 0",
		},
		{
			name:        "error - above maximum",
			pct:         10001,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(10001) should not be bigger than 10000",
		},
		{
			name:        "error - very large percentage",
			pct:         999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(999999) should not be bigger than 10000",
		},
		{
			name:        "success - minimum boundary (0%)",
			pct:         0,
			shouldPanic: false,
		},
		{
			name:        "success - maximum boundary (100%)",
			pct:         10000,
			shouldPanic: false,
		},
		{
			name:        "success - middle value (50%)",
			pct:         5000,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			testing.SetRealm(adminRealm)

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.SetDevOpsPct(tt.pct)
					}(cross)
				})
			} else {
				func(cur realm) {
					pf.SetDevOpsPct(tt.pct)
				}(cross)
				uassert.Equal(t, pf.getProtocolFeeState().DevOpsPct(), tt.pct)
				uassert.Equal(t, pf.getProtocolFeeState().GovStakerPct(), 10000-tt.pct)
			}
		})
	}
}

func TestProtocolFee_SetGovStakerPct_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		pct         int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "error - negative percentage",
			pct:         -1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(-1) should not be smaller than 0",
		},
		{
			name:        "error - very large negative",
			pct:         -999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(-999999) should not be smaller than 0",
		},
		{
			name:        "error - above maximum",
			pct:         10001,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(10001) should not be bigger than 10000",
		},
		{
			name:        "error - very large percentage",
			pct:         999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(999999) should not be bigger than 10000",
		},
		{
			name:        "success - minimum boundary (0%)",
			pct:         0,
			shouldPanic: false,
		},
		{
			name:        "success - maximum boundary (100%)",
			pct:         10000,
			shouldPanic: false,
		},
		{
			name:        "success - middle value (75%)",
			pct:         7500,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			testing.SetRealm(adminRealm)

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.SetGovStakerPct(tt.pct)
					}(cross)
				})
			} else {
				func(cur realm) {
					pf.SetGovStakerPct(tt.pct)
				}(cross)
				uassert.Equal(t, pf.getProtocolFeeState().GovStakerPct(), tt.pct)
				uassert.Equal(t, pf.getProtocolFeeState().DevOpsPct(), 10000-tt.pct)
			}
		})
	}
}

func TestProtocolFee_AssertIsValidPercent(t *testing.T) {
	tests := []struct {
		name        string
		pct         int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "error - negative",
			pct:         -1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(-1) should not be smaller than 0",
		},
		{
			name:        "error - over maximum",
			pct:         10001,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(10001) should not be bigger than 10000",
		},
		{
			name:        "success - zero",
			pct:         0,
			shouldPanic: false,
		},
		{
			name:        "success - maximum",
			pct:         10000,
			shouldPanic: false,
		},
		{
			name:        "success - middle",
			pct:         5000,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When & Then
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.panicMsg, func() {
					assertIsValidPercent(tt.pct)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidPercent(tt.pct)
				})
			}
		})
	}
}

func TestDistributeProtocolFee_AmountExceedsBalance(t *testing.T) {
	tokenPath := "gno.land/r/onbloc/bar"

	t.Run("error - recorded amount exceeds actual balance", func(t *testing.T) {
		pf := createTestProtocolFee(t)

		// Get current actual balance at protocolFeeAddr
		currentBalance := common.BalanceOf(tokenPath, protocolFeeAddr)

		// Set recorded amount to be greater than actual balance
		recordedAmount := currentBalance + 1000

		pf.store.SetTokenListWithAmountItem(tokenPath, recordedAmount)

		testing.SetRealm(govStakerRealm)

		uassert.AbortsContains(t, "should be less than or equal to balance", func() {
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
				pf.DistributeProtocolFee()
			}(cross)
		})
	})

	t.Run("error - large recorded amount exceeds actual balance", func(t *testing.T) {
		pf := createTestProtocolFee(t)

		// Get current actual balance at protocolFeeAddr
		currentBalance := common.BalanceOf(tokenPath, protocolFeeAddr)

		// Set recorded amount to be much greater than actual balance
		recordedAmount := currentBalance + 999999999

		pf.store.SetTokenListWithAmountItem(tokenPath, recordedAmount)

		testing.SetRealm(govStakerRealm)

		uassert.AbortsContains(t, "should be less than or equal to balance", func() {
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
				pf.DistributeProtocolFee()
			}(cross)
		})
	})
}

func TestProtocolFee_SetDevOpsPct_UnauthorizedCaller(t *testing.T) {
	tests := []struct {
		name        string
		prevRealm   runtime.Realm
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "error - unauthorized user",
			prevRealm:   testing.NewUserRealm(aliceAddr),
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "error - unauthorized code realm",
			prevRealm:   testing.NewCodeRealm("gno.land/r/unknown/contract"),
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "error - pool contract cannot set",
			prevRealm:   testing.NewCodeRealm(poolPath),
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "error - staker contract cannot set",
			prevRealm:   stakerRealm,
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "error - gov staker cannot set (only admin or governance)",
			prevRealm:   govStakerRealm,
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "success - admin can set",
			prevRealm:   adminRealm,
			shouldPanic: false,
		},
		{
			name:        "success - governance can set",
			prevRealm:   governanceRealm,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := createTestProtocolFee(t)
			testing.SetRealm(tt.prevRealm)

			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.SetDevOpsPct(5000)
					}(cross)
				})
			} else {
				uassert.NotPanics(t, func() {
					func(cur realm) {
						pf.SetDevOpsPct(5000)
					}(cross)
				})
			}
		})
	}
}

func TestProtocolFee_SetGovStakerPct_UnauthorizedCaller(t *testing.T) {
	tests := []struct {
		name        string
		prevRealm   runtime.Realm
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "error - unauthorized user",
			prevRealm:   testing.NewUserRealm(aliceAddr),
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "error - unauthorized code realm",
			prevRealm:   testing.NewCodeRealm("gno.land/r/unknown/contract"),
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "error - pool contract cannot set",
			prevRealm:   testing.NewCodeRealm(poolPath),
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "error - staker contract cannot set",
			prevRealm:   stakerRealm,
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "error - gov staker cannot set (only admin or governance)",
			prevRealm:   govStakerRealm,
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "success - admin can set",
			prevRealm:   adminRealm,
			shouldPanic: false,
		},
		{
			name:        "success - governance can set",
			prevRealm:   governanceRealm,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := createTestProtocolFee(t)
			testing.SetRealm(tt.prevRealm)

			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.SetGovStakerPct(5000)
					}(cross)
				})
			} else {
				uassert.NotPanics(t, func() {
					func(cur realm) {
						pf.SetGovStakerPct(5000)
					}(cross)
				})
			}
		})
	}
}

func TestProtocolFee_HaltState(t *testing.T) {
	setHaltAndRestore := func(t *testing.T, level halt.HaltLevel) func() {
		t.Helper()
		testing.SetRealm(adminRealm)
		halt.SetHaltLevel(cross, level)
		return func() {
			testing.SetRealm(adminRealm)
			halt.SetHaltLevel(cross, halt.HaltLevelNone)
		}
	}

	tests := []struct {
		name        string
		haltLevel   halt.HaltLevel
		setupRealm  func()
		operation   func(pf *protocolFeeV1)
		shouldAbort bool
		abortMsg    string
	}{
		{
			name:       "DistributeProtocolFee halted in emergency",
			haltLevel:  halt.HaltLevelEmergency,
			setupRealm: func() { testing.SetRealm(govStakerRealm) },
			operation: func(pf *protocolFeeV1) {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
					pf.DistributeProtocolFee()
				}(cross)
			},
			shouldAbort: true,
			abortMsg:    "halted: protocol_fee",
		},
		{
			name:       "SetDevOpsPct halted in emergency",
			haltLevel:  halt.HaltLevelEmergency,
			setupRealm: func() { testing.SetRealm(adminRealm) },
			operation: func(pf *protocolFeeV1) {
				func(cur realm) {
					pf.SetDevOpsPct(5000)
				}(cross)
			},
			shouldAbort: true,
			abortMsg:    "halted: protocol_fee",
		},
		{
			name:       "SetGovStakerPct halted in emergency",
			haltLevel:  halt.HaltLevelEmergency,
			setupRealm: func() { testing.SetRealm(adminRealm) },
			operation: func(pf *protocolFeeV1) {
				func(cur realm) {
					pf.SetGovStakerPct(5000)
				}(cross)
			},
			shouldAbort: true,
			abortMsg:    "halted: protocol_fee",
		},
		{
			name:       "AddToProtocolFee halted in emergency",
			haltLevel:  halt.HaltLevelEmergency,
			setupRealm: func() { testing.SetRealm(testing.NewCodeRealm(poolPath)) },
			operation: func(pf *protocolFeeV1) {
				func(cur realm) {
					pf.AddToProtocolFee("gno.land/r/onbloc/bar", 100)
				}(cross)
			},
			shouldAbort: true,
			abortMsg:    "halted: protocol_fee",
		},
		{
			name:       "ClearTokenListWithAmount halted in emergency",
			haltLevel:  halt.HaltLevelEmergency,
			setupRealm: func() { testing.SetRealm(govStakerRealm) },
			operation: func(pf *protocolFeeV1) {
				func(cur realm) {
					pf.ClearTokenListWithAmount()
				}(cross)
			},
			shouldAbort: true,
			abortMsg:    "halted: protocol_fee",
		},
		{
			name:       "ClearAccuTransferToGovStaker halted in emergency",
			haltLevel:  halt.HaltLevelEmergency,
			setupRealm: func() { testing.SetRealm(govStakerRealm) },
			operation: func(pf *protocolFeeV1) {
				func(cur realm) {
					pf.ClearAccuTransferToGovStaker()
				}(cross)
			},
			shouldAbort: true,
			abortMsg:    "halted: protocol_fee",
		},
		{
			name:       "SetDevOpsPct works in safe mode",
			haltLevel:  halt.HaltLevelSafeMode,
			setupRealm: func() {}, // realm set inside operation for non-aborting case
			operation: func(pf *protocolFeeV1) {
				testing.SetRealm(adminRealm)
				func(cur realm) {
					pf.SetDevOpsPct(5000)
				}(cross)
			},
			shouldAbort: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := createTestProtocolFee(t)
			restore := setHaltAndRestore(t, tt.haltLevel)
			defer restore()

			tt.setupRealm()

			if tt.shouldAbort {
				uassert.AbortsContains(t, tt.abortMsg, func() {
					tt.operation(pf)
				})
			} else {
				uassert.NotPanics(t, func() {
					tt.operation(pf)
				})
			}
		})
	}
}
