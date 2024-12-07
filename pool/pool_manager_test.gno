package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/json"
	"gno.land/p/demo/uassert"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"
)

var (
	test_tickLower          = int32(9000)
	test_tickUpper          = int32(11000)
	test_liquidityExpectStr = "100000000"
)

// 1. Create Foo:Bar Pool
func TestCreateFooBarPool(t *testing.T) {
	std.TestSkipHeights(100)

	uassert.Equal(t, gns.TotalSupply(), uint64(100000000000000))
	uassert.Equal(t, gnsBalance(t, consts.EMISSION_ADDR), uint64(0))
	uassert.Equal(t, gnsBalance(t, consts.STAKER_ADDR), uint64(0))
	uassert.Equal(t, gnsBalance(t, consts.DEV_OPS), uint64(0))

	std.TestSetRealm(adminRealm)
	gns.Approve(a2u(consts.POOL_ADDR), poolCreationFee)

	t.Run("wrong pool path", func(t *testing.T) {
		uassert.PanicsWithMessage(
			t,
			`[GNOSWAP-POOL-012] tokens must be in lexicographical order || pool_manager.gno__CreatePool() || expected token0Path(gno.land/r/onbloc/foo) < token1Path(gno.land/r/onbloc/bar)`,
			func() {
				CreatePool(fooPath, barPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000
			},
		)
	})

	t.Run("create pool", func(t *testing.T) {
		CreatePool(barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000
		std.TestSkipHeights(1)
	})

	uassert.Equal(t, gns.TotalSupply(), uint64(100001426940600))
	uassert.Equal(t, gnsBalance(t, consts.EMISSION_ADDR), uint64(0))
	uassert.Equal(t, gnsBalance(t, consts.STAKER_ADDR), uint64(1070205450))
	uassert.Equal(t, gnsBalance(t, consts.DEV_OPS), uint64(285388120))
}

// 2. Create Bar:Baz Pool
func TestCreateBarBazPool(t *testing.T) {
	std.TestSetRealm(adminRealm)

	gns.Approve(a2u(consts.POOL_ADDR), poolCreationFee)
	std.TestSkipHeights(1)

	CreatePool(barPath, bazPath, fee500, "130621891405341611593710811006") // tick 10000
	std.TestSkipHeights(1)
}

// 3. Mint Foo:Bar Liquidity by admin
func TestMintFooBarLiquidity(t *testing.T) {
	std.TestSetRealm(adminRealm)

	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(4)

	std.TestSetRealm(posRealm)
	amount0, amount1 := Mint(
		barPath,
		fooPath,
		fee500,
		consts.POSITION_ADDR,
		-11000, // -11000
		-9000,  // -9000
		test_liquidityExpectStr,
		admin,
	)
	uassert.Equal(t, amount0, "8040316")
	uassert.Equal(t, amount1, "2958015")
	std.TestSkipHeights(1)
}

// 4. Mint Bar:Baz Liquidity by admin
func TestMintBarBazLiquidity(t *testing.T) {
	std.TestSetRealm(adminRealm)

	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(2)

	std.TestSetRealm(posRealm)
	amount0, amount1 := Mint(
		barPath,
		bazPath,
		fee500,
		consts.POSITION_ADDR,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpectStr,
		admin,
	)
	uassert.Equal(t, amount0, "2958015")
	uassert.Equal(t, amount1, "8040316")
	std.TestSkipHeights(1)
}

// GETTER_API TEST
func TestApiGetPools(t *testing.T) {
	gpls := ApiGetPools()

	root, err := json.Unmarshal([]byte(gpls))
	if err != nil {
		panic(err.Error())
	}

	response, err := root.GetKey("response")
	if err != nil {
		panic(err.Error())
	}

	uassert.Equal(t, response.Size(), 2)
}

func gnsBalance(t *testing.T, addr std.Address) uint64 {
	t.Helper()
	return gns.BalanceOf(a2u(addr))
}
