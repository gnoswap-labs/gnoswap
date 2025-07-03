package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"

	"gno.land/p/gnoswap/consts"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/v1/gns"
)

// Constants for fee tiers
const (
	fee500 uint32 = 500
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	posRealm     = std.NewCodeRealm(consts.POSITION_PATH)
	rouRealm     = std.NewCodeRealm(consts.ROUTER_PATH)
	positionAddr = consts.POSITION_ADDR
	poolAddr     = consts.POOL_ADDR
)

// Token paths
var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
)

var (
	test_tickLower          = int32(9000)
	test_tickUpper          = int32(11000)
	test_liquidityExpectStr = "100000000"
	test_liquidityExpect256 = u256.NewUint(100_000_000)

	poolCreationFee = int64(100_000_000)
)

func main() {
	println("[SCENARIO] Multi Token")
	testing.SetRealm(adminRealm)

	println("[INFO] Create foo <> bar pool")
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000

	println("[INFO] Create bar <> baz pool")
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, bazPath, barPath, fee500, "130621891405341611593710811006")

	println("[SCENARIO] 1. Mint Foo:Bar Liquidity")
	TestMintFooBarLiquidity()

	println("[SCENARIO] 2. Mint Bar:Baz Liquidity")
	TestMintBarBazLiquidity()

	println("[SCENARIO] 3. Swap Foo:Bar Foo > Bar")
	TestSwapFooBarFooToBar()

	println("[SCENARIO] 4. Swap Bar:Baz Bar > Baz by admin")
	TestSwapBarBazBarToBaz()

	println("[SCENARIO] 5. Collect Foo:Bar Fees")
	TestCollectFooBarFees()

	println("[SCENARIO] 6. Collect Bar:Baz Fees")
	TestCollectBarBazFees()

	println("[SCENARIO] 7. Burn Foo:Bar Liquidity")
	TestBurnFooBarLiquidity()

	println("[SCENARIO] 8. Burn Bar:Baz Liquidity")
	TestBurnBarBazLiquidity()

	println("[SCENARIO] 9. Collect Foo:Bar burned Liquidity")
	TestCollectFooBarLiquidity()

	println("[SCENARIO] 10. Collect Bar:Baz burned Liquidity")
	TestCollectBarBazLiquidity()
}

// Mint Foo:Bar Liquidity by admin
func TestMintFooBarLiquidity() {
	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		fooPath,
		barPath,
		fee500,
		positionAddr,
		-test_tickUpper,
		-test_tickLower,
		test_liquidityExpectStr,
		adminAddr,
	)

	println("[EXPECTED] amount0:", amount0, "expected: 8040316")
	println("[EXPECTED] amount1:", amount1, "expected: 2958015")
	println()
}

// Mint Bar:Baz Liquidity by admin
func TestMintBarBazLiquidity() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		barPath,
		bazPath,
		fee500,
		positionAddr,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpectStr,
		adminAddr,
	)

	println("[EXPECTED] amount0:", amount0, "expected: 2958015")
	println("[EXPECTED] amount1:", amount1, "expected: 8040316")
	println()
}

// Swap Foo:Bar Foo > Bar by admin
func TestSwapFooBarFooToBar() {
	oldTest1Bar := bar.BalanceOf(adminAddr)
	oldTest1Foo := foo.BalanceOf(adminAddr)

	oldPoolBar := bar.BalanceOf(poolAddr)
	oldPoolFoo := foo.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 16000)

	testing.SetRealm(rouRealm)
	poolIn, poolOut := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"16000",
		consts.MIN_PRICE,
		adminAddr,
	)
	println("[EXPECTED] poolIn:", poolIn, "expected: 16000")
	println("[EXPECTED] poolOut:", poolOut, "expected: -5882")
	println()

	newTest1Bar := bar.BalanceOf(adminAddr)
	newTest1Foo := foo.BalanceOf(adminAddr)

	newPoolBar := bar.BalanceOf(poolAddr)
	newPoolFoo := foo.BalanceOf(poolAddr)

	println("[EXPECTED] oldTest1Bar-newTest1Bar:", oldTest1Bar-newTest1Bar, "expected: 16000")
	println("[EXPECTED] newTest1Foo-oldTest1Foo:", newTest1Foo-oldTest1Foo, "expected: 5882")
	println("[EXPECTED] newPoolBar-oldPoolBar:", newPoolBar-oldPoolBar, "expected: 16000")
	println("[EXPECTED] oldPoolFoo-newPoolFoo:", oldPoolFoo-newPoolFoo, "expected: 5882")
	println()
}

