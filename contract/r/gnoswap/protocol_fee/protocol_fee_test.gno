package protocol_fee

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _  = access.GetAddress(access.ROLE_ADMIN)
	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	adminRealm    = std.NewUserRealm(adminAddr)
	adminUser     = adminAddr
	dummyRealm    = std.NewCodeRealm("gno.land/r/dummy")
)

func TestDistributeProtocolFee(t *testing.T) {
	// admin > protocol_fee
	testing.SetRealm(adminRealm)
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 1000)
	qux.Transfer(cross, protocolFeeAddr, 1000)

	stakerRealm := std.NewCodeRealm(consts.STAKER_PATH)
	testing.SetRealm(stakerRealm)
	testing.SetOriginCaller(stakerAddr)
	AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)
	AddToProtocolFee(cross, "gno.land/r/onbloc/qux", 1000)

	uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), int64(1000))
	uassert.Equal(t, bar.BalanceOf(devOpsAddr), int64(0))
	uassert.Equal(t, bar.BalanceOf(govStakerAddr), int64(0))

	uassert.Equal(t, qux.BalanceOf(protocolFeeAddr), int64(1000))
	uassert.Equal(t, qux.BalanceOf(devOpsAddr), int64(0))
	uassert.Equal(t, qux.BalanceOf(govStakerAddr), int64(0))

	// gov/staker > protocol_fee
	govStakerRealm := std.NewCodeRealm(consts.GOV_STAKER_PATH)
	testing.SetRealm(govStakerRealm)
	testing.SetOriginCaller(govStakerAddr)
	DistributeProtocolFee(cross)

	uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), int64(0))
	uassert.Equal(t, bar.BalanceOf(devOpsAddr), int64(0))
	uassert.Equal(t, bar.BalanceOf(govStakerAddr), int64(1000))

	uassert.Equal(t, qux.BalanceOf(protocolFeeAddr), int64(0))
	uassert.Equal(t, qux.BalanceOf(devOpsAddr), int64(0))
	uassert.Equal(t, qux.BalanceOf(govStakerAddr), int64(1000))
}

func TestSetDevOpsPctByAdmin(t *testing.T) {
	tests := []struct {
		name        string
		realm       std.Realm
		percentage  uint64
		shouldPanic bool
		panicMsg    string
		expectedPct uint64
	}{
		{
			name:        "no permission to set devops percentage",
			realm:       std.NewUserRealm(testutils.TestAddress("dummy")),
			percentage:  123,
			shouldPanic: true,
			panicMsg:    "caller(g1v36k6mteta047h6lta047h6lta047h6lz7gmv8) has no permission",
		},
		{
			name:        "invalid percentage value",
			realm:       adminRealm,
			percentage:  100001,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(100001) should not be bigger than 10000",
		},
		{
			name:        "successfully set devops percentage",
			realm:       adminRealm,
			percentage:  123,
			shouldPanic: false,
			expectedPct: 123,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			testing.SetRealm(test.realm)

			if test.shouldPanic {
				uassert.AbortsWithMessage(t, test.panicMsg, func() {
					SetDevOpsPctByAdmin(cross, test.percentage)
				})
			} else {
				uassert.Equal(t, GetDevOpsPct(), uint64(0))
				SetDevOpsPctByAdmin(cross, test.percentage)
				uassert.Equal(t, GetDevOpsPct(), test.expectedPct)
			}
		})
	}
}

func TestTokenList(t *testing.T) {
	tokenListWithAmount = map[string]uint64{
		"gno.land/r/foo": 100,
		"gno.land/r/bar": 0,
		"gno.land/r/baz": 200,
	}

	uassert.Equal(t, len(TokenList(true)), 2)
	uassert.Equal(t, len(TokenList(false)), 3)
}

func TestAddToProtocolFee(t *testing.T) {
	tokenListWithAmount = map[string]uint64{}

	tests := []struct {
		name      string
		tokenPath string
		amount    uint64
		want      uint64
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

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			testing.SetRealm(std.NewCodeRealm(consts.POOL_PATH))
			AddToProtocolFee(cross, test.tokenPath, test.amount)
			uassert.Equal(t, tokenListWithAmount[test.tokenPath], test.want)
		})
	}
}

func TestClearTokenListWithAmount(t *testing.T) {
	tokenListWithAmount = map[string]uint64{
		"gno.land/r/foo": 100,
		"gno.land/r/baz": 200,
	}

	tests := []struct {
		name        string
		prevRealm   std.Realm
		want        map[string]uint64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "no permission to clear",
			prevRealm:   dummyRealm,
			shouldPanic: true,
			panicMsg:    "caller(g1lvx5ssxvuz5tttx6uza3myv8xy6w36a46fv7sy) has no permission",
		},
		{
			name:      "clear protocol fee",
			prevRealm: std.NewCodeRealm(consts.GOV_STAKER_PATH),
			want:      map[string]uint64{},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			testing.SetRealm(test.prevRealm)

			if test.shouldPanic {
				uassert.AbortsWithMessage(t, test.panicMsg, func() {
					ClearTokenListWithAmount(cross)
				})
			} else {
				ClearTokenListWithAmount(cross)
				uassert.Equal(t, len(tokenListWithAmount), len(test.want))
			}
		})
	}
}

func TestAssertOnlyPoolRouterStaker(t *testing.T) {
	tests := []struct {
		name        string
		prevRealm   std.Realm
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:      "caller is pool contract",
			prevRealm: std.NewCodeRealm(consts.POOL_PATH),
		},
		{
			name:      "caller is router contract",
			prevRealm: std.NewCodeRealm(consts.ROUTER_PATH),
		},
		{
			name:      "caller is staker contract",
			prevRealm: std.NewCodeRealm(consts.STAKER_PATH),
		},
		{
			name:        "caller is stranger",
			prevRealm:   dummyRealm,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] caller has no permission",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			testing.SetRealm(test.prevRealm)

			// When a function is defined to accept realm as a parameter,
			// there's no need to wrap it with an anonymous function,
			// but since the assertOnlyPoolRouterStaker function doesn't accept a realm parameter,
			// it appears that a separate execution scope needs to be set up to distinguish realms,
			// and this anonymous function wrapping pattern must be maintained for the tests to pass.
			if test.shouldPanic {
				uassert.AbortsWithMessage(t, test.panicMsg, func() {
					func(cur realm) {
						testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
						assertOnlyPoolRouterStaker()
					}(cross)
				})
			} else {
				uassert.NotPanics(t, func() {
					func(cur realm) {
						testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
						assertOnlyPoolRouterStaker()
					}(cross)
				})
			}
		})
	}
}
