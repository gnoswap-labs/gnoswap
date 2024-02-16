package position

import (
	"std"
	"testing"

	"encoding/gjson"

	_ "gno.land/r/demo/grc20_wrapper"
	p "gno.land/r/demo/pool"
)

var (
	test_tickLower       = int32(9000)
	test_tickUpper       = int32(11000)
	test_liquidityExpect = bigint(1000)
)

// 1. Init & Create Pool
func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(test1)
	p.InitManual()

	std.TestSetOrigCaller(test1)
	p.CreatePool(fooPath, barPath, fee500, 130621891405341611593710811006)

	// fee
	// 500		= 0.05% // USv3 default
	// 3000		= 0.3% // USv3 default
	// 10000	= 1% // USv3 default

	// sqrtPrice
	// 130621891405341611593710811006 // tick = 10000
	shouldPanic(t, func() { p.CreatePool(fooPath, barPath, 500, 130621891405341611593710811006) })
}

// 2. Mint LP and Get GNFT
func TestMint(t *testing.T) {
	// test1 mints => will get tid 1 nft
	std.TestSetOrigCaller(test1)
	Mint(fooPath, barPath, fee500, int32(9000), int32(11000), bigint(1_000_000), bigint(1_000_000), bigint(1), bigint(1), bigint(1234567890))

	// test1 mints => will get tid 2 nft
	std.TestSetOrigCaller(test1)
	Mint(fooPath, barPath, fee500, int32(4000), int32(6000), bigint(1_000_000), bigint(1_000_000), bigint(0), bigint(0), bigint(1234567890))
}

// 3. Swap to make position fee
func TestSwap(t *testing.T) {
	std.TestSetPrevRealm("gno.land/r/demo/router")
	std.TestSetOrigCaller(test1)
	p.Swap(
		fooPath,
		barPath,
		fee500,
		test1,
		true,
		bigint(123_456),
		MIN_PRICE,
		test1,
	)
}

func TestCollectFeeAfterSwap(t *testing.T) {
	// burn 0 to collect swap fee
	std.TestSetOrigCaller(test1)
	tokneId, fee0, fee1, fromPath := CollectFee(1)
	shouldEQ(t, tokneId, uint64(1))
	shouldEQ(t, fee0, bigint(61))
	shouldEQ(t, fee1, bigint(0))
	shouldEQ(t, fromPath, "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
}

// RPCs
func TestApiGetPositions(t *testing.T) {
	gpss := ApiGetPositions()
	jsonStr := gjson.Parse(gpss)
	shouldEQ(t, len(jsonStr.Get("response").Array()), 2)
}