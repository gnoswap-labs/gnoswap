package protocol_fee

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"

	// "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/baz"
	_ "gno.land/r/onbloc/foo"
	// "gno.land/r/onbloc/qux"
)

var (
	adminAddr, _  = access.GetAddress(access.ROLE_ADMIN)
	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	adminRealm    = std.NewUserRealm(adminAddr)
	adminUser     = adminAddr
	dummyRealm    = std.NewCodeRealm("gno.land/r/dummy")
)

// func TestDistributeProtocolFee(t *testing.T) {
// 	// admin > protocol_fee
// 	testing.SetRealm(adminRealm)
// 	testing.SetOriginCaller(adminAddr)
// 	func() {
// 		testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
// 		cross(bar.Transfer)(protocolFeeAddr, 1000)
// 		cross(qux.Transfer)(protocolFeeAddr, 1000)
// 	}()

// 	stakerRealm := std.NewCodeRealm(consts.STAKER_PATH)
// 	testing.SetRealm(stakerRealm)
// 	testing.SetOriginCaller(stakerAddr)
// 	func() {
// 		testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
// 		AddToProtocolFee("gno.land/r/onbloc/bar", 1000)
// 		AddToProtocolFee("gno.land/r/onbloc/qux", 1000)
// 	}()

// 	uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), int64(1000))
// 	uassert.Equal(t, bar.BalanceOf(devOpsAddr), int64(0))
// 	uassert.Equal(t, bar.BalanceOf(govStakerAddr), int64(0))

// 	uassert.Equal(t, qux.BalanceOf(protocolFeeAddr), int64(1000))
// 	uassert.Equal(t, qux.BalanceOf(devOpsAddr), int64(0))
// 	uassert.Equal(t, qux.BalanceOf(govStakerAddr), int64(0))

// 	// gov/staker > protocol_fee
// 	govStakerRealm := std.NewCodeRealm(consts.GOV_STAKER_PATH)
// 	testing.SetRealm(govStakerRealm)
// 	testing.SetOriginCaller(govStakerAddr)
// 	func() {
// 		testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
// 		DistributeProtocolFee()
// 	}()

// 	// uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), int64(0), "#1")
// 	// uassert.Equal(t, bar.BalanceOf(devOpsAddr), int64(0), "#2")
// 	// uassert.Equal(t, bar.BalanceOf(govStakerAddr), int64(1000), "#3")

// 	// uassert.Equal(t, qux.BalanceOf(protocolFeeAddr), int64(0), "#4")
// 	// uassert.Equal(t, qux.BalanceOf(devOpsAddr), int64(0), "#5")
// 	// uassert.Equal(t, qux.BalanceOf(govStakerAddr), int64(1000), "#6")
// }

func TestSetDevOpsPctByAdminNoPermission(t *testing.T) {
	dummy := testutils.TestAddress("dummy")
	dummyRealm := std.NewUserRealm(dummy)
	testing.SetRealm(dummyRealm)

	uassert.PanicsWithMessage(
		t, `caller(g1v36k6mteta047h6lta047h6lta047h6lz7gmv8) has no permission`, func() {
			func(cur realm) {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
				SetDevOpsPctByAdmin(cur, 123)
			}(cross)
		},
	)
}

func TestSetDevOpsPctByAdminInvalidFee(t *testing.T) {
	testing.SetRealm(adminRealm)

	uassert.PanicsWithMessage(
		t,
		`[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(100001) should not be bigger than 10000`,
		func(cur realm) {
			testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
			SetDevOpsPctByAdmin(cur, 100001)
		},
	)
}

func TestSetDevOpsPctByAdmin(t *testing.T) {
	testing.SetRealm(adminRealm)

	uassert.Equal(t, GetDevOpsPct(), uint64(0))

	func(cur realm) {
		testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
		SetDevOpsPctByAdmin(cur, 123)
	}(cross)
	uassert.Equal(t, GetDevOpsPct(), uint64(123))
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
			func(cur realm) {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
				AddToProtocolFee(cur, test.tokenPath, test.amount)
			}(cross)

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
				uassert.PanicsWithMessage(t, test.panicMsg, func() {
					func(cur realm) {
						testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
						ClearTokenListWithAmount(cur)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
					ClearTokenListWithAmount(cur)
				}(cross)
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

			if test.shouldPanic {
				uassert.PanicsWithMessage(t, test.panicMsg, func() {
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