func TestSwapBarBazBarToBaz() {
	oldTest1Token0Balance := bar.BalanceOf(adminAddr)
	oldadminBazBalance := baz.BalanceOf(adminAddr)
	oldPoolToken0Balance := bar.BalanceOf(poolAddr)
	oldPoolBazBalance := baz.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 16000)

	testing.SetRealm(rouRealm)
	poolIn, poolOut := pool.Swap(
		cross,
		barPath,
		bazPath,
		fee500,
		adminAddr,
		true,
		"16000",
		consts.MIN_PRICE,
		adminAddr,
	)

	println("[EXPECTED] poolIn:", poolIn, "expected: 16000")
	println("[EXPECTED] poolOut:", poolOut, "expected: -43457")
	println()

	newTest1Token0Balance := bar.BalanceOf(adminAddr)
	newadminBazBalance := baz.BalanceOf(adminAddr)
	newPoolToken0Balance := bar.BalanceOf(poolAddr)
	newPoolBazBalance := baz.BalanceOf(poolAddr)

	println("[EXPECTED] oldTest1Token0Balance-newTest1Token0Balance:", oldTest1Token0Balance-newTest1Token0Balance, "expected: 16000")
	println("[EXPECTED] newadminBazBalance-oldadminBazBalance:", newadminBazBalance-oldadminBazBalance, "expected: 43457")
	println("[EXPECTED] newPoolToken0Balance-oldPoolToken0Balance:", newPoolToken0Balance-oldPoolToken0Balance, "expected: 16000")
	println("[EXPECTED] oldPoolBazBalance-newPoolBazBalance:", oldPoolBazBalance-newPoolBazBalance, "expected: 43457")
	println()
}

func TestCollectFooBarFees() {
	testing.SetRealm(posRealm)

	oldTest1Token1Balance := foo.BalanceOf(adminAddr)
	oldTest1Token0Balance := bar.BalanceOf(adminAddr)
	oldPoolToken1Balance := foo.BalanceOf(poolAddr)
	oldPoolToken0Balance := bar.BalanceOf(poolAddr)

	// burn 0 to collect swap fees
	pool.Burn(cross, fooPath, barPath, fee500, -test_tickUpper, -test_tickLower, "0", adminAddr)

	c0, c1 := pool.Collect(
		cross,
		fooPath,
		barPath,
		fee500,
		adminAddr,
		-test_tickUpper,
		-test_tickLower,
		"100000",
		"100000",
	)

	println("[INFO] Swap: foo -> bar, thus only foo has fees")
	println("[EXPECTED] c0:", c0, "expected: should not be 0") // swap was foo > bar, so only foo has fees
	println("[EXPECTED] c1:", c1, "expected: should be 0")     // swap was foo > bar, so bar has no fees

	newTest1Token1Balance := foo.BalanceOf(adminAddr)
	newTest1Token0Balance := bar.BalanceOf(adminAddr)
	newPoolToken1Balance := foo.BalanceOf(poolAddr)
	newPoolToken0Balance := bar.BalanceOf(poolAddr)

	println("[EXPECTED] newTest1Token1Balance-oldTest1Token1Balance:", newTest1Token1Balance-oldTest1Token1Balance, "expected: should be", strToUint64(c1))
	println("[EXPECTED] newTest1Token0Balance-oldTest1Token0Balance:", newTest1Token0Balance-oldTest1Token0Balance, "expected: should be", strToUint64(c0))
	println("[EXPECTED] oldPoolToken1Balance-newPoolToken1Balance:", oldPoolToken1Balance-newPoolToken1Balance, "expected: should be", strToUint64(c1))
	println("[EXPECTED] oldPoolToken0Balance-newPoolToken0Balance:", oldPoolToken0Balance-newPoolToken0Balance, "expected: should be", strToUint64(c0))
	println()
}

