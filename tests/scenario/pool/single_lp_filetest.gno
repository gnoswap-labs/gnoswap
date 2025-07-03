package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	pl "gno.land/r/gnoswap/v1/pool"

	u256 "gno.land/p/gnoswap/uint256"
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
	positionAddr = consts.POSITION_ADDR
	poolAddr     = consts.POOL_ADDR
	rouRealm     = std.NewCodeRealm(consts.ROUTER_PATH)
)

var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
)

var (
	test_tickLower          = int32(9000)
	test_tickUpper          = int32(11000)
	test_liquidityExpectStr = "1000"
	test_liquidityExpect256 = u256.NewUint(1000)

	test_tickLower2 = int32(50000)
	test_tickUpper2 = int32(100000)

	poolCreationFee = int64(100_000_000)
)

func main() {
	println("[INFO] Create Foo:Bar Pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Create Bar:Foo Pool")
	gns.Approve(cross, poolAddr, poolCreationFee)
	pl.CreatePool(cross, barPath, fooPath, fee500, "130621891405341611593710811006") // x2.7

	println("[SCENARIO] 1. Mint by admin")
	TestMint()

	println("[SCENARIO] 2. Burn by admin")
	TestBurn()

	println("[SCENARIO] 3. Collect by admin")
	TestCollect()

	println("[SCENARIO] 4. Swap by admin")
	TestSwap()

	println("[INFO] Passed all tests")
}

// 2. Mint by admin
func TestMint() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, maxApprove)
	foo.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	amount0, amount1 := pl.Mint(
		cross,
		fooPath,
		barPath,
		fee500,
		positionAddr,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpectStr,
		adminAddr,
	)
	println("[EXPECTED] amount0:", amount0, "expected: should be 30")
	println("[EXPECTED] amount1:", amount1, "expected: should be 81")

	pool := pl.GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.Liquidity()
	println("[EXPECTED] test_liquidity.Dec():", test_liquidity.Dec(), "expected: should be 1000")

	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)

	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)

	test_liquidity = pool.Liquidity()
	println("[EXPECTED] test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(10))):", test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(10))), "expected: should be true")

	println("[INFO] tickLower > currentTick == don't add to current liquidity")
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower2, test_tickUpper2, test_liquidityExpectStr, adminAddr)

	println("[INFO] tickUpper < current tick == don't add to current liquidity")
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, -test_tickUpper2, -test_tickLower2, test_liquidityExpectStr, adminAddr)

	println("tickUpper < tickLower == don't add to current liquidity")
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, -test_tickUpper, -test_tickLower, test_liquidityExpectStr, adminAddr)

	expected := new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(10))
	println("[EXPECTED] test_liquidity.Eq(expected):", test_liquidity.Eq(expected), "expected: should be true")

	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)

	test_liquidity = pool.Liquidity()
	expected = new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(20))
	println("[EXPECTED] test_liquidity.Eq(expected):", test_liquidity.Eq(expected), "expected: should be true")
	println()
}

// 3. Burn by admin
func TestBurn() {
	testing.SetRealm(posRealm)

	b11, b12 := pl.Burn(cross, barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	b21, b22 := pl.Burn(cross, barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpectStr, adminAddr)
	println("[INFO] Burned amounts should be same")
	println("[EXPECTED] b11:", b11, "expected: should be 29")
	println("[EXPECTED] b21:", b21, "expected: should be 29")
	println("[EXPECTED] b12:", b12, "expected: should be 80")
	println("[EXPECTED] b22:", b22, "expected: should be 80")

	pool := pl.GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.Liquidity()
	println("[EXPECTED] test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(18))):", test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(18))), "expected: should be true")

	pl.Burn(cross, barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(8)).ToString(), adminAddr)
	test_liquidity = pool.Liquidity()
	println("[EXPECTED] test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(10))):", test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(10))), "expected: should be true")

	pl.Burn(cross, barPath, fooPath, fee500, test_tickLower, test_tickUpper, "1", adminAddr)
	test_liquidity = pool.Liquidity()
	println("[EXPECTED] test_liquidity.ToString():", test_liquidity.ToString(), "expected: should be 9999")

	pl.Burn(cross, barPath, fooPath, fee500, test_tickLower, test_tickUpper, "999", adminAddr)
	test_liquidity = pool.Liquidity()
	println("[EXPECTED] test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(9))):", test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(9))), "expected: should be true")

	pl.Burn(cross, barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(9)).ToString(), adminAddr)
	test_liquidity = pool.Liquidity()
	println("[EXPECTED] test_liquidity.ToString():", test_liquidity.ToString(), "expected: should be 0")
	println()
}

