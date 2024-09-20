package router

import (
	"std"
	"testing"

	"gno.land/p/demo/json"

	"gno.land/r/gnoswap/v2/consts"

	pl "gno.land/r/gnoswap/v2/pool"

	"gno.land/r/gnoswap/v2/gns"

	"gno.land/r/demo/wugnot"
	"gno.land/r/onbloc/qux"
)

func TestCreatePool(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee()*3)

	pl.CreatePool(quxPath, consts.GNOT, fee500, "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	// 1 bar ≈ 19.683 gnot

	jsonStr := pl.ApiGetPools()
	root, err := json.Unmarshal([]byte(jsonStr))
	if err != nil {
		panic(err)
	}

	response, err := root.GetKey("response")
	if err != nil {
		panic(err)
	}

	shouldEQ(t, response.Size(), 1)
}

func TestSwapRouteWugnotquxExactIn(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	wugnot.Approve(a2u(consts.ROUTER_ADDR), 1000000)
	qux.Approve(a2u(consts.ROUTER_ADDR), 1000000)
	std.TestSetOrigSend(std.Coins{{"ugnot", 12345}}, nil) //sented ugnot amount
	shouldPanicWithMsg(t,
		func() {
			SwapRoute(
				consts.GNOT, // inputToken
				quxPath,     // outputToken
				"3",         // amountSpecified   -> should be panic
				"EXACT_IN",  // swapType
				"gno.land/r/demo/wugnot:gno.land/r/onbloc/qux:500", // strRouteArr
				"100", // quoteArr
				"1",   // tokenAmountLimit
			)
		},
		"[ROUTER] Invalid amount of ugnot sent by user",
	)
}
