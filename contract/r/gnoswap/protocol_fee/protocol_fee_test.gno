package protocol_fee

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"

	_ "gno.land/r/onbloc/baz"
	_ "gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	adminUser    = adminAddr
	dummyRealm   = std.NewCodeRealm("gno.land/r/dummy")
)

// func TestDistributeProtocolFee(t *testing.T) {
// 	// admin > protocol_fee
// 	// send qux, bar for testing
// 	func() {
// 		testing.SetRealm(adminRealm)
// 		bar.Transfer(protocolFeeAddr, 1000)
// 		qux.Transfer(protocolFeeAddr, 1000)
// 	}()

// 	// Add protocol fees
// 	func() {
// 		stakerRealm := std.NewCodeRealm(consts.STAKER_PATH)
// 		testing.SetRealm(stakerRealm)
// 		pf.AddToProtocolFee("gno.land/r/onbloc/bar", 1000)
// 		pf.AddToProtocolFee("gno.land/r/onbloc/qux", 1000)
// 	}()

// 	// // Check initial balances
// 	// func() {
// 	// 	govStakerRealm := std.NewCodeRealm(consts.GOV_STAKER_PATH)
// 	// 	testing.SetRealm(govStakerRealm)
// 	// 	uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), uint64(1000))
// 	// 	uassert.Equal(t, bar.BalanceOf(devOpsAddr), uint64(0))
// 	// 	uassert.Equal(t, bar.BalanceOf(govStakerAddr), uint64(0))

// 	// 	uassert.Equal(t, qux.BalanceOf(protocolFeeAddr), uint64(1000))
// 	// 	uassert.Equal(t, qux.BalanceOf(devOpsAddr), uint64(0))
// 	// 	uassert.Equal(t, qux.BalanceOf(govStakerAddr), uint64(0))
// 	// }()

// 	// // Distribute protocol fees
// 	// func() {
// 	// 	govStakerRealm := std.NewCodeRealm(consts.GOV_STAKER_PATH)
// 	// 	testing.SetRealm(govStakerRealm)
// 	// 	DistributeProtocolFee()
// 	// }()

// 	// // Verify final balances
// 	// func() {
// 	// 	govStakerRealm := std.NewCodeRealm(consts.GOV_STAKER_PATH)
// 	// 	testing.SetRealm(govStakerRealm)
// 	// 	uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), uint64(0))
// 	// 	uassert.Equal(t, bar.BalanceOf(devOpsAddr), uint64(0))
// 	// 	uassert.Equal(t, bar.BalanceOf(govStakerAddr), uint64(1000))

// 	// 	uassert.Equal(t, qux.BalanceOf(protocolFeeAddr), uint64(0))
// 	// 	uassert.Equal(t, qux.BalanceOf(devOpsAddr), uint64(0))
// 	// 	uassert.Equal(t, qux.BalanceOf(govStakerAddr), uint64(1000))
// 	// }()
// }

func TestSetDevOpsPctByAdminInvalidFee(t *testing.T) {
	testing.SetRealm(adminRealm)

	uassert.PanicsWithMessage(
		t,
		`[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(100001) should not be bigger than 10000`,
		func() {
			testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
			SetDevOpsPctByAdmin(100001)
		},
	)
}

func TestSetDevOpsPctByAdmin(t *testing.T) {
	testing.SetRealm(adminRealm)

	uassert.Equal(t, GetDevOpsPct(), uint64(0))

	func() {
		testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
		SetDevOpsPctByAdmin(123)
	}()
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
			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
				AddToProtocolFee(test.tokenPath, test.amount)
			}()

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
					testing.SetRealm(std.NewCodeRealm(consts.POOL_PATH))
					ClearTokenListWithAmount()
				})
			} else {
				func() {
					testing.SetRealm(std.NewCodeRealm(consts.POOL_PATH))
					ClearTokenListWithAmount()
				}()
				uassert.Equal(t, len(tokenListWithAmount), len(test.want))
			}
		})
	}
}

// func TestTransferProtocolFee(t *testing.T) {
// 	// change devOpsPct to 49% (51% is for gov/staker)
// 	devOpsPct = 4900

