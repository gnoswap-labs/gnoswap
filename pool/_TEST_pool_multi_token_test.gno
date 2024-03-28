package pool

import (
	"std"
	"strconv"
	"testing"

	"gno.land/r/gnoswap/consts"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"

	"gno.land/r/demo/gns"

	u256 "gno.land/p/demo/uint256"
)

var (
	test_tickLower          = int32(9000)
	test_tickUpper          = int32(11000)
	test_liquidityExpectStr = "100000000"
	test_liquidityExpect256 = u256.NewUint(100_000_000)
)

// Create Foo:Bar Pool
func TestCreateFooBarPool(t *testing.T) {
	// call gns faucet to get creation fee
	std.TestSetPrevAddr(test1)
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()

	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE)

	CreatePool(fooPath, barPath, fee500, "130621891405341611593710811006")
	shouldEQ(t, len(pools), 1)
}

// Create Bar:Baz Pool
func TestCreateBarBazPool(t *testing.T) {
	// call gns faucet to get creation fee
	std.TestSetPrevAddr(test1)
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()

	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE)

	CreatePool(barPath, bazPath, fee500, "130621891405341611593710811006")
	shouldEQ(t, len(pools), 2)
}

// Mint Foo:Bar Liquidity by test1
func TestMintFooBarLiquidity(t *testing.T) {
	std.TestSetPrevAddr(test1)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	std.TestSetPrevRealm(consts.POSITION_PATH)
	std.TestSetOrigCaller(test1)
	amount0, amount1 := Mint(
		fooPath,
		barPath,
		fee500,
		consts.POSITION_ADDR.String(),
		-test_tickUpper,
		-test_tickLower,
		test_liquidityExpectStr,
	)
	shouldEQ(t, amount0, "8040316")
	shouldEQ(t, amount1, "2958014")
}

// Mint Bar:Baz Liquidity by test1
func TestMintBarBazLiquidity(t *testing.T) {
	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	std.TestSetPrevRealm(consts.POSITION_PATH)
	std.TestSetOrigCaller(test1)
	amount0, amount1 := Mint(
		barPath,
		bazPath,
		fee500,
		consts.POSITION_ADDR.String(),
		test_tickLower,
		test_tickUpper,
		test_liquidityExpectStr,
	)
	shouldEQ(t, amount0, "2958015")
	shouldEQ(t, amount1, "8040315")
}

// Swap Foo:Bar Foo > Bar by test1
func TestSwapFooBarFooToBar(t *testing.T) {
	oldTest1Bar := balanceOfByRegisterCall(barPath, test1)
	oldTest1Foo := balanceOfByRegisterCall(fooPath, test1)

	oldPoolBar := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)
	oldPoolFoo := balanceOfByRegisterCall(fooPath, consts.POOL_ADDR)

	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.POOL_ADDR), 16000)

	std.TestSetPrevRealm(consts.ROUTER_PATH)
	std.TestSetOrigCaller(test1)
	poolIn, poolOut := Swap(
		barPath,
		fooPath,
		fee500,
		test1.String(),
		true,
		"16000",
		consts.MIN_PRICE,
		std.GetOrigCaller().String(),
	)
	shouldEQ(t, poolIn, "16000")
	shouldEQ(t, poolOut, "-5882")

	newTest1Bar := balanceOfByRegisterCall(barPath, test1)
	newTest1Foo := balanceOfByRegisterCall(fooPath, test1)

	newPoolBar := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)
	newPoolFoo := balanceOfByRegisterCall(fooPath, consts.POOL_ADDR)

	shouldEQ(t, oldTest1Bar-newTest1Bar, 16000)
	shouldEQ(t, newTest1Foo-oldTest1Foo, 5882)

	shouldEQ(t, newPoolBar-oldPoolBar, 16000)
	shouldEQ(t, oldPoolFoo-newPoolFoo, 5882)
}

