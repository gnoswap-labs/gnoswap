package position

import (
	"std"
	"testing"

	"encoding/gjson"

	"gno.land/p/demo/testutils"

	nft "gno.land/r/gnft"

	_ "gno.land/r/grc20_wrapper"
	p "gno.land/r/pool"

	"gno.land/r/bar"
	"gno.land/r/foo"
)

var (
	PoolAddr = p.GetOrigPkgAddr()

	own  = testutils.TestAddress("own")  // Owner
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	lp02 = testutils.TestAddress("lp02") // Liquidity Provider 02
	rv01 = testutils.TestAddress("rv01") // Receiver 01
	tr01 = testutils.TestAddress("tr01") // Trader 01
	pc01 = testutils.TestAddress("pc01") // Pool Creator 01
)

var (
	// Common
	fooPath = "gno.land/r/foo"
	barPath = "gno.land/r/bar"
	pFee    = uint16(500)

	test_tickLower       = int32(9000)
	test_tickUpper       = int32(11000)
	test_liquidityExpect = bigint(1000)
)

// 1. Init & Create Pool
func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(own)
	p.InitManual()

	std.TestSetOrigCaller(pc01)
	p.CreatePool(fooPath, barPath, pFee, 130621891405341611593710811006)

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
	// lp01 mints
	// will get tid 1 nft
	{
		std.TestSetOrigCaller(lp01)

		poolOldToken0Bal := Token0Bal(PoolAddr)
		poolOldToken1Bal := Token1Bal(PoolAddr)

		tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
			fooPath,
			barPath,
			pFee,
			test_tickLower,
			test_tickUpper,
			bigint(50000000),
			bigint(50000000),
			bigint(1),
			bigint(1),
			bigint(1234567890),
		)

		isOwner(t, tTokenId, lp01)
		shouldEQ(t, tTokenId, 1)
		shouldEQ(t, getNextId(), 2)

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
			fooPath,
			barPath,
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
		shouldEQ(t, tTokenId, 2)
		shouldEQ(t, getNextId(), 3)
		shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal+tAmount1)
	}

	// lp02 mints out of range => token1 will be 0
	// will get tid 3 nft
	{
		std.TestSetOrigCaller(lp02)

		poolOldToken0Bal := Token0Bal(PoolAddr)
		poolOldToken1Bal := Token1Bal(PoolAddr)

		tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
			fooPath,
			barPath,
			pFee,
			int32(1000),
			int32(2000),
			bigint(1000),
			bigint(1000),
			bigint(0),
			bigint(0),
			bigint(1234567890),
		)
		shouldEQ(t, tAmount0, bigint(999))
		shouldEQ(t, tAmount1, bigint(0))

		isOwner(t, tTokenId, lp02)
		shouldEQ(t, tTokenId, 3)
		shouldEQ(t, getNextId(), 4)
		shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal+tAmount1)
	}

	// lp02 mints out of range => token0 will be 0
	// will get tid 4 nft
	{
		std.TestSetOrigCaller(lp02)

		poolOldToken0Bal := Token0Bal(PoolAddr)
		poolOldToken1Bal := Token1Bal(PoolAddr)

		tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
			fooPath,
			barPath,
			pFee,
			int32(-34000),
			int32(-32000),
			bigint(1000),
			bigint(1000),
			bigint(0),
			bigint(0),
			bigint(1234567890),
		)
		shouldEQ(t, tAmount0, bigint(999))
		shouldEQ(t, tAmount1, bigint(0))

		isOwner(t, tTokenId, lp02)
		shouldEQ(t, tTokenId, 4)
		shouldEQ(t, getNextId(), 5)
		shouldEQ(t, Token0Bal(PoolAddr), poolOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(PoolAddr), poolOldToken1Bal+tAmount1)
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

		shouldEQ(t, getNextId(), 5)
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
		pool := p.GetPool(fooPath, barPath, pFee)

		tTargetLiquidity := bigint(1234)

		poolOldLiquidity := pool.PoolGetLiquidity()
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
		shouldEQ(t, pool.PoolGetLiquidity(), poolOldLiquidity-tTargetLiquidity)
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
		pool := p.GetPool(fooPath, barPath, pFee)

		poolOldLiquidity := pool.PoolGetLiquidity()
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
		shouldEQ(t, pool.PoolGetLiquidity(), poolOldLiquidity)

		// Recipient balance increases
		shouldEQ(t, Token0Bal(rv01), rvOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(rv01), rvOldToken1Bal+tAmount1)
	}

	// lp01 collect all
	{
		std.TestSetOrigCaller(lp01)
		pool := p.GetPool(fooPath, barPath, pFee)

		poolOldLiquidity := pool.PoolGetLiquidity()
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
		shouldEQ(t, pool.PoolGetLiquidity(), poolOldLiquidity)

		// Recipient balance increases
		shouldEQ(t, Token0Bal(rv01), rvOldToken0Bal+tAmount0)
		shouldEQ(t, Token1Bal(rv01), rvOldToken1Bal+tAmount1)
	}

	// lp02 didn't decrease any liquidity => nothing to collect
	{
		std.TestSetOrigCaller(lp02)
		pool := p.GetPool(fooPath, barPath, pFee)

		poolOldLiquidity := pool.PoolGetLiquidity()
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
		shouldEQ(t, pool.PoolGetLiquidity(), poolOldLiquidity)

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
			bigint(100000000), // collect all
			bigint(100000000), // collect all
		)
		shouldEQ(t, nftBalanceOf(lp01), tBefore-bigint(1))
	}

	// burn non exists nft
	shouldPanic(t, func() { burn("5") })
}