// 	// send(and add) to protocol fee
// 	transferToProtocolFee(t, "gno.land/r/onbloc/foo", 100)
// 	transferToProtocolFee(t, "gno.land/r/onbloc/baz", 201)

// 	// Check initial balances and distribute fees
// 	func() {
// 		govStakerRealm := std.NewCodeRealm(consts.GOV_STAKER_PATH)
// 		testing.SetRealm(govStakerRealm)

// 		// Check initial balances
// 		devOpsOldFoo := common.BalanceOf("gno.land/r/onbloc/foo", devOpsAddr)
// 		devOpsOldBaz := common.BalanceOf("gno.land/r/onbloc/baz", devOpsAddr)
// 		govStkaerOldFoo := common.BalanceOf("gno.land/r/onbloc/foo", govStakerAddr)
// 		govStkaerOldBaz := common.BalanceOf("gno.land/r/onbloc/baz", govStakerAddr)
// 		uassert.Equal(t, devOpsOldFoo, int64(0))
// 		uassert.Equal(t, devOpsOldBaz, int64(0))
// 		uassert.Equal(t, govStkaerOldFoo, int64(0))
// 		uassert.Equal(t, govStkaerOldBaz, int64(0))

// 		// Distribute protocol fees
// 		sentToGovStaker := DistributeProtocolFee()

// 		// Check final balances
// 		devOpsNewFoo := common.BalanceOf("gno.land/r/onbloc/foo", devOpsAddr)
// 		devOpsNewBaz := common.BalanceOf("gno.land/r/onbloc/baz", devOpsAddr)
// 		uassert.Equal(t, devOpsNewFoo, int64(49), "devOpsNewFoo should be 49")
// 		uassert.Equal(t, devOpsNewBaz, int64(98), "devOpsNewBaz should be 98")

// 		govStkaerNewFoo := common.BalanceOf("gno.land/r/onbloc/foo", govStakerAddr)
// 		govStkaerNewBaz := common.BalanceOf("gno.land/r/onbloc/baz", govStakerAddr)
// 		uassert.Equal(t, govStkaerNewFoo, int64(51), "govStkaerNewFoo should be 51")
// 		uassert.Equal(t, govStkaerNewBaz, int64(103), "govStkaerNewBaz should be 103")

// 		uassert.Equal(t, len(sentToGovStaker), 2)
// 		uassert.Equal(t, sentToGovStaker["gno.land/r/onbloc/foo"], int64(51), "sentToGovStaker[gno.land/r/onbloc/foo] should be 51")
// 		uassert.Equal(t, sentToGovStaker["gno.land/r/onbloc/baz"], int64(103), "sentToGovStaker[gno.land/r/onbloc/baz] should be 103")
// 	}()
// }

func transferToProtocolFee(t *testing.T, tokenPath string, amount uint64) {
	t.Helper()

	func() {
		// Set admin realm for token transfer
		testing.SetRealm(adminRealm)
		tokenTeller := common.GetTokenTeller(tokenPath)
		tokenTeller.Transfer(protocolFeeAddr, int64(amount))

		// Set gov/staker realm for updating protocol fee
		testing.SetRealm(std.NewCodeRealm(consts.GOV_STAKER_PATH))
		tokenListWithAmount[tokenPath] += amount
	}()
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
					testing.SetRealm(std.NewCodeRealm(consts.GOV_STAKER_PATH))
					assertOnlyPoolRouterStaker()
				})
			} else {
				uassert.NotPanics(t, func() {
					testing.SetRealm(std.NewCodeRealm(consts.GOV_STAKER_PATH))
					assertOnlyPoolRouterStaker()
				})
			}
		})
	}
}

func TestAssertOnlyGovStaker(t *testing.T) {
	tests := []struct {
		name        string
		prevRealm   std.Realm
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:      "caller is gov/staker contract",
			prevRealm: std.NewCodeRealm(consts.GOV_STAKER_PATH),
		},
		{
			name:        "caller is stranger",
			prevRealm:   dummyRealm,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-PROTOCOL_FEE-001] caller has no permission",
		},
	}
}
