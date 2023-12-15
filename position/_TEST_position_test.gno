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

func TestCollectFee(t *testing.T) {
	// collect fee from tid 1 ( no swap, no fee)
	tokenId, fee0, fee1, poolPath := CollectFee(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, fee0, bigint(0))
	shouldEQ(t, fee1, bigint(0))
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
}

func TestApiGetPositions(t *testing.T) {
	gpss := ApiGetPositions()
	jsonStr := gjson.Parse(gpss)
	shouldEQ(t, len(jsonStr.Get("response.data").Array()), 4)
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
	shouldEQ(t, len(jsonStr.Get("response.data").Array()), 4)

	shouldEQ(t, jsonStr.Get("response.data.0.token_id").Int(), 1)
	shouldEQ(t, jsonStr.Get("response.data.0.pool_key").String(), "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
	shouldEQ(t, jsonStr.Get("response.data.0.tick_lower").Int(), -11000)
	shouldEQ(t, jsonStr.Get("response.data.0.tick_upper").Int(), -9000)
	shouldEQ(t, jsonStr.Get("response.data.0.liquidity").Int(), 622504326)

	shouldEQ(t, jsonStr.Get("response.data.1.token_id").Int(), 2)
	shouldEQ(t, jsonStr.Get("response.data.1.pool_key").String(), "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
	shouldEQ(t, jsonStr.Get("response.data.1.tick_lower").Int(), -11000)
	shouldEQ(t, jsonStr.Get("response.data.1.tick_upper").Int(), -9000)
	shouldEQ(t, jsonStr.Get("response.data.1.liquidity").Int(), 24900)

	shouldEQ(t, jsonStr.Get("response.data.2.token_id").Int(), 3)
	shouldEQ(t, jsonStr.Get("response.data.2.tick_lower").Int(), -2000)
	shouldEQ(t, jsonStr.Get("response.data.2.tick_upper").Int(), -1000)
	shouldEQ(t, jsonStr.Get("response.data.2.liquidity").Int(), 18553)

	shouldEQ(t, jsonStr.Get("response.data.3.token_id").Int(), 4)
	shouldEQ(t, jsonStr.Get("response.data.3.tick_lower").Int(), 32000)
	shouldEQ(t, jsonStr.Get("response.data.3.tick_upper").Int(), 34000)
	shouldEQ(t, jsonStr.Get("response.data.3.liquidity").Int(), 52046)
}

func TestBurn(t *testing.T) {
	tokenId, liquidity, amount0, amount1, poolPath := Burn(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, liquidity, bigint(622504326))
	shouldEQ(t, amount0, bigint(49999999))
	shouldEQ(t, amount1, bigint(18432647))
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
}

func TestApiGetPositionByUserAfterBurn(t *testing.T) {
	gpu := ApiGetPositionByUser("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5") // test1
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
