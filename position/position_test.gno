package position

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	p "gno.land/r/pool"

	nft "gno.land/r/gnft"
)

var (
	PoolAddr = p.GetOrigPkgAddr()

	own  = testutils.TestAddress("own")  // Owner
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	lp02 = testutils.TestAddress("lp02") // Liquidity Provider 02
	rv01 = testutils.TestAddress("rv01") // Receiver 01
	tr01 = testutils.TestAddress("tr01") // Trader 01
)

func init() {
	// debug - print addr
	println(lp01, "// lp01")
	println(lp02, "// lp02")
	println(rv01, "// rv01")
	println(tr01, "// tr01")
	println(PoolAddr, "// pool")
	println(GetOrigPkgAddr(), "// position")
}

var (
	// Common
	pToken0 = "foo"
	pToken1 = "bar"
	pFee    = uint16(500)

	test_tickLower       = int32(9000)
	test_tickUpper       = int32(11000)
	test_liquidityExpect = bigint(1000)
)

// 1. Init & Create Pool
func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(own)
	p.InitManual()
	p.CreatePool("foo", "bar", pFee, 130621891405341611593710811006)

	// fee
	// 500		= 0.05% // USv3 default
	// 3000		= 0.3% // USv3 default
	// 10000	= 1% // USv3 default

	// sqrtPrice
	// 130621891405341611593710811006 // tick = 10000
	shouldPanic(t, func() { p.CreatePool("foo", "bar", 500, 130621891405341611593710811006) })
}

// 2. Mint LP and Get GNFT
func TestMint(t *testing.T) {
	// lp01 mints
	// will get tid 1 nft
	{
		std.TestSetOrigCaller(lp01)

		poolOldToken0Bal := Token0Bal(PoolAddr)
		poolOldToken1Bal := Token1Bal(PoolAddr)

		tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
			pToken0,
			pToken1,
			pFee,
			test_tickLower,
			test_tickUpper,
			bigint(1000),
			bigint(1000),
			bigint(1),
			bigint(1),
			bigint(1234567890),
		)

		isOwner(t, tTokenId, lp01)
		shouldEQ(t, tTokenId, bigint(1))
		shouldEQ(t, getNextId(), bigint(2))
		shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal+tAmount1)
	}

	// lp02 mints
	// will get tid 2 nft
	{
		std.TestSetOrigCaller(lp02)

		poolOldToken0Bal := Token0Bal(PoolAddr)
		poolOldToken1Bal := Token1Bal(PoolAddr)

		tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
			pToken0,
			pToken1,
			pFee,
			test_tickLower,
			test_tickUpper,
			bigint(2000),
			bigint(2000),
			bigint(1),
			bigint(1),
			bigint(1234567890),
		)

		isOwner(t, tTokenId, lp02)
		shouldEQ(t, tTokenId, bigint(2))
		shouldEQ(t, getNextId(), bigint(3))
		shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal+tAmount1)

		// lp02 mints out of range => upper position (token1 will be 0)
		// will get tid 3 nft
		{
			std.TestSetOrigCaller(lp02)

			poolOldToken0Bal := Token0Bal(PoolAddr)
			poolOldToken1Bal := Token1Bal(PoolAddr)

			tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
				pToken0,
				pToken1,
				pFee,
				int32(14000),
				int32(18000),
				bigint(1000),
				bigint(1000),
				bigint(0),
				bigint(0),
				bigint(1234567890),
			)
			shouldEQ(t, tAmount1, bigint(0))

			isOwner(t, tTokenId, lp02)
			shouldEQ(t, tTokenId, bigint(3))
			shouldEQ(t, getNextId(), bigint(4))
			shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal+tAmount0)
			shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal+tAmount1)
		}

		// lp02 mints out of range => lower position (token0 will be 0)
		// will get tid 4 nft
		{
			std.TestSetOrigCaller(lp02)

			poolOldToken0Bal := Token0Bal(PoolAddr)
			poolOldToken1Bal := Token1Bal(PoolAddr)

			tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
				pToken0,
				pToken1,
				pFee,
				int32(7000),
				int32(9000),
				bigint(1000),
				bigint(1000),
				bigint(0),
				bigint(0),
				bigint(1234567890),
			)
			shouldEQ(t, tAmount0, bigint(0))

			isOwner(t, tTokenId, lp02)
			shouldEQ(t, tTokenId, bigint(4))
			shouldEQ(t, getNextId(), bigint(5))
			shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal+tAmount0)
			shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal+tAmount1)
		}
	}
}