func TestCollectBarBazFees() {
	testing.SetRealm(posRealm)

	oldTest1Token0Balance := bar.BalanceOf(adminAddr)
	oldadminBazBalance := baz.BalanceOf(adminAddr)
	oldPoolToken0Balance := bar.BalanceOf(poolAddr)
	oldPoolBazBalance := baz.BalanceOf(poolAddr)

	// burn 0 to collect swap fees
	pool.Burn(cross, barPath, bazPath, fee500, test_tickLower, test_tickUpper, "0", adminAddr)

	c0, c1 := pool.Collect(
		cross,
		barPath,
		bazPath,
		fee500,
		adminAddr,
		test_tickLower,
		test_tickUpper,
		"100000",
		"100000",
	)

	println("[INFO] Swap: bar -> baz, thus only bar has fees")
	println("[EXPECTED] c0:", c0, "expected: should not be 0") // swap was bar > baz, so only bar has fees
	println("[EXPECTED] c1:", c1, "expected: should be 0")     // swap was bar > baz, so baz has no fees

	newTest1Token0Balance := bar.BalanceOf(adminAddr)
	newadminBazBalance := baz.BalanceOf(adminAddr)
	newPoolToken0Balance := bar.BalanceOf(poolAddr)
	newPoolBazBalance := baz.BalanceOf(poolAddr)

	println("[EXPECTED] newTest1Token0Balance-oldTest1Token0Balance:", newTest1Token0Balance-oldTest1Token0Balance, "expected: should be", strToUint64(c0))
	println("[EXPECTED] newadminBazBalance-oldadminBazBalance:", newadminBazBalance-oldadminBazBalance, "expected: should be", strToUint64(c1))
	println("[EXPECTED] oldPoolToken0Balance-newPoolToken0Balance:", oldPoolToken0Balance-newPoolToken0Balance, "expected: should be", strToUint64(c0))
	println("[EXPECTED] oldPoolBazBalance-newPoolBazBalance:", oldPoolBazBalance-newPoolBazBalance, "expected: should be", strToUint64(c1))
	println()
}

// Burn Foo:Bar Liquidity by admin
func TestBurnFooBarLiquidity() {
	testing.SetRealm(posRealm)

	poolOldLiquidity := pool.GetPool(fooPath, barPath, fee500).
		Liquidity()

	b0, b1 := pool.Burn(
		cross,
		fooPath,
		barPath,
		fee500,
		-test_tickUpper,
		-test_tickLower,
		test_liquidityExpectStr,
		adminAddr,
	)

	println("[EXPECTED] b0:", b0, "expected: should not be 0")
	println("[EXPECTED] b1:", b1, "expected: should not be 0")

	poolNewLiquidity := pool.GetPool(fooPath, barPath, fee500).Liquidity()

	expected := u256.Zero().Sub(poolOldLiquidity, poolNewLiquidity).ToString()
	println("[EXPECTED] expected:", expected, "expected: should be", test_liquidityExpect256.ToString())
	println()
}

func TestBurnBarBazLiquidity() {
	testing.SetRealm(posRealm)

	poolOldLiquidity := pool.GetPool(barPath, bazPath, fee500).Liquidity()

	b0, b1 := pool.Burn(
		cross,
		barPath,
		bazPath,
		fee500,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpectStr,
		adminAddr,
	)

	println("[EXPECTED] b0:", b0, "expected: should not be 0")
	println("[EXPECTED] b1:", b1, "expected: should not be 0")

	poolNewLiquidity := pool.GetPool(barPath, bazPath, fee500).Liquidity()

	expected := u256.Zero().Sub(poolOldLiquidity, poolNewLiquidity).ToString()
	println("[EXPECTED] expected:", expected, "expected: should be 0")
	println()
}

