package position

import (
	"encoding/json"
	"std"
	"testing"
	"time"

	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/demo/users"
	"gno.land/r/gnoswap/v1/consts"
)

func setupPositions(t *testing.T) {
	t.Helper()

	CreatePoolWithoutFee(t)
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	position := Position{
		nonce:                    u256.Zero(),
		operator:                 consts.POSITION_ADDR,
		poolKey:                  "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
		tickLower:                -10000,
		tickUpper:                10000,
		liquidity:                u256.NewUint(1000000),
		feeGrowthInside0LastX128: u256.Zero(),
		feeGrowthInside1LastX128: u256.Zero(),
		tokensOwed0:              u256.Zero(),
		tokensOwed1:              u256.Zero(),
		burned:                   false,
	}
	tokenId := getNextId()
	setPosition(tokenId, position)
	DecreaseLiquidity(
		tokenId,
		"1000000",
		"0",
		"0",
		time.Now().Add(time.Hour).Unix(),
		false,
	)
	TokenApprove(t, barPath, admin, pool, consts.UINT64_MAX)
	TokenApprove(t, fooPath, admin, pool, consts.UINT64_MAX)
	Mint(
		barPath,
		fooPath,
		fee500,
		int32(-10000),
		int32(10000),
		"1000000",
		"1000000",
		u256.Zero().ToString(),
		u256.Zero().ToString(),
		time.Now().Add(time.Hour).Unix(),
		users.Resolve(admin),
		users.Resolve(admin),
	)
}

func TestApiGetPositions(t *testing.T) {
	setupPositions(t)
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))

	result := ApiGetPositions()

	var response ResponseApiGetPositions
	err := json.Unmarshal([]byte(result), &response)
	uassert.NoError(t, err)
	uassert.Equal(t, 1, len(response.Response))

	position := response.Response[0]
	uassert.Equal(t, uint64(1), position.LpTokenId)
	uassert.Equal(t, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", position.PoolKey)
	uassert.Equal(t, "1000000", position.Liquidity)
}

func TestApiGetPosition(t *testing.T) {
	setupPositions(t)

	result := ApiGetPosition(1)

	var response ResponseApiGetPositions
	err := json.Unmarshal([]byte(result), &response)
	uassert.NoError(t, err)
	uassert.Equal(t, 1, len(response.Response))

	position := response.Response[0]
	uassert.Equal(t, uint64(1), position.LpTokenId)
	uassert.Equal(t, "pool-1", position.PoolKey)
	uassert.Equal(t, "1000", position.Liquidity)
}

func TestApiGetPositionsByPoolPath(t *testing.T) {
	setupPositions(t)

	result := ApiGetPositionsByPoolPath("pool-1")

	var response ResponseApiGetPositions
	err := json.Unmarshal([]byte(result), &response)
	uassert.NoError(t, err)
	uassert.Equal(t, 1, len(response.Response))

	position := response.Response[0]
	uassert.Equal(t, "pool-1", position.PoolKey)
}

func TestApiGetPositionsByAddress(t *testing.T) {
	setupPositions(t)

	address := users.Resolve(admin)
	result := ApiGetPositionsByAddress(address)

	var response ResponseApiGetPositions
	err := json.Unmarshal([]byte(result), &response)
	uassert.NoError(t, err)
	uassert.Equal(t, 1, len(response.Response))

	position := response.Response[0]
	uassert.Equal(t, uint64(1), position.LpTokenId)
	uassert.Equal(t, address.String(), position.Operator)
}

func TestApiGetPositionsUnclaimedFee(t *testing.T) {
	setupPositions(t)

	result := ApiGetPositionsUnclaimedFee()

	var response map[string]interface{}
	err := json.Unmarshal([]byte(result), &response)
	uassert.NoError(t, err)
	//uassert.NotNil(t, response["response"])

	responses := response["response"].([]interface{})
	uassert.Equal(t, 1, len(responses))
	unclaimedFee := responses[0].(map[string]interface{})

	uassert.Equal(t, float64(1), unclaimedFee["lpTokenId"])
	uassert.Equal(t, "0", unclaimedFee["fee0"])
	uassert.Equal(t, "0", unclaimedFee["fee1"])
}

func TestApiGetPositionUnclaimedFeeByLpTokenId(t *testing.T) {
	setupPositions(t)

	result := ApiGetPositionUnclaimedFeeByLpTokenId(1)

	var response map[string]interface{}
	err := json.Unmarshal([]byte(result), &response)
	uassert.NoError(t, err)
	//uassert.NotNil(t, response["response"])

	responses := response["response"].([]interface{})
	uassert.Equal(t, 1, len(responses))
	unclaimedFee := responses[0].(map[string]interface{})

	uassert.Equal(t, float64(1), unclaimedFee["lpTokenId"])
	uassert.Equal(t, "0", unclaimedFee["fee0"])
	uassert.Equal(t, "0", unclaimedFee["fee1"])
}

func TestDryMint(t *testing.T) {
	tickCurrent := int32(0)
	tickLower := int32(-100)
	tickUpper := int32(100)

	amount0Desired := "500"
	amount1Desired := "300"

	amount0, amount1 := DryMint(tickCurrent, tickLower, tickUpper, amount0Desired, amount1Desired)

	uassert.NotEqual(t, "0", amount0)
	uassert.NotEqual(t, "0", amount1)
	uassert.Equal(t, "500", amount0)
	uassert.Equal(t, "300", amount1)
}
