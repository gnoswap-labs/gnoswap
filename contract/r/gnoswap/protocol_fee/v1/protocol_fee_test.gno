package v1

import (
	"chain/runtime"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"

	_ "gno.land/r/gnoswap/rbac" // Initialize contract roles

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	adminUser     = adminAddr
	dummyRealm    = testing.NewCodeRealm("gno.land/r/dummy")
	aliceAddr     = testutils.TestAddress("alice")

	// contract paths
	poolPath      = "gno.land/r/gnoswap/pool"
	positionPath  = "gno.land/r/gnoswap/position"
	routerPath    = "gno.land/r/gnoswap/router"
	stakerPath    = "gno.land/r/gnoswap/staker"
	govStakerPath = "gno.land/r/gnoswap/gov/staker"

	stakerRealm    = testing.NewCodeRealm(stakerPath)
	govStakerRealm = testing.NewCodeRealm(govStakerPath)
)

// createTestProtocolFee creates a fresh protocolFeeV1 instance for testing
func createTestProtocolFee(t *testing.T) *protocolFeeV1 {
	t.Helper()

	return &protocolFeeV1{
		store: newMockProtocolFeeStore(),
	}
}

func transferTokenTo(cur realm, t *testing.T, tokenPath string, to address, amount int64) {
	t.Helper()

	testing.SetRealm(adminRealm)

	switch tokenPath {
	case "gno.land/r/onbloc/bar":
		bar.Transfer(cross(cur), to, amount)
	case "gno.land/r/onbloc/obl":
		obl.Transfer(cross(cur), to, amount)
	case "gno.land/r/onbloc/qux":
		qux.Transfer(cross(cur), to, amount)
	default:
		panic(ufmt.Sprintf("unsupported token path: %s", tokenPath))
	}
}

func approveProtocolFeeSpender(cur realm, t *testing.T, ownerRealm runtime.Realm, tokenPath string, amount int64) {
	t.Helper()

	testing.SetRealm(ownerRealm)
	protocolFeeV1Realm := testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1")

	switch tokenPath {
	case "gno.land/r/onbloc/bar":
		bar.Approve(cross(cur), protocolFeeAddr, amount)
		bar.Approve(cross(cur), protocolFeeV1Realm.Address(), amount)
	case "gno.land/r/onbloc/obl":
		obl.Approve(cross(cur), protocolFeeAddr, amount)
		obl.Approve(cross(cur), protocolFeeV1Realm.Address(), amount)
	case "gno.land/r/onbloc/qux":
		qux.Approve(cross(cur), protocolFeeAddr, amount)
		qux.Approve(cross(cur), protocolFeeV1Realm.Address(), amount)
	default:
		panic(ufmt.Sprintf("unsupported token path: %s", tokenPath))
	}
}

func fundRealmAndApproveProtocolFee(cur realm, t *testing.T, ownerRealm runtime.Realm, tokenPath string, amount int64) {
	if t != nil {
		t.Helper()
	}

	if amount <= 0 {
		return
	}

	transferTokenTo(cross(cur), t, tokenPath, ownerRealm.Address(), amount)
	approveProtocolFeeSpender(cross(cur), t, ownerRealm, tokenPath, amount)
}

func fundAndApproveProtocolFee(cur realm, holderRealm runtime.Realm, tokenPath string, amount int64) {
	fundRealmAndApproveProtocolFee(cross(cur), nil, holderRealm, tokenPath, amount)
}

// TestDistributeProtocolFee_NoTokens covers the no-op path where there are
// no reserved tokens to distribute. Authorization is exercised via the
// inner crossing closure: the SetRealm'd caller becomes cur.Previous() inside
// pf.DistributeProtocolFee, satisfying assertIsAdminOrGovStaker.
func TestDistributeProtocolFee_NoTokens(cur realm, t *testing.T) {
	tests := []struct {
		name      string
		prevRealm runtime.Realm
		devOpsPct int64
	}{
		{
			name:      "success - no tokens to distribute (gov/staker, 0% devOps)",
			prevRealm: govStakerRealm,
			devOpsPct: 0,
		},
		{
			name:      "success - no tokens to distribute (gov/staker, 50% devOps)",
			prevRealm: govStakerRealm,
			devOpsPct: 5_000,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(cur realm, t *testing.T) {
			pf := createTestProtocolFee(t)

			testing.SetRealm(adminRealm)
			func(cur realm) {
				pf.SetDevOpsPct(0, cur, test.devOpsPct)
			}(cross(cur))

			testing.SetRealm(test.prevRealm)
			func(cur realm) {
				pf.DistributeProtocolFee(0, cur)
			}(cross(cur))
		})
	}
}