func TestCollect() {
	testing.SetRealm(posRealm)

	// withdraw all token before test `Collect`
	pl.Collect(cross, barPath, fooPath, fee500, adminAddr, test_tickLower, test_tickUpper, "50000000", "50000000")

	// pool should have zero liquidity
	pool := pl.GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.Liquidity()
	println("[EXPECTED] test_liquidity.ToString():", test_liquidity.ToString(), "expected: should be 0")

	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString(), adminAddr)
	pl.Burn(cross, barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString(), adminAddr)
	c11, c12 := pl.Collect(cross, barPath, fooPath, fee500, adminAddr, test_tickLower, test_tickUpper, "50000000", "50000000")

	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString(), adminAddr)
	pl.Burn(cross, barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString(), adminAddr)
	c21, c22 := pl.Collect(cross, barPath, fooPath, fee500, adminAddr, test_tickLower, test_tickUpper, "50000000", "50000000")

	println("[EXPECTED] c11:", c11, "expected: should be 443")
	println("[EXPECTED] c21:", c21, "expected: should be 443")
	println("[EXPECTED] c12:", c12, "expected: should be 1206")
	println("[EXPECTED] c22:", c22, "expected: should be 1206")

	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString(), adminAddr)
	pl.Burn(cross, barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString(), adminAddr)
	c31, c32 := pl.Collect(cross, barPath, fooPath, fee500, adminAddr, test_tickLower, test_tickUpper, "100", "100")
	println("[EXPECTED] c31:", c31, "expected: should be 100")
	println("[EXPECTED] c32:", c32, "expected: should be 100")

	c41, c42 := pl.Collect(cross, barPath, fooPath, fee500, adminAddr, test_tickLower, test_tickUpper, "50000000", "50000000")
	println("[EXPECTED] c41:", c41, "expected: should be 343")  // 343 = c21 - 100
	println("[EXPECTED] c42:", c42, "expected: should be 1106") // 1106 = c22 - 100

	println("[INFO] Mint > No Burn => nothing to collect")
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString(), adminAddr)
	c51, c52 := pl.Collect(cross, barPath, fooPath, fee500, adminAddr, test_tickLower, test_tickUpper, "50000000", "50000000")
	println("[EXPECTED] c51:", c51, "expected: should be 0")
	println("[EXPECTED] c52:", c52, "expected: should be 0")

	println("[INFO] Burn Now => something to collect")
	pl.Burn(cross, barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString(), adminAddr)
	c61, c62 := pl.Collect(cross, barPath, fooPath, fee500, adminAddr, test_tickLower, test_tickUpper, "50000000", "50000000")
	println("[EXPECTED] c61:", c61, "expected: should not be 0")
	println("[EXPECTED] c62:", c62, "expected: should not be 0")
	println()
}