// Collect Foo:Bar burned Liquidity by admin
func TestCollectFooBarLiquidity() {
	testing.SetRealm(posRealm)

	oldTest1Token1Balance := foo.BalanceOf(adminAddr)
	oldTest1Token0Balance := bar.BalanceOf(adminAddr)
	oldPoolToken1Balance := foo.BalanceOf(poolAddr)
	oldPoolToken0Balance := bar.BalanceOf(poolAddr)

	c0, c1 := pool.Collect(
		cross,
		fooPath,
		barPath,
		fee500,
		adminAddr,
		-test_tickUpper,
		-test_tickLower,
		"100000",
		"100000",
	)

	println("[EXPECTED] c0:", c0, "expected: should not be 0")
	println("[EXPECTED] c1:", c1, "expected: should not be 0")

	newTest1Token1Balance := foo.BalanceOf(adminAddr)
	newTest1Token0Balance := bar.BalanceOf(adminAddr)
	newPoolToken1Balance := foo.BalanceOf(poolAddr)
	newPoolToken0Balance := bar.BalanceOf(poolAddr)

	println("[EXPECTED] newTest1Token1Balance-oldTest1Token1Balance:", newTest1Token1Balance-oldTest1Token1Balance, "expected: should be", strToUint64(c0))
	println("[EXPECTED] newTest1Token0Balance-oldTest1Token0Balance:", newTest1Token0Balance-oldTest1Token0Balance, "expected: should be", strToUint64(c1))
	println("[EXPECTED] oldPoolToken1Balance-newPoolToken1Balance:", oldPoolToken1Balance-newPoolToken1Balance, "expected: should be", strToUint64(c0))
	println("[EXPECTED] oldPoolToken0Balance-newPoolToken0Balance:", oldPoolToken0Balance-newPoolToken0Balance, "expected: should be", strToUint64(c1))
	println()
}

// Collect Bar:Baz burned Liquidity by admin
func TestCollectBarBazLiquidity() {
	testing.SetRealm(posRealm)

	oldTest1Token0Balance := bar.BalanceOf(adminAddr)
	oldadminBazBalance := baz.BalanceOf(adminAddr)
	oldPoolToken0Balance := bar.BalanceOf(poolAddr)
	oldPoolBazBalance := baz.BalanceOf(poolAddr)

	c0, c1 := pool.Collect(
		cross,
		barPath,
		bazPath,
		fee500,
		adminAddr,
		test_tickLower,
		test_tickUpper,
		"100000",
		"100000",
	)

	println("[EXPECTED] c0:", c0, "expected: should not be 0")
	println("[EXPECTED] c1:", c1, "expected: should not be 0")

	newTest1Token0Balance := bar.BalanceOf(adminAddr)
	newadminBazBalance := baz.BalanceOf(adminAddr)
	newPoolToken0Balance := bar.BalanceOf(poolAddr)
	newPoolBazBalance := baz.BalanceOf(poolAddr)

	println("[EXPECTED] newTest1Token0Balance-oldTest1Token0Balance:", newTest1Token0Balance-oldTest1Token0Balance, "expected: should be", strToUint64(c0))
	println("[EXPECTED] newadminBazBalance-oldadminBazBalance:", newadminBazBalance-oldadminBazBalance, "expected: should be", strToUint64(c1))
	println("[EXPECTED] oldPoolToken0Balance-newPoolToken0Balance:", oldPoolToken0Balance-newPoolToken0Balance, "expected: should be", strToUint64(c0))
	println("[EXPECTED] oldPoolBazBalance-newPoolBazBalance:", oldPoolBazBalance-newPoolBazBalance, "expected: should be", strToUint64(c1))
	println()
}

func strToUint64(s string) uint64 {
	i, err := strconv.Atoi(s)
	if err != nil {
		panic("strToUint64")
	}
	return uint64(i)
}

