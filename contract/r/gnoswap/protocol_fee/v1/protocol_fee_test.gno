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
	poolPath      = "gno.land/r/gnoswap/v1/pool"
	positionPath  = "gno.land/r/gnoswap/v1/position"
	routerPath    = "gno.land/r/gnoswap/router"
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