func TestSwap() {
	pool := pl.GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.Liquidity()
	println("[EXPECTED] test_liquidity.ToString():", test_liquidity.ToString(), "expected: should be 0")

	testing.SetRealm(posRealm)
	pl.Mint(cross, barPath, fooPath, fee500, positionAddr, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(20000)).ToString(), adminAddr)

	testing.SetRealm(rouRealm)
	test_price := consts.MIN_PRICE
	{
		poolOldToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(poolAddr)
		poolOldToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(poolAddr)

		userOldToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(adminAddr)
		userOldToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(adminAddr)

		amount0, amount1 := pl.Swap(
			cross,
			fooPath,    // token0Path
			barPath,    // token1Path
			fee500,     // fee
			adminAddr,  // recipient
			true,       // zeroForOne
			"10000",    // _amountSpecified
			test_price, // _sqrtPriceLimitX96
			adminAddr,  // payer
		)

		println("[EXPECTED] amount0:", amount0, "expected: should not be 0")
		println("[EXPECTED] amount1:", amount1, "expected: should not be 0")
		intAmount0, _ := strconv.Atoi(amount0)
		intAmount1, _ := strconv.Atoi(amount1)

		poolNewToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(poolAddr)
		poolNewToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(poolAddr)

		userNewToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(adminAddr)
		userNewToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(adminAddr)

		println("[EXPECTED] userOldToken0Bal-userNewToken0Bal:", userOldToken0Bal-userNewToken0Bal, "expected: should be", intAmount0)
		println("[EXPECTED] userNewToken1Bal-userOldToken1Bal:", userNewToken1Bal-userOldToken1Bal, "expected: should be", -intAmount1)
		println("[EXPECTED] poolNewToken0Bal-poolOldToken0Bal:", poolNewToken0Bal-poolOldToken0Bal, "expected: should be", intAmount0)
		println("[EXPECTED] poolOldToken1Bal-poolNewToken1Bal:", poolOldToken1Bal-poolNewToken1Bal, "expected: should be", -intAmount1)
	}

	{
		poolOldToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(poolAddr)
		poolOldToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(poolAddr)

		userOldToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(adminAddr)
		userOldToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(adminAddr)

		amount0, amount1 := pl.Swap(cross, barPath, fooPath, fee500, adminAddr, true, "5000", test_price, adminAddr) // give enough amount to take fees away

		intAmount0, _ := strconv.Atoi(amount0)
		intAmount1, _ := strconv.Atoi(amount1)

		poolNewToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(poolAddr)
		poolNewToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(poolAddr)

		userNewToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(adminAddr)
		userNewToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(adminAddr)

		println("[EXPECTED] userOldToken0Bal-userNewToken0Bal:", userOldToken0Bal-userNewToken0Bal, "expected: should be", intAmount0)
		println("[EXPECTED] userNewToken1Bal-userOldToken1Bal:", userNewToken1Bal-userOldToken1Bal, "expected: should be", -intAmount1)
		println("[EXPECTED] poolNewToken0Bal-poolOldToken0Bal:", poolNewToken0Bal-poolOldToken0Bal, "expected: should be", intAmount0)
		println("[EXPECTED] poolOldToken1Bal-poolNewToken1Bal:", poolOldToken1Bal-poolNewToken1Bal, "expected: should be", -intAmount1)
	}

	{
		poolOldToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(poolAddr)
		poolOldToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(poolAddr)

		userOldToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(adminAddr)
		userOldToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(adminAddr)

		amount0, amount1 := pl.Swap(cross, barPath, fooPath, fee500, adminAddr, true, "1000", test_price, adminAddr) // give enough amount to take fees away

		intAmount0, _ := strconv.Atoi(amount0)
		intAmount1, _ := strconv.Atoi(amount1)

		poolNewToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(poolAddr)
		poolNewToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(poolAddr)

		userNewToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(adminAddr)
		userNewToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(adminAddr)

		println("[EXPECTED] userOldToken0Bal-userNewToken0Bal:", userOldToken0Bal-userNewToken0Bal, "expected: should be", intAmount0)
		println("[EXPECTED] userNewToken1Bal-userOldToken1Bal:", userNewToken1Bal-userOldToken1Bal, "expected: should be", -intAmount1)
		println("[EXPECTED] poolNewToken0Bal-poolOldToken0Bal:", poolNewToken0Bal-poolOldToken0Bal, "expected: should be", intAmount0)
		println("[EXPECTED] poolOldToken1Bal-poolNewToken1Bal:", poolOldToken1Bal-poolNewToken1Bal, "expected: should be", -intAmount1)
	}

	println("[INFO] Swap token1 -> token0")
	{
		poolOldToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(poolAddr)
		poolOldToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(poolAddr)

		userOldToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(adminAddr)
		userOldToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(adminAddr)

		amount0, amount1 := pl.Swap(cross, barPath, fooPath, fee500, adminAddr, false, "16000", consts.MAX_PRICE, adminAddr) // give enough amount to take fees away

		intAmount0, _ := strconv.Atoi(amount0)
		intAmount1, _ := strconv.Atoi(amount1)

		poolNewToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(poolAddr)
		poolNewToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(poolAddr)

		userNewToken0Bal := common.GetToken(pool.Token0Path()).BalanceOf(adminAddr)
		userNewToken1Bal := common.GetToken(pool.Token1Path()).BalanceOf(adminAddr)

		println("[EXPECTED] userOldToken0Bal-userNewToken0Bal:", userOldToken0Bal-userNewToken0Bal, "expected: should be", intAmount0)
		println("[EXPECTED] userNewToken1Bal-userOldToken1Bal:", userNewToken1Bal-userOldToken1Bal, "expected: should be", -intAmount1)
		println("[EXPECTED] poolNewToken0Bal-poolOldToken0Bal:", poolNewToken0Bal-poolOldToken0Bal, "expected: should be", intAmount0)
		println("[EXPECTED] poolOldToken1Bal-poolNewToken1Bal:", poolOldToken1Bal-poolNewToken1Bal, "expected: should be", -intAmount1)
	}

	println("[INFO] Finished swap")
	println()
}