// Swap Bar:Baz Bar > Baz by test1
func TestSwapBarBazBarToBaz(t *testing.T) {
	oldTest1Token0Balance := balanceOfByRegisterCall(barPath, test1)
	oldtest1BazBalance := balanceOfByRegisterCall(bazPath, test1)
	oldPoolToken0Balance := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)
	oldPoolBazBalance := balanceOfByRegisterCall(bazPath, consts.POOL_ADDR)

	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.POOL_ADDR), 16000)

	std.TestSetPrevRealm(consts.ROUTER_PATH)
	std.TestSetOrigCaller(test1)
	poolIn, poolOut := Swap(
		barPath,
		bazPath,
		fee500,
		test1.String(),
		true,
		"16000",
		consts.MIN_PRICE,
		std.GetOrigCaller().String(),
	)
	shouldEQ(t, poolIn, "16000")
	shouldEQ(t, poolOut, "-43457")

	newTest1Token0Balance := balanceOfByRegisterCall(barPath, test1)
	newtest1BazBalance := balanceOfByRegisterCall(bazPath, test1)
	newPoolToken0Balance := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)
	newPoolBazBalance := balanceOfByRegisterCall(bazPath, consts.POOL_ADDR)

	shouldEQ(t, oldTest1Token0Balance-newTest1Token0Balance, 16000)
	shouldEQ(t, newtest1BazBalance-oldtest1BazBalance, 43457)
	shouldEQ(t, newPoolToken0Balance-oldPoolToken0Balance, 16000)
	shouldEQ(t, oldPoolBazBalance-newPoolBazBalance, 43457)
}

// Collect Foo:Bar Fees by test1
func TestCollectFooBarFees(t *testing.T) {
	std.TestSetPrevRealm(consts.POSITION_PATH)
	std.TestSetOrigCaller(test1)

	oldTest1Token1Balance := balanceOfByRegisterCall(fooPath, test1)
	oldTest1Token0Balance := balanceOfByRegisterCall(barPath, test1)
	oldPoolToken1Balance := balanceOfByRegisterCall(fooPath, consts.POOL_ADDR)
	oldPoolToken0Balance := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)

	// burn 0 to collect swap fees
	Burn(fooPath, barPath, fee500, -test_tickUpper, -test_tickLower, "0")

	c0, c1 := Collect(
		fooPath,
		barPath,
		fee500,
		test1.String(),
		-test_tickUpper,
		-test_tickLower,
		"100000",
		"100000",
	)

	shouldNEQ(t, c0, "0") // swap was foo > bar, so only foo has fees
	shouldEQ(t, c1, "0")  // swap was foo > bar, so bar has no fees

	newTest1Token1Balance := balanceOfByRegisterCall(fooPath, test1)
	newTest1Token0Balance := balanceOfByRegisterCall(barPath, test1)
	newPoolToken1Balance := balanceOfByRegisterCall(fooPath, consts.POOL_ADDR)
	newPoolToken0Balance := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)

	shouldEQ(t, newTest1Token1Balance-oldTest1Token1Balance, c1)
	shouldEQ(t, newTest1Token0Balance-oldTest1Token0Balance, strToUint64(c0))
	shouldEQ(t, oldPoolToken1Balance-newPoolToken1Balance, c1)
	shouldEQ(t, oldPoolToken0Balance-newPoolToken0Balance, strToUint64(c0))
}

// Collect Bar:Baz Fees by test1
func TestCollectBarBazFees(t *testing.T) {
	std.TestSetPrevRealm(consts.POSITION_PATH)
	std.TestSetOrigCaller(test1)

	oldTest1Token0Balance := balanceOfByRegisterCall(barPath, test1)
	oldtest1BazBalance := balanceOfByRegisterCall(bazPath, test1)
	oldPoolToken0Balance := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)
	oldPoolBazBalance := balanceOfByRegisterCall(bazPath, consts.POOL_ADDR)

	// burn 0 to collect swap fees
	Burn(barPath, bazPath, fee500, test_tickLower, test_tickUpper, "0")

	c0, c1 := Collect(
		barPath,
		bazPath,
		fee500,
		test1.String(),
		test_tickLower,
		test_tickUpper,
		"100000",
		"100000",
	)

	shouldNEQ(t, c0, "0") // swap was foo > bar, so only foo has fees
	shouldEQ(t, c1, "0")  // swap was foo > bar, so bar has no fees

	newTest1Token0Balance := balanceOfByRegisterCall(barPath, test1)
	newtest1BazBalance := balanceOfByRegisterCall(bazPath, test1)
	newPoolToken0Balance := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)
	newPoolBazBalance := balanceOfByRegisterCall(bazPath, consts.POOL_ADDR)

	shouldEQ(t, newTest1Token0Balance-oldTest1Token0Balance, strToUint64(c0))
	shouldEQ(t, newtest1BazBalance-oldtest1BazBalance, c1)
	shouldEQ(t, oldPoolToken0Balance-newPoolToken0Balance, strToUint64(c0))
	shouldEQ(t, oldPoolBazBalance-newPoolBazBalance, c1)
}

