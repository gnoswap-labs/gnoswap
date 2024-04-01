package position

import (
	"gno.land/p/demo/json"

	"std"
	"testing"

	"gno.land/r/gnoswap/consts"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/gns"

	pl "gno.land/r/demo/pool"
)

// 1. Init & Create Pool
func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetPrevAddr(test1)
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()

	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE)
	pl.CreatePool(fooPath, barPath, fee500, "130621891405341611593710811006") // tick = 10000
}

// 2. Mint LP and Get GNFT
func TestMint(t *testing.T) {
	std.TestSetPrevAddr(test1)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	// test1 mints => will get tid 1 nft
	std.TestSetOrigCaller(test1)
	Mint(fooPath, barPath, fee500, int32(9000), int32(11000), "1000000", "1000000", "1", "1", max_timeout, test1.String())

	// test1 mints => will get tid 2 nft
	std.TestSetOrigCaller(test1)
	Mint(fooPath, barPath, fee500, int32(4000), int32(6000), "1000000", "1000000", "0", "0", max_timeout, test1.String())
}

// 3. Swap to make position fee
func TestSwap(t *testing.T) {
	std.TestSetPrevRealm(consts.ROUTER_PATH)
	std.TestSetOrigCaller(test1)
	pl.Swap(
		fooPath,
		barPath,
		fee500,
		test1.String(),
		true,
		"123456",
		consts.MIN_PRICE,
		test1.String(),
	)
}

func TestCollectFeeAfterSwap(t *testing.T) {
	// burn 0 to collect swap fee
	std.TestSetOrigCaller(test1)
	tokneId, fee0, fee1, fromPath := CollectFee(1)
	shouldEQ(t, tokneId, uint64(1))
	shouldEQ(t, fee0, "60")
	shouldEQ(t, fee1, "0")
	shouldEQ(t, fromPath, "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
}

// RPCs
func TestApiGetPositions(t *testing.T) {
	gpss := ApiGetPositions()

	root, err := json.Unmarshal([]byte(gpss))
	if err != nil {
		panic(err)
	}

	response, err := root.GetKey("response")
	if err != nil {
		panic(err)
	}

	shouldEQ(t, response.Size(), 2)
}