// Output:
// [SCENARIO] Multi Token
// [INFO] Create foo <> bar pool
// [INFO] Create bar <> baz pool
// [SCENARIO] 1. Mint Foo:Bar Liquidity
// [EXPECTED] amount0: 8040316 expected: 8040316
// [EXPECTED] amount1: 2958015 expected: 2958015
//
// [SCENARIO] 2. Mint Bar:Baz Liquidity
// [EXPECTED] amount0: 6067683 expected: 2958015
// [EXPECTED] amount1: 0 expected: 8040316
//
// [SCENARIO] 3. Swap Foo:Bar Foo > Bar
// [EXPECTED] poolIn: 16000 expected: 16000
// [EXPECTED] poolOut: -5882 expected: -5882
//
// [EXPECTED] oldTest1Bar-newTest1Bar: 16000 expected: 16000
// [EXPECTED] newTest1Foo-oldTest1Foo: 5882 expected: 5882
// [EXPECTED] newPoolBar-oldPoolBar: 16000 expected: 16000
// [EXPECTED] oldPoolFoo-newPoolFoo: 5882 expected: 5882
//
// [SCENARIO] 4. Swap Bar:Baz Bar > Baz by admin
// [EXPECTED] poolIn: 0 expected: 16000
// [EXPECTED] poolOut: 0 expected: -43457
//
// [EXPECTED] oldTest1Token0Balance-newTest1Token0Balance: 0 expected: 16000
// [EXPECTED] newadminBazBalance-oldadminBazBalance: 0 expected: 43457
// [EXPECTED] newPoolToken0Balance-oldPoolToken0Balance: 0 expected: 16000
// [EXPECTED] oldPoolBazBalance-newPoolBazBalance: 0 expected: 43457
//
// [SCENARIO] 5. Collect Foo:Bar Fees
// [INFO] Swap: foo -> bar, thus only foo has fees
// [EXPECTED] c0: 7 expected: should not be 0
// [EXPECTED] c1: 0 expected: should be 0
// [EXPECTED] newTest1Token1Balance-oldTest1Token1Balance: 0 expected: should be 0
// [EXPECTED] newTest1Token0Balance-oldTest1Token0Balance: 7 expected: should be 7
// [EXPECTED] oldPoolToken1Balance-newPoolToken1Balance: 0 expected: should be 0
// [EXPECTED] oldPoolToken0Balance-newPoolToken0Balance: 7 expected: should be 7
//
// [SCENARIO] 6. Collect Bar:Baz Fees
// [INFO] Swap: bar -> baz, thus only bar has fees
// [EXPECTED] c0: 0 expected: should not be 0
// [EXPECTED] c1: 0 expected: should be 0
// [EXPECTED] newTest1Token0Balance-oldTest1Token0Balance: 0 expected: should be 0
// [EXPECTED] newadminBazBalance-oldadminBazBalance: 0 expected: should be 0
// [EXPECTED] oldPoolToken0Balance-newPoolToken0Balance: 0 expected: should be 0
// [EXPECTED] oldPoolBazBalance-newPoolBazBalance: 0 expected: should be 0
//
// [SCENARIO] 7. Burn Foo:Bar Liquidity
// [EXPECTED] b0: 8056307 expected: should not be 0
// [EXPECTED] b1: 2952131 expected: should not be 0
// [EXPECTED] expected: 100000000 expected: should be 100000000
//
// [SCENARIO] 8. Burn Bar:Baz Liquidity
// [EXPECTED] b0: 6067682 expected: should not be 0
// [EXPECTED] b1: 0 expected: should not be 0
// [EXPECTED] expected: 0 expected: should be 0
//
// [SCENARIO] 9. Collect Foo:Bar burned Liquidity
// [EXPECTED] c0: 100000 expected: should not be 0
// [EXPECTED] c1: 100000 expected: should not be 0
// [EXPECTED] newTest1Token1Balance-oldTest1Token1Balance: 100000 expected: should be 100000
// [EXPECTED] newTest1Token0Balance-oldTest1Token0Balance: 100000 expected: should be 100000
// [EXPECTED] oldPoolToken1Balance-newPoolToken1Balance: 100000 expected: should be 100000
// [EXPECTED] oldPoolToken0Balance-newPoolToken0Balance: 100000 expected: should be 100000
//
// [SCENARIO] 10. Collect Bar:Baz burned Liquidity
// [EXPECTED] c0: 100000 expected: should not be 0
// [EXPECTED] c1: 0 expected: should not be 0
// [EXPECTED] newTest1Token0Balance-oldTest1Token0Balance: 100000 expected: should be 100000
// [EXPECTED] newadminBazBalance-oldadminBazBalance: 0 expected: should be 0
// [EXPECTED] oldPoolToken0Balance-newPoolToken0Balance: 100000 expected: should be 100000
// [EXPECTED] oldPoolBazBalance-newPoolBazBalance: 0 expected: should be 0
