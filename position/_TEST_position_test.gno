package position

import (
	"encoding/gjson"
	"std"
	"testing"

	"gno.land/r/demo/consts"

	pl "gno.land/r/demo/pool"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/foo"

	"gno.land/r/demo/gnft"
	"gno.land/r/demo/gns"
)

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	pl.InitManual()

	std.TestSetPrevAddr(test1)
	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE)

	pl.CreatePool(barPath, fooPath, fee500, "130621891405341611593710811006") // tick = 10000
}

func TestMintPosition01InRange(t *testing.T) {
	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.POOL_ADDR), 18394892)
	foo.Approve(a2u(consts.POOL_ADDR), 50000000)

	tokenId, liquidity, amount0, amount1 := Mint(
		barPath,
		fooPath,
		fee500,
		8000,
		12000,
		"50000000",
		"50000000",
		"0",
		"0",
		max_timeout,
		test1.String(),
	)
	shouldEQ(t, tokenId, 1)
	shouldEQ(t, getNextId(), 2)
	shouldEQ(t, amount0, "18394892")
	shouldEQ(t, amount1, "49999999")
}

func TestMintPosition02LowerRange(t *testing.T) {
	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.POOL_ADDR), 0)
	foo.Approve(a2u(consts.POOL_ADDR), 50000000)

	tokenId, liquidity, amount0, amount1 := Mint(
		barPath,
		fooPath,
		fee500,
		5000,
		8000,
		"50000000",
		"50000000",
		"0",
		"0",
		max_timeout,
		test1.String(),
	)
	shouldEQ(t, tokenId, 2)
	shouldEQ(t, getNextId(), 3)
	shouldEQ(t, amount0, "0")
	shouldEQ(t, amount1, "49999999")
}

func TestMintPosition03UpperRange(t *testing.T) {
	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.POOL_ADDR), 50000000)
	foo.Approve(a2u(consts.POOL_ADDR), 0)

	tokenId, liquidity, amount0, amount1 := Mint(
		barPath,
		fooPath,
		fee500,
		12000,
		14000,
		"50000000",
		"50000000",
		"0",
		"0",
		max_timeout,
		test1.String(),
	)
	shouldEQ(t, tokenId, 3)
	shouldEQ(t, getNextId(), 4)
	shouldEQ(t, amount0, "50000000")
	shouldEQ(t, amount1, "0")
}

func TestCollectFeeBeforeSwap(t *testing.T) {
	tokenId, fee0, fee1, poolPath := CollectFee(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, fee0, "0")
	shouldEQ(t, fee1, "0")
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
}

func TestSwap(t *testing.T) {
	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.POOL_ADDR), 1234567)

	std.TestSetPrevRealm(consts.ROUTER_PATH)
	std.TestSetOrigCaller(test1)
	amount0, amount1 := pl.Swap(
		barPath,
		fooPath,
		fee500,
		test1,
		true,
		"1234567",
		consts.MIN_PRICE,
		test1,
	)
	shouldEQ(t, amount0, "1234567")
	shouldEQ(t, amount1, "-3332779")
}

func TestCollectFeeAfterSwap(t *testing.T) {
	std.TestSetPrevAddr(test1)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX) // COLLECT_FEE
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX) // COLLECT_FEE

	tokenId, fee0, fee1, poolPath := CollectFee(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldNEQ(t, fee0, "0") // this is input token
	shouldEQ(t, fee1, "0")  // this it output token
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
}

func TestDecreaseLiquidityUpperPosition(t *testing.T) {
	std.TestSetPrevAddr(test1)

	ownerOfPosition := gnft.OwnerOf(tid(3))
	shouldEQ(t, ownerOfPosition, std.GetOrigCaller())

	tokenId, liquidity, fee0, fee1, amount0, amount1, poolPath := DecreaseLiquidity(uint64(3), 100, "0", "0", max_timeout, false)
	shouldEQ(t, tokenId, uint64(3))
	shouldEQ(t, amount0, "49999999")
	shouldEQ(t, amount1, "0")

	ownerOfPosition = gnft.OwnerOf(tid(3))
	shouldEQ(t, ownerOfPosition, std.GetOrigCaller())
}

func TestApiGetPositions(t *testing.T) {
	gpss := ApiGetPositions()
	jsonStr := gjson.Parse(gpss)
	jsonArr := jsonStr.Get("response").Array()
	shouldEQ(t, len(jsonArr), 3)

	shouldEQ(t, jsonArr[0].Get("burned").Bool(), false)
	shouldEQ(t, jsonArr[2].Get("burned").Bool(), true)
}
