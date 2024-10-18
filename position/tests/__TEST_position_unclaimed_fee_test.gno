package position

import (
	"std"
	"testing"

	"gno.land/r/gnoswap/v2/consts"

	pl "gno.land/r/gnoswap/v2/pool"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/v2/gnft"
	"gno.land/r/gnoswap/v2/gns"

	i256 "gno.land/p/gnoswap/int256"
)

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetRealm(adminRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee())
	pl.CreatePool(barPath, fooPath, fee500, "130621891405341611593710811006") // tick = 10000
}

func TestMintPosition01InRange(t *testing.T) {
	std.TestSetRealm(adminRealm)
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
		admin,
		admin,
	)

	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, getNextId(), uint64(2))
	shouldEQ(t, amount0, "18394892")
	shouldEQ(t, amount1, "50000000")
}

func TestMintPosition02LowerRange(t *testing.T) {
	std.TestSetRealm(adminRealm)
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
		admin,
		admin,
	)

	shouldEQ(t, tokenId, uint64(2))
	shouldEQ(t, getNextId(), uint64(3))
	shouldEQ(t, amount0, "0")
	shouldEQ(t, amount1, "50000000")
}

func TestMintPosition03UpperRange(t *testing.T) {
	std.TestSetRealm(adminRealm)
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
		admin,
		admin,
	)

	shouldEQ(t, tokenId, uint64(3))
	shouldEQ(t, getNextId(), uint64(4))
	shouldEQ(t, amount0, "50000000")
	shouldEQ(t, amount1, "0")
}

func TestCollectFeeBeforeSwap(t *testing.T) {
	std.TestSetRealm(adminRealm)
	tokenId, fee0, fee1, poolPath, _, _ := CollectFee(1, false)

	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, fee0, "0")
	shouldEQ(t, fee1, "0")
	shouldEQ(t, poolPath, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500")
}

func TestUnclaimedFee0(t *testing.T) {
	amount0, amount1 := unclaimedFee(1)

	shouldEQ(t, amount0.ToString(), "0")
	shouldEQ(t, amount1.ToString(), "0")
}

func TestSwap1(t *testing.T) {
	std.TestSetRealm(adminRealm)
	bar.Approve(a2u(consts.POOL_ADDR), 1234567)

	std.TestSetRealm(rouRealm)
	amount0, amount1 := pl.Swap(
		barPath,
		fooPath,
		fee500,
		admin,
		true,
		"1234567",
		consts.MIN_PRICE,
		admin,
	)

	shouldEQ(t, amount0, "1234567")
	shouldEQ(t, amount1, "-3332779")
}

func TestUnclaimedFee1(t *testing.T) {
	amount0, amount1 := unclaimedFee(1)

	shouldEQ(t, amount0.ToString(), "617")
	shouldEQ(t, amount1.ToString(), "0")
}

func TestSwap2(t *testing.T) {
	std.TestSetRealm(adminRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	std.TestSetRealm(rouRealm)
	amount0, amount1 := pl.Swap(
		barPath,
		fooPath,
		fee500,
		admin,
		true,
		"20000000", //
		consts.MIN_PRICE,
		admin,
	)

	shouldEQ(t, amount0, "20000000")
	shouldEQ(t, amount1, "-48647018")
}

func TestUnclaimedFee2(t *testing.T) {
	amount0, amount1 := unclaimedFee(1)

	shouldEQ(t, amount0.ToString(), "10170")
	shouldEQ(t, amount1.ToString(), "0")
}

func TestSwap3(t *testing.T) {
	std.TestSetRealm(adminRealm)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	std.TestSetRealm(rouRealm)
	amount0, amount1 := pl.Swap(
		fooPath,
		barPath,
		fee500,
		admin,
		false,
		"20000000", //
		consts.MAX_PRICE,
		admin,
	)

	shouldEQ(t, amount0, "-8692001")
	shouldEQ(t, amount1, "20000000")
}

func TestUnclaimedFee3(t *testing.T) {
	amount0, amount1 := unclaimedFee(1)

	shouldEQ(t, amount0.ToString(), "10170")
	shouldEQ(t, amount1.ToString(), "9009")
}

func TestCollectFeeAfterSwap(t *testing.T) {
	std.TestSetRealm(adminRealm)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX) // COLLECT_FEE
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX) // COLLECT_FEE

	tokenId, fee0, fee1, poolPath, _, _ := CollectFee(1, false)

	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, fee0, "10069") // this is input token
	shouldEQ(t, fee1, "8919")  // this it output token
	shouldEQ(t, poolPath, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500")
}

func TestDecreaseLiquidityUpperPosition(t *testing.T) {
	std.TestSetRealm(adminRealm)

	ownerOfPosition := gnft.OwnerOf(tid(3))
	shouldEQ(t, ownerOfPosition, admin)

	tokenId, liquidity, fee0, fee1, amount0, amount1, poolPath := DecreaseLiquidity(uint64(3), 100, "0", "0", max_timeout, false)

	shouldEQ(t, tokenId, uint64(3))
	shouldEQ(t, amount0, "49999999")
	shouldEQ(t, amount1, "0")

	ownerOfPosition = gnft.OwnerOf(tid(3))
	shouldEQ(t, ownerOfPosition, admin)
}

func TestSubIn256(t *testing.T) {
	a := i256.Zero()
	b := i256.One()

	c := subIn256(a, b)
	if c.ToString() != "115792089237316195423570985008687907853269984665640564039457584007913129639934" {
		t.Errorf("subIn256 error")
	}
}