// TestDistributeProtocolFee_Unauthorized covers the authorization-failure path.
// The inner crossing closure carries the SetRealm'd caller into rlm.Previous(),
// which assertIsAdminOrGovStaker rejects with the expected message.
func TestDistributeProtocolFee_Unauthorized(cur realm, t *testing.T) {
	tests := []struct {
		name      string
		prevRealm runtime.Realm
		panicMsg  string
	}{
		{
			name:      "failure - caller is not admin or gov/staker",
			prevRealm: testing.NewCodeRealm("gno.land/r/unknown/contract"),
			panicMsg:  "unauthorized: caller g1pxn2ve8l38svvke6wzpvhkhld8xjktk66qpn5h is not admin or gov/staker",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(cur realm, t *testing.T) {
			pf := createTestProtocolFee(t)

			testing.SetRealm(test.prevRealm)
			uassert.AbortsContains(t, cur, test.panicMsg, func() {
				func(cur realm) {
					pf.DistributeProtocolFee(0, cur)
				}(cross(cur))
			})
		})
	}
}

// TestDistributeProtocolFee_WithDeposits covers the distribution arithmetic
// (devOps split, gov/staker split, rounding for tiny amounts).
//
// We assert only the accounting state recorded inside pf — the accumulated
// totals and the per-recipient "actual distributed" history — because the
// underlying token transfer at distribution time requires the call to enter
// the protocol_fee proxy realm (so cross(rlm) inside distributeToDevOps
// observes sender = protocolFeeAddr where the pooled balance lives). The
// inner-cross test pattern cannot synthesize that proxy frame: the inner
// cur's address resolves to the v1 package realm, and the proxy realm is
// reachable only via a real cross-call from /r/gnoswap/protocol_fee, which
// tests cannot construct.
//
// Token-transfer side effects of DistributeProtocolFee are covered by the
// scenario/integration suite where the call actually enters via the proxy.
func TestDistributeProtocolFee_WithDeposits(cur realm, t *testing.T) {
	tests := []struct {
		name              string
		devOpsPct         int64
		depositedBalances map[string]int64
		wantAccuDevOps    map[string]int64
		wantAccuGovStaker map[string]int64
	}{
		{
			name:      "success - distribute protocol fee with 10% devOps",
			devOpsPct: 1_000, // 10%
			depositedBalances: map[string]int64{
				"gno.land/r/onbloc/bar": 100,
				"gno.land/r/onbloc/qux": 200,
			},
			wantAccuDevOps: map[string]int64{
				"gno.land/r/onbloc/bar": 10,
				"gno.land/r/onbloc/qux": 20,
			},
			wantAccuGovStaker: map[string]int64{
				"gno.land/r/onbloc/bar": 90,
				"gno.land/r/onbloc/qux": 180,
			},
		},
		{
			name:      "success - distribute protocol fee with 50% devOps",
			devOpsPct: 5_000, // 50%
			depositedBalances: map[string]int64{
				"gno.land/r/onbloc/bar": 100,
				"gno.land/r/onbloc/qux": 200,
			},
			wantAccuDevOps: map[string]int64{
				"gno.land/r/onbloc/bar": 50,
				"gno.land/r/onbloc/qux": 100,
			},
			wantAccuGovStaker: map[string]int64{
				"gno.land/r/onbloc/bar": 50,
				"gno.land/r/onbloc/qux": 100,
			},
		},
		{
			name:      "success - distribute protocol fee with tiny amount 50% devOps",
			devOpsPct: 5_000, // 50%
			depositedBalances: map[string]int64{
				"gno.land/r/onbloc/bar": 1,
				"gno.land/r/onbloc/qux": 3,
			},
			wantAccuDevOps: map[string]int64{
				"gno.land/r/onbloc/bar": 0,
				"gno.land/r/onbloc/qux": 1,
			},
			wantAccuGovStaker: map[string]int64{
				"gno.land/r/onbloc/bar": 1,
				"gno.land/r/onbloc/qux": 2,
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(cur realm, t *testing.T) {
			positionRealm := testing.NewCodeRealm("gno.land/r/gnoswap/position")

			pf := createTestProtocolFee(t)

			testing.SetRealm(adminRealm)
			func(cur realm) {
				pf.SetDevOpsPct(0, cur, test.devOpsPct)
			}(cross(cur))

			for token, amount := range test.depositedBalances {
				fundRealmAndApproveProtocolFee(cross(cur), t, positionRealm, token, amount)
				testing.SetRealm(positionRealm)
				func(cur realm) {
					pf.AddToProtocolFee(0, cur, token, amount)
				}(cross(cur))
			}

			// Assert accumulated split totals recorded by AddToProtocolFee.
			// This validates devOps/govStaker arithmetic without depending on
			// the proxy-realm balance transfer that DistributeProtocolFee
			// performs (see comment on this test function).
			for token, wantDevOps := range test.wantAccuDevOps {
				gotDevOps := pf.GetAccuTransferToDevOpsByTokenPath(token)
				uassert.Equal(
					t,
					gotDevOps,
					wantDevOps,
					ufmt.Sprintf("devOps accu mismatch for %s: got %d, want %d", token, gotDevOps, wantDevOps),
				)
			}

			for token, wantGovStaker := range test.wantAccuGovStaker {
				gotGovStaker := pf.GetAccuTransferToGovStakerByTokenPath(token)
				uassert.Equal(
					t,
					gotGovStaker,
					wantGovStaker,
					ufmt.Sprintf("govStaker accu mismatch for %s: got %d, want %d", token, gotGovStaker, wantGovStaker),
				)
			}
		})
	}
}

func TestAddToProtocolFee(cur realm, t *testing.T) {
	tests := []struct {
		name                  string
		tokenPath             string
		initialAmount         int64
		amount                int64
		wantReservedGovStaker int64
	}{
		{
			name:                  "add bar to protocol fee",
			tokenPath:             "gno.land/r/onbloc/bar",
			amount:                100,
			wantReservedGovStaker: 100,
		},
		{
			name:                  "add qux to protocol fee",
			tokenPath:             "gno.land/r/onbloc/qux",
			amount:                50,
			wantReservedGovStaker: 50,
		},
		{
			name:                  "reserve more qux immediately",
			tokenPath:             "gno.land/r/onbloc/qux",
			initialAmount:         50,
			amount:                10,
			wantReservedGovStaker: 60,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(cur realm, t *testing.T) {
			pf := createTestProtocolFee(t)
			poolRealm := testing.NewCodeRealm(poolPath)

			if test.initialAmount > 0 {
				fundRealmAndApproveProtocolFee(cross(cur), t, poolRealm, test.tokenPath, test.initialAmount)
				testing.SetRealm(poolRealm)
				func(cur realm) {
					pf.AddToProtocolFee(0, cur, test.tokenPath, test.initialAmount)
				}(cross(cur))
			}

			beforeBalance := common.BalanceOf(test.tokenPath, protocolFeeAddr)

			fundRealmAndApproveProtocolFee(cross(cur), t, poolRealm, test.tokenPath, test.amount)
			testing.SetRealm(poolRealm)
			func(cur realm) {
				pf.AddToProtocolFee(0, cur, test.tokenPath, test.amount)
			}(cross(cur))

			reservedTokens := pf.store.GetReservedTokens()
			uassert.Equal(t, len(reservedTokens), 1)
			uassert.Equal(t, reservedTokens[0], test.tokenPath)
			uassert.Equal(t, pf.GetAccuTransferToGovStakerByTokenPath(test.tokenPath), test.wantReservedGovStaker)
			uassert.Equal(t, common.BalanceOf(test.tokenPath, protocolFeeAddr)-beforeBalance, test.amount)
		})
	}
}

func TestProtocolFee_AddToProtocolFee_EdgeCases(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		tokenPath   string
		amount      int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "error - negative amount",
			tokenPath:   "gno.land/r/onbloc/bar",
			amount:      -1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid amount || amount(-1) should not be negative",
		},
		{
			name:        "error - negative large amount",
			tokenPath:   "gno.land/r/onbloc/bar",
			amount:      -999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid amount || amount(-999999) should not be negative",
		},
		{
			name:      "success - zero amount",
			tokenPath: "gno.land/r/onbloc/bar",
			amount:    0,
		},
		{
			name:      "success - minimum positive amount",
			tokenPath: "gno.land/r/onbloc/bar",
			amount:    1,
		},
		{
			name:      "success - large amount",
			tokenPath: "gno.land/r/onbloc/bar",
			// Keep this within the test token supply now that AddToProtocolFee
			// performs a real TransferFrom from the caller realm.
			amount: 1_000_000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			poolRealm := testing.NewCodeRealm(poolPath)
			beforeBalance := common.BalanceOf(tt.tokenPath, protocolFeeAddr)
			fundRealmAndApproveProtocolFee(cross(cur), t, poolRealm, tt.tokenPath, tt.amount)
			testing.SetRealm(poolRealm)

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, tt.panicMsg, func() {
					func(cur realm) {
						pf.AddToProtocolFee(0, cur, tt.tokenPath, tt.amount)
					}(cross(cur))
				})
			} else {
				func(cur realm) {
					pf.AddToProtocolFee(0, cur, tt.tokenPath, tt.amount)
				}(cross(cur))
				if tt.amount > 0 {
					uassert.Equal(t, pf.GetAccuTransferToGovStakerByTokenPath(tt.tokenPath), tt.amount)
					uassert.Equal(t, pf.getProtocolFeeState().ReservedTokens()[0], tt.tokenPath)
					uassert.Equal(t, common.BalanceOf(tt.tokenPath, protocolFeeAddr)-beforeBalance, tt.amount)
				}
			}
		})
	}
}

