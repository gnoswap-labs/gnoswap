package v1

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"

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
		store: &mockProtocolFeeStore{
			state: newProtocolFeeStateInternal(t),
		},
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
			want:      make(map[string]int64, 0),
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
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-003] invalid amount || amount(-1) should not be negative",
		},
		{
			name:        "error - negative large amount",
			tokenPath:   "gno.land/r/foo",
			amount:      -999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-003] invalid amount || amount(-999999) should not be negative",
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
				uassert.PanicsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.AddToProtocolFee(tt.tokenPath, tt.amount)
					}(cross)
				})
			} else {
				func(cur realm) {
					pf.AddToProtocolFee(tt.tokenPath, tt.amount)
				}(cross)
				if tt.amount > 0 {
					uassert.Equal(t, pf.getProtocolFeeState().tokenListWithAmount[tt.tokenPath], tt.amount)
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
			panicMsg:     "overflow detected",
		},
		{
			name:         "error - overflow with large values",
			tokenPath:    "gno.land/r/foo",
			initialValue: 9223372036854775800,
			addAmount:    10,
			shouldPanic:  true,
			panicMsg:     "overflow detected",
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
			pf.getProtocolFeeState().tokenListWithAmount[tt.tokenPath] = tt.initialValue
			testing.SetRealm(testing.NewCodeRealm(poolPath))

			// When & Then
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.AddToProtocolFee(tt.tokenPath, tt.addAmount)
					}(cross)
				})
			} else {
				func(cur realm) {
					pf.AddToProtocolFee(tt.tokenPath, tt.addAmount)
				}(cross)
				expectedTotal := tt.initialValue + tt.addAmount
				uassert.Equal(t, pf.getProtocolFeeState().tokenListWithAmount[tt.tokenPath], expectedTotal)
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
				uassert.PanicsContains(t, tt.panicMsg, func() {
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
			pf.getProtocolFeeState().accuToGovStaker.Set("gno.land/r/foo", int64(1000))
			testing.SetRealm(tt.prevRealm)

			// When & Then
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.panicMsg, func() {
					func(cur realm) {
						pf.ClearAccuTransferToGovStaker()
					}(cross)
				})
			} else {
				func(cur realm) {
					pf.ClearAccuTransferToGovStaker()
				}(cross)
				// Verify tree was cleared
				uassert.Equal(t, pf.getProtocolFeeState().accuToGovStaker.Size(), 0)
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
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(-1) should not be smaller than 0",
		},
		{
			name:        "error - very large negative",
			pct:         -999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(-999999) should not be smaller than 0",
		},
		{
			name:        "error - above maximum",
			pct:         10001,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(10001) should not be bigger than 10000",
		},
		{
			name:        "error - very large percentage",
			pct:         999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(999999) should not be bigger than 10000",
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
				uassert.PanicsContains(t, tt.panicMsg, func() {
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
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(-1) should not be smaller than 0",
		},
		{
			name:        "error - very large negative",
			pct:         -999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(-999999) should not be smaller than 0",
		},
		{
			name:        "error - above maximum",
			pct:         10001,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(10001) should not be bigger than 10000",
		},
		{
			name:        "error - very large percentage",
			pct:         999999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(999999) should not be bigger than 10000",
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
				uassert.PanicsContains(t, tt.panicMsg, func() {
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
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(-1) should not be smaller than 0",
		},
		{
			name:        "error - over maximum",
			pct:         10001,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(10001) should not be bigger than 10000",
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