func TestIncreaseLiquidity(t *testing.T) {
	// lp02 mints at lp01 position
	{
		std.TestSetOrigCaller(lp02)

		poolOldToken0Bal := Token0Bal(PoolAddr)
		poolOldToken1Bal := Token1Bal(PoolAddr)

		tLiquidity, tAmount0, tAmount1 := IncreaseLiquidity(
			bigint(1), // lp01 owns tid 1
			bigint(2000),
			bigint(2000),
			bigint(1),
			bigint(1),
			bigint(1234567890),
		)

		shouldEQ(t, getNextId(), bigint(5))
		shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal+tAmount1)
	}

	// lp02 mints at unknown position
	// should panic
	{
		std.TestSetOrigCaller(lp02)

		shouldPanic(t, func() {
			IncreaseLiquidity(
				bigint(123),
				bigint(2000),
				bigint(2000),
				bigint(1),
				bigint(1),
				bigint(1234567890),
			)
		})
	}
}

func TestDecreaseLiquidity(t *testing.T) {
	// lp01 decreases liquidity at tid 1 position ( in range )
	{
		std.TestSetOrigCaller(lp01)
		pool := p.GetPool(pToken0, pToken1, pFee)

		tTargetLiquidity := bigint(1234)

		poolOldLiquidity := pool.GetLiquidity()
		poolOldToken0Bal := Token0Bal(PoolAddr) // or PositionAddr
		poolOldToken1Bal := Token1Bal(PoolAddr)

		tAmount0, tAmount1 := DecreaseLiquidity(
			bigint(1),
			tTargetLiquidity,
			bigint(1),
			bigint(1),
			bigint(1234567890),
		)

		shouldNEQ(t, tAmount0, bigint(0))
		shouldNEQ(t, tAmount1, bigint(0))

		// decreasing liquidity doesn't decrease tid
		// Decreaseliquitiy() => Burn() doesn't decrease pool's balance
		// Collect() will decrease pool's balance
		shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal)
		shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal)
		shouldEQ(t, pool.GetLiquidity(), poolOldLiquidity-tTargetLiquidity)
	}

	// lp01 decreases liquidity too much => should panic
	{
		std.TestSetOrigCaller(lp01)

		shouldPanic(t, func() {
			DecreaseLiquidity(
				bigint(1),
				bigint(1234567890),
				bigint(1),
				bigint(1),
				bigint(1234567890),
			)
		})
	}

	// lp01 decreases liquidity at tid 2 position ( out-of range )
	// should panic, only lp02 minted at tid 2
	{
		std.TestSetOrigCaller(lp01)

		shouldPanic(t, func() {
			DecreaseLiquidity(
				bigint(2),
				bigint(1000),
				bigint(0),
				bigint(0),
				bigint(1234567890),
			)
		})
	}
}