// Burn Foo:Bar Liquidity by test1
func TestBurnFooBarLiquidity(t *testing.T) {
	std.TestSetOrigCaller(test1)
	std.TestSetPrevRealm(consts.POSITION_PATH)

	pool := GetPool(fooPath, barPath, fee500)
	poolOldLiquidity := pool.PoolGetLiquidity()

	b0, b1 := Burn(
		fooPath,
		barPath,
		fee500,
		-test_tickUpper,
		-test_tickLower,
		test_liquidityExpectStr,
	)

	shouldNEQ(t, b0, "0")
	shouldNEQ(t, b1, "0")

	poolNewLiquidity := pool.PoolGetLiquidity()

	shouldEQ(t, true, new(u256.Uint).Sub(poolOldLiquidity, poolNewLiquidity).Eq(test_liquidityExpect256))
}

// Burn Bar:Baz Liquidity by test1
func TestBurnBarBazLiquidity(t *testing.T) {
	std.TestSetOrigCaller(test1)
	std.TestSetPrevRealm(consts.POSITION_PATH)

	pool := GetPool(barPath, bazPath, fee500)
	poolOldLiquidity := pool.PoolGetLiquidity()

	b0, b1 := Burn(
		barPath,
		bazPath,
		fee500,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpectStr,
	)

	shouldNEQ(t, b0, "0")
	shouldNEQ(t, b1, "0")

	poolNewLiquidity := pool.PoolGetLiquidity()

	// shouldEQ(t, poolOldLiquidity-poolNewLiquidity, test_liquidityExpect256)
}

// Collect Foo:Bar burned Liquidity by test1
func TestCollectFooBarLiquidity(t *testing.T) {
	std.TestSetOrigCaller(test1)
	std.TestSetPrevRealm(consts.POSITION_PATH)

	oldTest1Token1Balance := balanceOfByRegisterCall(fooPath, test1)
	oldTest1Token0Balance := balanceOfByRegisterCall(barPath, test1)
	oldPoolToken1Balance := balanceOfByRegisterCall(fooPath, consts.POOL_ADDR)
	oldPoolToken0Balance := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)

	c0, c1 := Collect(
		fooPath,
		barPath,
		fee500,
		test1.String(),
		-test_tickUpper,
		-test_tickLower,
		"100000",
		"100000",
	)

	shouldNEQ(t, c0, "0")
	shouldNEQ(t, c1, "0")

	newTest1Token1Balance := balanceOfByRegisterCall(fooPath, test1)
	newTest1Token0Balance := balanceOfByRegisterCall(barPath, test1)
	newPoolToken1Balance := balanceOfByRegisterCall(fooPath, consts.POOL_ADDR)
	newPoolToken0Balance := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)

	shouldEQ(t, newTest1Token1Balance-oldTest1Token1Balance, strToUint64(c0))
	shouldEQ(t, newTest1Token0Balance-oldTest1Token0Balance, strToUint64(c1))
	shouldEQ(t, oldPoolToken1Balance-newPoolToken1Balance, strToUint64(c0))
	shouldEQ(t, oldPoolToken0Balance-newPoolToken0Balance, strToUint64(c1))
}

// Collect Bar:Baz burned Liquidity by test1
func TestCollectBarBazLiquidity(t *testing.T) {
	std.TestSetOrigCaller(test1)
	std.TestSetPrevRealm(consts.POSITION_PATH)

	oldTest1Token0Balance := balanceOfByRegisterCall(barPath, test1)
	oldtest1BazBalance := balanceOfByRegisterCall(bazPath, test1)
	oldPoolToken0Balance := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)
	oldPoolBazBalance := balanceOfByRegisterCall(bazPath, consts.POOL_ADDR)

	c0, c1 := Collect(
		barPath,
		bazPath,
		fee500,
		test1.String(),
		test_tickLower,
		test_tickUpper,
		"100000",
		"100000",
	)

	shouldNEQ(t, c0, "0")
	shouldNEQ(t, c1, "0")

	newTest1Token0Balance := balanceOfByRegisterCall(barPath, test1)
	newtest1BazBalance := balanceOfByRegisterCall(bazPath, test1)
	newPoolToken0Balance := balanceOfByRegisterCall(barPath, consts.POOL_ADDR)
	newPoolBazBalance := balanceOfByRegisterCall(bazPath, consts.POOL_ADDR)

	shouldEQ(t, newTest1Token0Balance-oldTest1Token0Balance, strToUint64(c0))
	shouldEQ(t, newtest1BazBalance-oldtest1BazBalance, strToUint64(c1))
	shouldEQ(t, oldPoolToken0Balance-newPoolToken0Balance, strToUint64(c0))
	shouldEQ(t, oldPoolBazBalance-newPoolBazBalance, strToUint64(c1))
}

// UTILs //
func strToUint64(s string) uint64 {
	i, err := strconv.Atoi(s)
	if err != nil {
		panic("strToUint64")
	}
	return uint64(i)
}
