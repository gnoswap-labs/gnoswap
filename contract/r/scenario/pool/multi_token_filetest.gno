// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"strconv"
	"testing"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"

	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/gns"
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
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	rouRealm        = testing.NewUserRealm(routerAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
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

	MIN_PRICE string = "4295128740"
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

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/v1/router"))
	poolIn, poolOut := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"16000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta string) error {
			mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, true)

			return nil
		},
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

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/v1/router"))
	poolIn, poolOut := pool.Swap(
		cross,
		barPath,
		bazPath,
		fee500,
		adminAddr,
		true,
		"16000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta string) error {
			return mockSwapCallback(barPath, bazPath, amount0Delta, amount1Delta, true)
		},
	)

	println("[EXPECTED] poolIn:", poolIn, "expected: 16000")
	println("[EXPECTED] poolOut:", poolOut, "expected: -43457")
	println()

	newTest1Token0Balance := bar.BalanceOf(adminAddr)
	newAdminBazBalance := baz.BalanceOf(adminAddr)
	newPoolToken0Balance := bar.BalanceOf(poolAddr)
	newPoolBazBalance := baz.BalanceOf(poolAddr)

	println("[EXPECTED] oldTest1Token0Balance-newTest1Token0Balance:", oldTest1Token0Balance-newTest1Token0Balance, "expected: 16000")
	println("[EXPECTED] newAdminBazBalance-oldadminBazBalance:", newAdminBazBalance-oldadminBazBalance, "expected: 43457")
	println("[EXPECTED] newPoolToken0Balance-oldPoolToken0Balance:", newPoolToken0Balance-oldPoolToken0Balance, "expected: 16000")
	println("[EXPECTED] oldPoolBazBalance-newPoolBazBalance:", oldPoolBazBalance-newPoolBazBalance, "expected: 43457")
	println()
}