func TestCollect(t *testing.T) {
	// lp01 did decrease some liquidity => there are some to collect
	{
		std.TestSetOrigCaller(lp01)
		pool := p.GetPool(pToken0, pToken1, pFee)

		poolOldLiquidity := pool.GetLiquidity()
		poolOldToken0Bal := Token0Bal(PoolAddr)
		poolOldToken1Bal := Token1Bal(PoolAddr)

		rvOldToken0Bal := Token0Bal(rv01)
		rvOldToken1Bal := Token1Bal(rv01)

		// Collect => pool.Burn()
		tAmount0, tAmount1 := Collect(
			bigint(1),
			rv01,
			bigint(10),
			bigint(10),
		)

		shouldNEQ(t, tAmount0, bigint(0))
		shouldNEQ(t, tAmount1, bigint(0))

		// After Collect
		// pool's liquidity stays same
		// pool's balance decreases
		shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal-tAmount0)
		shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal-tAmount1)
		shouldEQ(t, pool.GetLiquidity(), poolOldLiquidity)

		// Recipient balance increases
		shouldEQ(t, Token0Bal(rv01), rvOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(rv01), rvOldToken1Bal+tAmount1)
	}

	// lp01 collect all
	{
		std.TestSetOrigCaller(lp01)
		pool := p.GetPool(pToken0, pToken1, pFee)

		poolOldLiquidity := pool.GetLiquidity()
		poolOldToken0Bal := Token0Bal(PoolAddr)
		poolOldToken1Bal := Token1Bal(PoolAddr)

		rvOldToken0Bal := Token0Bal(rv01)
		rvOldToken1Bal := Token1Bal(rv01)

		tAmount0, tAmount1 := Collect(
			bigint(1),
			rv01,
			bigint(100000),
			bigint(100000),
		)

		shouldNEQ(t, tAmount0, bigint(0))
		shouldNEQ(t, tAmount1, bigint(0))

		// After Collect
		// pool's liquidity stays same
		// pool's balance decreases
		shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal-tAmount0)
		shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal-tAmount1)
		shouldEQ(t, pool.GetLiquidity(), poolOldLiquidity)

		// Recipient balance increases
		shouldEQ(t, Token0Bal(rv01), rvOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(rv01), rvOldToken1Bal+tAmount1)
	}

	// lp02 didn't decrease any liquidity => nothing to collect
	{
		std.TestSetOrigCaller(lp02)
		pool := p.GetPool(pToken0, pToken1, pFee)

		poolOldLiquidity := pool.GetLiquidity()
		poolOldToken0Bal := Token0Bal(PoolAddr)
		poolOldToken1Bal := Token1Bal(PoolAddr)

		rvOldToken0Bal := Token0Bal(rv01)
		rvOldToken1Bal := Token1Bal(rv01)

		tAmount0, tAmount1 := Collect(
			bigint(2),
			rv01,
			bigint(10),
			bigint(10),
		)

		shouldEQ(t, tAmount0, bigint(0))
		shouldEQ(t, tAmount1, bigint(0))

		// After Collect
		// pool's liquidity stays same
		// pool's balance decreases
		shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal-tAmount0)
		shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal-tAmount1)
		shouldEQ(t, pool.GetLiquidity(), poolOldLiquidity)

		// Recipient balance increases
		shouldEQ(t, Token0Bal(rv01), rvOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(rv01), rvOldToken1Bal+tAmount1)
	}

	// lp02 collect lp01's position => panic
	{
		std.TestSetOrigCaller(lp02)

		shouldPanic(t, func() {
			Collect(
				bigint(1),
				rv01,
				bigint(10),
				bigint(10),
			)
		})
	}
}

func TestNFTBurn(t *testing.T) {
	// burn tid 1 (lp01's position) will panic => there are some liquidity left
	std.TestSetOrigCaller(lp01)
	shouldPanic(t, func() { burn("1") })

	// remove all liquditiy & collect all then burn tid 1
	{
		std.TestSetOrigCaller(lp01)

		tTokenId := uint64(1)
		tPosition := positions[tTokenId]

		tPositionLiquidity := tPosition.liquidity

		// remove all liquidity
		DecreaseLiquidity(
			tTokenId,
			tPositionLiquidity, // remove all liquidity
			bigint(1),
			bigint(1),
			bigint(1234567890),
		)
		// didn't collect yet => burn will panic
		shouldPanic(t, func() { burn("1") })

		// collect all => nft is burnable and burned
		tBefore := nftBalanceOf(lp01)
		Collect( // burn happens here as last step
			tTokenId,
			rv01,
			bigint(100000), // collect all
			bigint(100000), // collect all
		)
		shouldEQ(t, nftBalanceOf(lp01), tBefore-bigint(1))
	}

	// burn non exists nft
	shouldPanic(t, func() { burn("5") })
}

/* GETTER_API TEST */
func TestApiGetPositions(t *testing.T) {
	gpss := ApiGetPositions()
	println(gpss)
}

func TestApiGetPosition(t *testing.T) {
	gps := ApiGetPosition(uint64(2))
	println(gps)
}

func TestApiGetPositionByUser(t *testing.T) {
	gpu := ApiGetPositionByUser("g1d3crqvjlta047h6lta047h6lta047h6ljnm9km") // lp02
	println(gpu)
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, didn't expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}

func isOwner(t *testing.T, tokenId uint64, addr std.Address) bool {
	owner := nft.OwnerOf(tid(tokenId))

	if owner == addr {
		return true
	}

	t.Errorf("expected owner %v, got %v", addr, owner)
	return false
}