// Output:
// [INFO] Create Foo:Bar Pool
// [INFO] Create Bar:Foo Pool
// [SCENARIO] 1. Mint by admin
// [EXPECTED] amount0: 30 expected: should be 30
// [EXPECTED] amount1: 81 expected: should be 81
// [EXPECTED] test_liquidity.Dec(): 1000 expected: should be 1000
// [EXPECTED] test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(10))): true expected: should be true
// [INFO] tickLower > currentTick == don't add to current liquidity
// [INFO] tickUpper < current tick == don't add to current liquidity
// tickUpper < tickLower == don't add to current liquidity
// [EXPECTED] test_liquidity.Eq(expected): true expected: should be true
// [EXPECTED] test_liquidity.Eq(expected): true expected: should be true
//
// [SCENARIO] 2. Burn by admin
// [INFO] Burned amounts should be same
// [EXPECTED] b11: 29 expected: should be 29
// [EXPECTED] b21: 29 expected: should be 29
// [EXPECTED] b12: 80 expected: should be 80
// [EXPECTED] b22: 80 expected: should be 80
// [EXPECTED] test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(18))): true expected: should be true
// [EXPECTED] test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(10))): true expected: should be true
// [EXPECTED] test_liquidity.ToString(): 9999 expected: should be 9999
// [EXPECTED] test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(9))): true expected: should be true
// [EXPECTED] test_liquidity.ToString(): 0 expected: should be 0
//
// [SCENARIO] 3. Collect by admin
// [EXPECTED] test_liquidity.ToString(): 0 expected: should be 0
// [EXPECTED] c11: 443 expected: should be 443
// [EXPECTED] c21: 443 expected: should be 443
// [EXPECTED] c12: 1206 expected: should be 1206
// [EXPECTED] c22: 1206 expected: should be 1206
// [EXPECTED] c31: 100 expected: should be 100
// [EXPECTED] c32: 100 expected: should be 100
// [EXPECTED] c41: 343 expected: should be 343
// [EXPECTED] c42: 1106 expected: should be 1106
// [INFO] Mint > No Burn => nothing to collect
// [EXPECTED] c51: 0 expected: should be 0
// [EXPECTED] c52: 0 expected: should be 0
// [INFO] Burn Now => something to collect
// [EXPECTED] c61: 443 expected: should not be 0
// [EXPECTED] c62: 1206 expected: should not be 0
//
// [SCENARIO] 4. Swap by admin
// [EXPECTED] test_liquidity.ToString(): 0 expected: should be 0
// [EXPECTED] amount0: 10000 expected: should not be 0
// [EXPECTED] amount1: -27145 expected: should not be 0
// [EXPECTED] userOldToken0Bal-userNewToken0Bal: 10000 expected: should be 10000
// [EXPECTED] userNewToken1Bal-userOldToken1Bal: 27145 expected: should be 27145
// [EXPECTED] poolNewToken0Bal-poolOldToken0Bal: 10000 expected: should be 10000
// [EXPECTED] poolOldToken1Bal-poolNewToken1Bal: 27145 expected: should be 27145
// [EXPECTED] userOldToken0Bal-userNewToken0Bal: 5000 expected: should be 5000
// [EXPECTED] userNewToken1Bal-userOldToken1Bal: 13554 expected: should be 13554
// [EXPECTED] poolNewToken0Bal-poolOldToken0Bal: 5000 expected: should be 5000
// [EXPECTED] poolOldToken1Bal-poolNewToken1Bal: 13554 expected: should be 13554
// [EXPECTED] userOldToken0Bal-userNewToken0Bal: 1000 expected: should be 1000
// [EXPECTED] userNewToken1Bal-userOldToken1Bal: 2708 expected: should be 2708
// [EXPECTED] poolNewToken0Bal-poolOldToken0Bal: 1000 expected: should be 1000
// [EXPECTED] poolOldToken1Bal-poolNewToken1Bal: 2708 expected: should be 2708
// [INFO] Swap token1 -> token0
// [EXPECTED] userOldToken0Bal-userNewToken0Bal: -5896 expected: should be -5896
// [EXPECTED] userNewToken1Bal-userOldToken1Bal: -16000 expected: should be -16000
// [EXPECTED] poolNewToken0Bal-poolOldToken0Bal: -5896 expected: should be -5896
// [EXPECTED] poolOldToken1Bal-poolNewToken1Bal: -16000 expected: should be -16000
// [INFO] Finished swap
//
// [INFO] Passed all tests