func TestCollectFooBarFees() {
	testing.SetRealm(posRealm)

	poolPath := ufmt.Sprintf("%s:%s:%d", barPath, fooPath, fee500)
	oldToken0Balance := pool.GetBalanceToken0(poolPath)
	oldToken1Balance := pool.GetBalanceToken1(poolPath)

	// burn 0 to collect swap fees
	pool.Burn(cross, barPath, fooPath, fee500, -test_tickUpper, -test_tickLower, "0", adminAddr)

	c0, c1 := pool.Collect(
		cross,
		barPath,
		fooPath,
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

	newToken0Balance := pool.GetBalanceToken0(poolPath)
	newToken1Balance := pool.GetBalanceToken1(poolPath)

	println("[EXPECTED] oldToken0Balance:", oldToken0Balance)
	println("[EXPECTED] oldToken1Balance:", oldToken1Balance)
	println("[EXPECTED] newToken0Balance:", newToken0Balance)
	println("[EXPECTED] newToken1Balance:", newToken1Balance)
	println()
}

func TestCollectBarBazFees() {
	testing.SetRealm(posRealm)

	poolPath := ufmt.Sprintf("%s:%s:%d", barPath, bazPath, fee500)
	oldToken0Balance := pool.GetBalanceToken1(poolPath)
	oldToken1Balance := pool.GetBalanceToken0(poolPath)

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

	newToken0Balance := pool.GetBalanceToken0(poolPath)
	newToken1Balance := pool.GetBalanceToken1(poolPath)

	println("[EXPECTED] oldToken0Balance:", oldToken0Balance)
	println("[EXPECTED] oldToken1Balance:", oldToken1Balance)
	println("[EXPECTED] newToken0Balance:", newToken0Balance)
	println("[EXPECTED] newToken1Balance:", newToken1Balance)
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

	poolPath := ufmt.Sprintf("%s:%s:%d", barPath, fooPath, fee500)
	oldToken0Balance := pool.GetBalanceToken0(poolPath)
	oldToken1Balance := pool.GetBalanceToken1(poolPath)

	c0, c1 := pool.Collect(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		-test_tickUpper,
		-test_tickLower,
		"100000",
		"100000",
	)

	println("[EXPECTED] c0:", c0, "expected: should not be 0")
	println("[EXPECTED] c1:", c1, "expected: should not be 0")

	newToken0Balance := pool.GetBalanceToken0(poolPath)
	newToken1Balance := pool.GetBalanceToken1(poolPath)

	println("[EXPECTED] oldToken0Balance:", oldToken0Balance)
	println("[EXPECTED] oldToken1Balance:", oldToken1Balance)
	println("[EXPECTED] newToken0Balance:", newToken0Balance)
	println("[EXPECTED] newToken1Balance:", newToken1Balance)
	println()
}

// Collect Bar:Baz burned Liquidity by admin
func TestCollectBarBazLiquidity() {
	testing.SetRealm(posRealm)

	poolPath := ufmt.Sprintf("%s:%s:%d", barPath, bazPath, fee500)
	oldToken0Balance := pool.GetBalanceToken1(poolPath)
	oldToken1Balance := pool.GetBalanceToken0(poolPath)

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

	newToken0Balance := pool.GetBalanceToken0(poolPath)
	newToken1Balance := pool.GetBalanceToken1(poolPath)

	println("[EXPECTED] oldToken0Balance:", oldToken0Balance)
	println("[EXPECTED] oldToken1Balance:", oldToken1Balance)
	println("[EXPECTED] newToken0Balance:", newToken0Balance)
	println("[EXPECTED] newToken1Balance:", newToken1Balance)
	println()
}

func strToUint64(s string) uint64 {
	i, err := strconv.Atoi(s)
	if err != nil {
		panic("strToUint64")
	}
	return uint64(i)
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta string, amount1Delta string, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	const wugnotPath = "gno.land/r/gnoland/wugnot"
	const ugnotDenom = "ugnot"

	amount0Int64, _ := strconv.ParseInt(amount0Delta, 10, 64)
	amount1Int64, _ := strconv.ParseInt(amount1Delta, 10, 64)

	if zeroForOne {
		if token0Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Int64}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Int64)
	} else {
		if token1Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Int64}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Int64)
	}

	return nil
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
// [EXPECTED] newAdminBazBalance-oldadminBazBalance: 0 expected: 43457
// [EXPECTED] newPoolToken0Balance-oldPoolToken0Balance: 0 expected: 16000
// [EXPECTED] oldPoolBazBalance-newPoolBazBalance: 0 expected: 43457
//
// [SCENARIO] 5. Collect Foo:Bar Fees
// [INFO] Swap: foo -> bar, thus only foo has fees
// [EXPECTED] c0: 7 expected: should not be 0
// [EXPECTED] c1: 0 expected: should be 0
// [EXPECTED] oldToken0Balance: 8056316
// [EXPECTED] oldToken1Balance: 2952133
// [EXPECTED] newToken0Balance: 8056309
// [EXPECTED] newToken1Balance: 2952133
//
// [SCENARIO] 6. Collect Bar:Baz Fees
// [INFO] Swap: bar -> baz, thus only bar has fees
// [EXPECTED] c0: 0 expected: should not be 0
// [EXPECTED] c1: 0 expected: should be 0
// [EXPECTED] oldToken0Balance: 0
// [EXPECTED] oldToken1Balance: 6067683
// [EXPECTED] newToken0Balance: 6067683
// [EXPECTED] newToken1Balance: 0
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
// [EXPECTED] oldToken0Balance: 8056309
// [EXPECTED] oldToken1Balance: 2952133
// [EXPECTED] newToken0Balance: 7956309
// [EXPECTED] newToken1Balance: 2852133
//
// [SCENARIO] 10. Collect Bar:Baz burned Liquidity
// [EXPECTED] c0: 100000 expected: should not be 0
// [EXPECTED] c1: 0 expected: should not be 0
// [EXPECTED] oldToken0Balance: 0
// [EXPECTED] oldToken1Balance: 6067683
// [EXPECTED] newToken0Balance: 5967683
// [EXPECTED] newToken1Balance: 0