func TestProtocolFee_AddToProtocolFee_Overflow(cur realm, t *testing.T) {
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
			tokenPath:    "gno.land/r/onbloc/bar",
			initialValue: 9223372036854775806, // MAX_INT64 - 1
			addAmount:    2,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "error - overflow with large values",
			tokenPath:    "gno.land/r/onbloc/bar",
			initialValue: 9223372036854775800,
			addAmount:    10,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "success - at exact boundary",
			tokenPath:    "gno.land/r/onbloc/bar",
			initialValue: 9223372036854775806, // MAX_INT64 - 1
			addAmount:    1,
			shouldPanic:  false,
		},
		{
			name:         "success - normal addition",
			tokenPath:    "gno.land/r/onbloc/bar",
			initialValue: 1000,
			addAmount:    500,
			shouldPanic:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			pfs := pf.getProtocolFeeState()
			if err := pfs.addAccuToGovStaker(0, cur, tt.tokenPath, tt.initialValue); err != nil {
				panic(err)
			}
			poolRealm := testing.NewCodeRealm(poolPath)
			fundRealmAndApproveProtocolFee(cross(cur), t, poolRealm, tt.tokenPath, tt.addAmount)
			testing.SetRealm(poolRealm)

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, tt.panicMsg, func() {
					func(cur realm) {
						pf.AddToProtocolFee(0, cur, tt.tokenPath, tt.addAmount)
					}(cross(cur))
				})
			} else {
				func(cur realm) {
					pf.AddToProtocolFee(0, cur, tt.tokenPath, tt.addAmount)
				}(cross(cur))
				expectedTotal := tt.initialValue + tt.addAmount
				uassert.Equal(t, pfs.GetAccuTransferToGovStakerByTokenPath(tt.tokenPath), expectedTotal)
				uassert.Equal(t, pfs.ReservedTokens()[0], tt.tokenPath)
			}
		})
	}
}