/* GETTER_API TEST */
func TestApiGetPositions(t *testing.T) {
	gpss := ApiGetPositions()
	jsonStr := gjson.Parse(gpss)
	shouldEQ(t, len(jsonStr.Get("response.data").Array()), 3)
}

func TestApiGetPosition(t *testing.T) {
	{
		gps := ApiGetPosition(uint64(2))
		jsonStr := gjson.Parse(gps)
		shouldEQ(t, jsonStr.Get("response.data.token_id").Int(), 2)
		shouldEQ(t, jsonStr.Get("response.data.tick_lower").Int(), -11000)
		shouldEQ(t, jsonStr.Get("response.data.tick_upper").Int(), -9000)
	}

	{
		gps := ApiGetPosition(uint64(3))
		jsonStr := gjson.Parse(gps)
		shouldEQ(t, jsonStr.Get("response.data.token_id").Int(), 3)
		shouldEQ(t, jsonStr.Get("response.data.tick_lower").Int(), -2000)
		shouldEQ(t, jsonStr.Get("response.data.tick_upper").Int(), -1000)
	}

	{
		gps := ApiGetPosition(uint64(4))
		jsonStr := gjson.Parse(gps)
		shouldEQ(t, jsonStr.Get("response.data.token_id").Int(), 4)
		shouldEQ(t, jsonStr.Get("response.data.tick_lower").Int(), 32000)
		shouldEQ(t, jsonStr.Get("response.data.tick_upper").Int(), 34000)
	}

}

func TestApiGetPositionByUser(t *testing.T) {
	gpu := ApiGetPositionByUser("g1d3crqvjlta047h6lta047h6lta047h6ljnm9km") // lp02
	jsonStr := gjson.Parse(gpu)
	shouldEQ(t, len(jsonStr.Get("response.data").Array()), 3)

	shouldEQ(t, jsonStr.Get("response.data.0.token_id").Int(), 2)
	shouldEQ(t, jsonStr.Get("response.data.0.pool_key").String(), "gno.land/r/bar:gno.land/r/foo:500")
	shouldEQ(t, jsonStr.Get("response.data.0.tick_lower").Int(), -11000)
	shouldEQ(t, jsonStr.Get("response.data.0.tick_upper").Int(), -9000)
	shouldEQ(t, jsonStr.Get("response.data.0.liquidity").Int(), 24900)

	shouldEQ(t, jsonStr.Get("response.data.1.token_id").Int(), 3)
	shouldEQ(t, jsonStr.Get("response.data.1.tick_lower").Int(), -2000)
	shouldEQ(t, jsonStr.Get("response.data.1.tick_upper").Int(), -1000)
	shouldEQ(t, jsonStr.Get("response.data.1.liquidity").Int(), 18553)

	shouldEQ(t, jsonStr.Get("response.data.2.token_id").Int(), 4)
	shouldEQ(t, jsonStr.Get("response.data.2.tick_lower").Int(), 32000)
	shouldEQ(t, jsonStr.Get("response.data.2.tick_upper").Int(), 34000)
	shouldEQ(t, jsonStr.Get("response.data.2.liquidity").Int(), 52046)
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

func Token0Bal(addr std.Address) bigint {
	return bigint(bar.BalanceOf(a2u(addr)))
}

func Token1Bal(addr std.Address) bigint {
	return bigint(foo.BalanceOf(a2u(addr)))
}
