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
	shouldPanic(t, func() { p.CreatePool(fooPath, barPath, fee500, 130621891405341611593710811006) })
}

// 2. Mint LP and Get GNFT
func TestMint(t *testing.T) {
	// test1 mints
	// will get tid 1 nft
	{
		std.TestSetOrigCaller(test1)

		tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
			fooPath,
			barPath,
			fee500,
			test_tickLower,
			test_tickUpper,
			bigint(50000000),
			bigint(50000000),
			bigint(1),
			bigint(1),
			bigint(1234567890),
		)

		isOwner(t, tTokenId, test1)
		shouldEQ(t, tTokenId, 1)
		shouldEQ(t, getNextId(), 2)
	}

	// test1 mints
	// will get tid 2 nft
	{
		std.TestSetOrigCaller(test1)

		tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
			fooPath,
			barPath,
			fee500,
			test_tickLower,
			test_tickUpper,
			bigint(2000),
			bigint(2000),
			bigint(1),
			bigint(1),
			bigint(1234567890),
		)

		isOwner(t, tTokenId, test1)
		shouldEQ(t, tTokenId, 2)
		shouldEQ(t, getNextId(), 3)
	}

	// test1 mints out of range => token1 will be 0
	// will get tid 3 nft
	{
		std.TestSetOrigCaller(test1)

		tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
			fooPath,
			barPath,
			fee500,
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

		isOwner(t, tTokenId, test1)
		shouldEQ(t, tTokenId, 3)
		shouldEQ(t, getNextId(), 4)
	}

	// test1 mints out of range => token0 will be 0
	// will get tid 4 nft
	{
		std.TestSetOrigCaller(test1)

		tTokenId, tLiquidity, tAmount0, tAmount1 := Mint(
			fooPath,
			barPath,
			fee500,
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

		isOwner(t, tTokenId, test1)
		shouldEQ(t, tTokenId, 4)
		shouldEQ(t, getNextId(), 5)
	}
}

func TestIncreaseLiquidity(t *testing.T) {
	// test1 mints at test1 position
	{
		std.TestSetOrigCaller(test1)

		tLiquidity, tAmount0, tAmount1 := IncreaseLiquidity(
			bigint(1), // test1 test1s tid 1
			bigint(2000),
			bigint(2000),
			bigint(1),
			bigint(1),
			bigint(1234567890),
		)

		shouldEQ(t, getNextId(), 5)
	}

	// test1 mints at unkntest1 position
	// should panic
	{
		std.TestSetOrigCaller(test1)

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
	// test1 decreases liquidity at tid 1 position ( in range )
	std.TestSetOrigCaller(test1)
	pool := p.GetPool(fooPath, barPath, fee500)

	tTargetLiquidity := bigint(1234)

	poolOldLiquidity := pool.PoolGetLiquidity()

	tAmount0, tAmount1 := DecreaseLiquidity(
		bigint(1),
		tTargetLiquidity,
		bigint(1234567890),
	)

	shouldNEQ(t, tAmount0, bigint(0))
	shouldNEQ(t, tAmount1, bigint(0))

	// decreasing liquidity doesn't decrease tid
	// Decreaseliquitiy() => Burn() doesn't decrease pool's balance
	// Collect() will decrease pool's balance
	shouldEQ(t, pool.PoolGetLiquidity(), poolOldLiquidity-tTargetLiquidity)
}

func TestCollect(t *testing.T) {
	// test1 did decrease some liquidity => there are some to collect
	{
		std.TestSetOrigCaller(test1)
		pool := p.GetPool(fooPath, barPath, fee500)

		poolOldLiquidity := pool.PoolGetLiquidity()

		// Collect => pool.Burn()
		tAmount0, tAmount1 := Collect(
			bigint(1),
			test1,
			bigint(10),
			bigint(10),
		)

		shouldNEQ(t, tAmount0, bigint(0))
		shouldNEQ(t, tAmount1, bigint(0))

		// After Collect
		// pool's liquidity stays same
		// pool's balance decreases
		shouldEQ(t, pool.PoolGetLiquidity(), poolOldLiquidity)

		// Recipient balance increases
	}

	// test1 collect all
	{
		std.TestSetOrigCaller(test1)
		pool := p.GetPool(fooPath, barPath, fee500)

		poolOldLiquidity := pool.PoolGetLiquidity()

		tAmount0, tAmount1 := Collect(
			bigint(1),
			test1,
			bigint(100000),
			bigint(100000),
		)

		shouldNEQ(t, tAmount0, bigint(0))
		shouldNEQ(t, tAmount1, bigint(0))

		// After Collect
		// pool's liquidity stays same
		// pool's balance decreases
		shouldEQ(t, pool.PoolGetLiquidity(), poolOldLiquidity)

		// Recipient balance increases
	}

	// test1 didn't decrease any liquidity => nothing to collect
	{
		std.TestSetOrigCaller(test1)
		pool := p.GetPool(fooPath, barPath, fee500)

		poolOldLiquidity := pool.PoolGetLiquidity()

		tAmount0, tAmount1 := Collect(
			bigint(2),
			test1,
			bigint(10),
			bigint(10),
		)

		shouldEQ(t, tAmount0, bigint(0))
		shouldEQ(t, tAmount1, bigint(0))

		// After Collect
		// pool's liquidity stays same
		// pool's balance decreases
		shouldEQ(t, pool.PoolGetLiquidity(), poolOldLiquidity)

		// Recipient balance increases
	}
}

func TestNFTBurn(t *testing.T) {
	// burn tid 1 (test1's position) will panic => there are some liquidity left
	std.TestSetOrigCaller(test1)
	shouldPanic(t, func() { burn("1") })

	// remove all liquditiy & collect all then burn tid 1
	{
		std.TestSetOrigCaller(test1)

		tTokenId := uint64(1)
		tPosition := positions[tTokenId]

		tPositionLiquidity := tPosition.liquidity

		// remove all liquidity
		DecreaseLiquidity(
			tTokenId,
			tPositionLiquidity, // remove all liquidity
			bigint(1234567890),
		)
		// didn't collect yet => burn will panic
		shouldPanic(t, func() { burn("1") })

		// collect all => nft is burnable and burned
		tBefore := nftBalanceOf(test1)
		Collect( // burn happens here as last step
			tTokenId,
			test1,
			bigint(100000000), // collect all
			bigint(100000000), // collect all
		)
		shouldEQ(t, nftBalanceOf(test1), tBefore-bigint(1))
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
	gpu := ApiGetPositionByUser("g16kvq0mra3atvr07lkdwc2x6jqmna8a4kt0e85d") // test1
	jsonStr := gjson.Parse(gpu)
	shouldEQ(t, len(jsonStr.Get("response.data").Array()), 3)

	shouldEQ(t, jsonStr.Get("response.data.0.token_id").Int(), 2)
	shouldEQ(t, jsonStr.Get("response.data.0.pool_key").String(), "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
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