func TestProtocolFee_AddToProtocolFee_UnauthorizedCaller(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			if !tt.shouldPanic {
				fundRealmAndApproveProtocolFee(cross(cur), t, tt.prevRealm, "gno.land/r/onbloc/bar", 100)
			}
			testing.SetRealm(tt.prevRealm)

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, tt.panicMsg, func() {
					func(cur realm) {
						pf.AddToProtocolFee(0, cur, "gno.land/r/onbloc/bar", 100)
					}(cross(cur))
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					func(cur realm) {
						pf.AddToProtocolFee(0, cur, "gno.land/r/onbloc/bar", 100)
					}(cross(cur))
				})
			}
		})
	}
}

func TestProtocolFee_SetDevOpsPct_EdgeCases(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			testing.SetRealm(adminRealm)

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, tt.panicMsg, func() {
					func(cur realm) {
						pf.SetDevOpsPct(0, cur, tt.pct)
					}(cross(cur))
				})
			} else {
				func(cur realm) {
					pf.SetDevOpsPct(0, cur, tt.pct)
				}(cross(cur))
				uassert.Equal(t, pf.getProtocolFeeState().DevOpsPct(), tt.pct)
				uassert.Equal(t, pf.getProtocolFeeState().GovStakerPct(), 10000-tt.pct)
			}
		})
	}
}

