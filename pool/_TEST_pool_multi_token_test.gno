package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"
)

var (
	gsa  = testutils.TestAddress("gsa")  // Gnoswap Admin
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	tr01 = testutils.TestAddress("tr01") // Trader 01

	poolAddr = std.DerivePkgAddr("gno.land/r/pool")
	posAddr  = std.DerivePkgAddr("gno.land/r/position")

	poolPath = "gno.land/r/pool"
)

var (
	// Common
	fooPath = "gno.land/r/foo"
	barPath = "gno.land/r/bar"
	bazPath = "gno.land/r/baz"

	pFee = uint16(500)

	test_tickLower       = int32(9000)
	test_tickUpper       = int32(11000)
	test_liquidityExpect = bigint(100000000)

	test_tickLower2 = int32(50000)
	test_tickUpper2 = int32(100000)
)

// 1. Init Pool
func TestInit(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	InitManual()
}

// 2. Create Foo:Bar Pool
func TestCreateFooBarPool(t *testing.T) {
	CreatePool(fooPath, barPath, pFee, 130621891405341611593710811006)
	shouldEQ(t, len(pools), 1)
}

// 3. Create Bar:Baz Pool
func TestCreateBarBazPool(t *testing.T) {
	CreatePool(barPath, bazPath, pFee, 130621891405341611593710811006)
	shouldEQ(t, len(pools), 2)
}

// 4. Mint Foo:Bar Liquidity by lp01
func TestMintFooBarLiquidity(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	std.TestSetPrevRealm("gno.land/r/position")

	Mint(
		fooPath,
		barPath,
		pFee,
		posAddr,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpect,
	)
}

// 5. Mint Bar:Baz Liquidity by lp01
func TestMintBarBazLiquidity(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	std.TestSetPrevRealm("gno.land/r/position")

	Mint(
		barPath,
		bazPath,
		pFee,
		posAddr,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpect,
	)
}

// 6. Swap Foo:Bar Foo > Bar by tr01
func TestSwapFooBarFooToBar(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	oldTr01FooBalance := balanceOfByRegisterCall(fooPath, tr01)
	oldTr01BarBalance := balanceOfByRegisterCall(barPath, tr01)
	oldPoolFooBalance := balanceOfByRegisterCall(fooPath, poolAddr)
	oldPoolBarBalance := balanceOfByRegisterCall(barPath, poolAddr)

	poolIn, poolOut := Swap(
		fooPath,
		barPath,
		pFee,
		tr01,
		true,
		bigint(16000),
		MIN_PRICE,
	)
	shouldEQ(t, poolIn, bigint(16000))
	shouldEQ(t, poolOut, bigint(-43457))

	newTr01FooBalance := balanceOfByRegisterCall(fooPath, tr01)
	newTr01BarBalance := balanceOfByRegisterCall(barPath, tr01)
	newPoolFooBalance := balanceOfByRegisterCall(fooPath, poolAddr)
	newPoolBarBalance := balanceOfByRegisterCall(barPath, poolAddr)

	shouldEQ(t, oldTr01FooBalance-newTr01FooBalance, bigint(16000))
	shouldEQ(t, newTr01BarBalance-oldTr01BarBalance, bigint(43457))
	shouldEQ(t, newPoolFooBalance-oldPoolFooBalance, bigint(16000))
	shouldEQ(t, oldPoolBarBalance-newPoolBarBalance, bigint(43457))
}

// 7. Swap Bar:Baz Bar > Baz by tr01
func TestSwapBarBazBarToBaz(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	oldTr01BarBalance := balanceOfByRegisterCall(barPath, tr01)
	oldTr01BazBalance := balanceOfByRegisterCall(bazPath, tr01)
	oldPoolBarBalance := balanceOfByRegisterCall(barPath, poolAddr)
	oldPoolBazBalance := balanceOfByRegisterCall(bazPath, poolAddr)

	poolIn, poolOut := Swap(
		barPath,
		bazPath,
		pFee,
		tr01,
		true,
		bigint(16000),
		MIN_PRICE,
	)
	shouldEQ(t, poolIn, bigint(16000))
	shouldEQ(t, poolOut, bigint(-43457))

	newTr01BarBalance := balanceOfByRegisterCall(barPath, tr01)
	newTr01BazBalance := balanceOfByRegisterCall(bazPath, tr01)
	newPoolBarBalance := balanceOfByRegisterCall(barPath, poolAddr)
	newPoolBazBalance := balanceOfByRegisterCall(bazPath, poolAddr)

	shouldEQ(t, oldTr01BarBalance-newTr01BarBalance, bigint(16000))
	shouldEQ(t, newTr01BazBalance-oldTr01BazBalance, bigint(43457))
	shouldEQ(t, newPoolBarBalance-oldPoolBarBalance, bigint(16000))
	shouldEQ(t, oldPoolBazBalance-newPoolBazBalance, bigint(43457))
}

// 8. Burn Foo:Bar Liquidity by lp01
func TestBurnFooBarLiquidity(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	
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

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}