func TestProtocolFee_SetGovStakerPct_EdgeCases(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			testing.SetRealm(adminRealm)

			// When & Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, tt.panicMsg, func() {
					func(cur realm) {
						pf.SetGovStakerPct(0, cur, tt.pct)
					}(cross(cur))
				})
			} else {
				func(cur realm) {
					pf.SetGovStakerPct(0, cur, tt.pct)
				}(cross(cur))
				uassert.Equal(t, pf.getProtocolFeeState().GovStakerPct(), tt.pct)
				uassert.Equal(t, pf.getProtocolFeeState().DevOpsPct(), 10000-tt.pct)
			}
		})
	}
}

func TestProtocolFee_AssertIsValidPercent(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// When & Then
			if tt.shouldPanic {
				uassert.PanicsContains(t, cur, tt.panicMsg, func() {
					assertIsValidPercent(tt.pct)
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					assertIsValidPercent(tt.pct)
				})
			}
		})
	}
}

func TestSetDevOpsPct_HaltScenario(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm)
		cleanup     func(cur realm)
		pct         int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "panic - protocol fee admin change remains blocked during emergency",
			setup: func(cur realm) {
				testing.SetOriginCaller(adminAddr)
				halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
			},
			cleanup: func(cur realm) {
				testing.SetOriginCaller(adminAddr)
				halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
			},
			pct:         5000,
			shouldPanic: true,
			panicMsg:    "halted: protocol_fee",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			if tt.setup != nil {
				tt.setup(cur)
			}
			defer func() {
				if tt.cleanup != nil {
					tt.cleanup(cur)
				}
			}()

			testing.SetRealm(adminRealm)

			// When - Then
			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, cur, tt.panicMsg, func() {
					func(cur realm) {
						pf.SetDevOpsPct(0, cur, tt.pct)
					}(cross(cur))
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					func(cur realm) {
						pf.SetDevOpsPct(0, cur, tt.pct)
					}(cross(cur))
				})
			}
		})
	}
}

func TestSetDevOpsPct_UnauthorizedCaller(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		prevRealm   runtime.Realm
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "panic - unauthorized user",
			prevRealm:   testing.NewUserRealm(aliceAddr),
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "panic - pool contract cannot set",
			prevRealm:   testing.NewCodeRealm(poolPath),
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "panic - staker contract cannot set",
			prevRealm:   stakerRealm,
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "success - admin can set",
			prevRealm:   adminRealm,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			testing.SetRealm(tt.prevRealm)

			// When - Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, tt.panicMsg, func() {
					func(cur realm) {
						pf.SetDevOpsPct(0, cur, 5000)
					}(cross(cur))
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					func(cur realm) {
						pf.SetDevOpsPct(0, cur, 5000)
					}(cross(cur))
				})
			}
		})
	}
}

func TestSetGovStakerPct_HaltScenario(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm)
		cleanup     func(cur realm)
		pct         int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "panic - gov staker pct change remains blocked during emergency",
			setup: func(cur realm) {
				testing.SetOriginCaller(adminAddr)
				halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
			},
			cleanup: func(cur realm) {
				testing.SetOriginCaller(adminAddr)
				halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
			},
			pct:         5000,
			shouldPanic: true,
			panicMsg:    "halted: protocol_fee",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			if tt.setup != nil {
				tt.setup(cur)
			}
			defer func() {
				if tt.cleanup != nil {
					tt.cleanup(cur)
				}
			}()

			testing.SetRealm(adminRealm)

			// When - Then
			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, cur, tt.panicMsg, func() {
					func(cur realm) {
						pf.SetGovStakerPct(0, cur, tt.pct)
					}(cross(cur))
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					func(cur realm) {
						pf.SetGovStakerPct(0, cur, tt.pct)
					}(cross(cur))
				})
			}
		})
	}
}

func TestSetGovStakerPct_UnauthorizedCaller(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		prevRealm   runtime.Realm
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "panic - unauthorized user",
			prevRealm:   testing.NewUserRealm(aliceAddr),
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "panic - pool contract cannot set",
			prevRealm:   testing.NewCodeRealm(poolPath),
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "panic - gov staker contract cannot set",
			prevRealm:   govStakerRealm,
			shouldPanic: true,
			panicMsg:    "is not admin or governance",
		},
		{
			name:        "success - admin can set",
			prevRealm:   adminRealm,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			testing.SetRealm(tt.prevRealm)

			// When - Then
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, tt.panicMsg, func() {
					func(cur realm) {
						pf.SetGovStakerPct(0, cur, 5000)
					}(cross(cur))
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					func(cur realm) {
						pf.SetGovStakerPct(0, cur, 5000)
					}(cross(cur))
				})
			}
		})
	}
}

func TestDistributeProtocolFee_HaltScenario_SafeMode(cur realm, t *testing.T) {
	// Given
	pf := createTestProtocolFee(t)

	if err := pf.getProtocolFeeState().addAccuToGovStaker(0, cur, "gno.land/r/onbloc/bar", 100); err != nil {
		panic(err)
	}
	if err := pf.store.AddReservedToken(0, cur, "gno.land/r/onbloc/bar"); err != nil {
		panic(err)
	}

	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelSafeMode)
	defer func() {
		func(cur realm) {
			testing.SetOriginCaller(adminAddr)
			testing.SetRealm(adminRealm)
			halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
		}(cross(cur))
	}()

	testing.SetRealm(adminRealm)
	common.SafeGRC20Transfer(cross(cur), "gno.land/r/onbloc/bar", protocolFeeAddr, 100)

	testing.SetRealm(govStakerRealm)

	// When - Then: the call returns without panicking and without
	// touching distribution state.
	uassert.NotPanics(t, cur, func() {
		func(cur realm) {
			pf.DistributeProtocolFee(0, cur)
		}(cross(cur))
	})

	uassert.Equal(t, int64(100), pf.GetAccuTransferToGovStakerByTokenPath("gno.land/r/onbloc/bar"))
	uassert.Equal(t, int64(0), pf.GetActualDistributedToGovStakerByTokenPath("gno.land/r/onbloc/bar"))
	uassert.Equal(t, 1, len(pf.getProtocolFeeState().ReservedTokens()))
	uassert.Equal(t, "gno.land/r/onbloc/bar", pf.getProtocolFeeState().ReservedTokens()[0])
}

func TestDistributeProtocolFee_HaltScenario_Emergency(cur realm, t *testing.T) {
	pf := createTestProtocolFee(t)

	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
	defer func() {
		func(cur realm) {
			testing.SetOriginCaller(adminAddr)
			testing.SetRealm(adminRealm)
			halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
		}(cross(cur))
	}()

	testing.SetRealm(govStakerRealm)

	uassert.NotPanics(t, cur, func() {
		func(cur realm) {
			pf.DistributeProtocolFee(0, cur)
		}(cross(cur))
	})

	// State assertions: no reserves, no distribution recorded.
	uassert.Equal(t, 0, len(pf.getProtocolFeeState().ReservedTokens()))
	uassert.Equal(t, int64(0), pf.GetActualDistributedToGovStakerByTokenPath("gno.land/r/onbloc/bar"))
	uassert.Equal(t, int64(0), pf.GetActualDistributedToDevOpsByTokenPath("gno.land/r/onbloc/bar"))
}

func TestAddToProtocolFee_HaltScenario(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm)
		cleanup     func(cur realm)
		shouldPanic bool
		panicMsg    string
		assertState func(t *testing.T, pf *protocolFeeV1)
	}{
		{
			name: "success - protocol fee accrual returns error during emergency",
			setup: func(cur realm) {
				testing.SetOriginCaller(adminAddr)
				halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
			},
			cleanup: func(cur realm) {
				testing.SetOriginCaller(adminAddr)
				halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
			},
			shouldPanic: false,
			panicMsg:    "",
			assertState: func(t *testing.T, pf *protocolFeeV1) {
				uassert.Equal(t, 0, len(pf.store.GetReservedTokens()))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)
			if tt.setup != nil {
				tt.setup(cur)
			}
			defer func() {
				if tt.cleanup != nil {
					tt.cleanup(cur)
				}
			}()

			holderRealm := testing.NewCodeRealm(poolPath)
			fundAndApproveProtocolFee(cross(cur), holderRealm, "gno.land/r/onbloc/bar", 100)
			testing.SetRealm(holderRealm)

			// When - Then
			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, cur, tt.panicMsg, func() {
					func(cur realm) {
						pf.AddToProtocolFee(0, cur, "gno.land/r/foo", 100)
					}(cross(cur))
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					func(cur realm) {
						err := pf.AddToProtocolFee(0, cur, "gno.land/r/onbloc/bar", 100)
						uassert.NotNil(t, err)
					}(cross(cur))
				})
				if tt.assertState != nil {
					tt.assertState(t, pf)
				}
			}
		})
	}
}

func TestSafeAddInt64(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:     "success - positive + positive",
			a:        100,
			b:        200,
			expected: 300,
		},
		{
			name:     "success - positive + negative",
			a:        100,
			b:        -50,
			expected: 50,
		},
		{
			name:     "success - negative + negative",
			a:        -100,
			b:        -200,
			expected: -300,
		},
		{
			name:     "success - zero + positive",
			a:        0,
			b:        100,
			expected: 100,
		},
		{
			name:     "success - zero + zero",
			a:        0,
			b:        0,
			expected: 0,
		},
		{
			name:        "panic - overflow",
			a:           9223372036854775807, // MaxInt64
			b:           1,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "panic - overflow with large positives",
			a:           9223372036854775800,
			b:           100,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "panic - underflow",
			a:           -9223372036854775808, // MinInt64
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
		{
			name:        "panic - underflow with large negatives",
			a:           -9223372036854775800,
			b:           -100,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, tt.panicMsg, func() {
					safeAddInt64(tt.a, tt.b)
				})
			} else {
				result := safeAddInt64(tt.a, tt.b)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestSafeSubInt64(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:     "success - positive - positive (positive result)",
			a:        200,
			b:        100,
			expected: 100,
		},
		{
			name:     "success - positive - positive (negative result)",
			a:        100,
			b:        200,
			expected: -100,
		},
		{
			name:     "success - positive - negative",
			a:        100,
			b:        -50,
			expected: 150,
		},
		{
			name:     "success - negative - negative",
			a:        -100,
			b:        -200,
			expected: 100,
		},
		{
			name:     "success - zero - positive",
			a:        0,
			b:        100,
			expected: -100,
		},
		{
			name:     "success - zero - zero",
			a:        0,
			b:        0,
			expected: 0,
		},
		{
			name:        "panic - underflow",
			a:           -9223372036854775808, // MinInt64
			b:           1,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "panic - underflow with large values",
			a:           -9223372036854775800,
			b:           100,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "panic - overflow",
			a:           9223372036854775807, // MaxInt64
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		{
			name:        "panic - overflow with large values",
			a:           9223372036854775800,
			b:           -100,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, tt.panicMsg, func() {
					safeSubInt64(tt.a, tt.b)
				})
			} else {
				result := safeSubInt64(tt.a, tt.b)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestSafeMulDiv(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		c           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:     "success - simple multiplication and division",
			a:        100,
			b:        50,
			c:        10,
			expected: 500,
		},
		{
			name:     "success - percentage calculation",
			a:        1000,
			b:        2500,
			c:        10000,
			expected: 250,
		},
		{
			name:     "success - zero numerator",
			a:        0,
			b:        100,
			c:        10,
			expected: 0,
		},
		{
			name:     "success - zero multiplier",
			a:        100,
			b:        0,
			c:        10,
			expected: 0,
		},
		{
			name:        "panic - division by zero",
			a:           100,
			b:           50,
			c:           0,
			shouldPanic: true,
			panicMsg:    "division by zero in safeMulDiv",
		},
		{
			name:        "panic - multiplication overflow (positive * positive)",
			a:           9223372036854775807, // MaxInt64
			b:           2,
			c:           1,
			shouldPanic: true,
			panicMsg:    "int64 multiplication overflow in safeMulDiv",
		},
		{
			name:        "panic - multiplication underflow (positive * negative)",
			a:           9223372036854775807,
			b:           -2,
			c:           1,
			shouldPanic: true,
			panicMsg:    "int64 multiplication underflow in safeMulDiv",
		},
		{
			name:        "panic - multiplication underflow (negative * positive)",
			a:           -9223372036854775808, // MinInt64
			b:           2,
			c:           1,
			shouldPanic: true,
			panicMsg:    "int64 multiplication underflow in safeMulDiv",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, tt.panicMsg, func() {
					safeMulDiv(tt.a, tt.b, tt.c)
				})
			} else {
				result := safeMulDiv(tt.a, tt.b, tt.c)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}
