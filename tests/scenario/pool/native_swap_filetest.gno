package main

import (
	"std"
	"testing"

	"gno.land/r/demo/wugnot"

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
	// call gns faucet to get creation fee
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, consts.WRAPPED_WUGNOT, fooPath, fee500, "130621891405341611593710811006") // x2.7

	println("[SCENARIO] 1. Mint LP and Get GNFT")
	TestMint()

	println("[SCENARIO] 2. Swap Buy Native")
	TestSwapBuyNative()

	println("[SCENARIO] 3. Swap Sell Native")
	TestSwapSellNative()
}

// 2. Mint LP and Get GNFT
func TestMint() {
	token0, token1 := fooPath, consts.WRAPPED_WUGNOT
	if token1 < token0 {
		token0, token1 = token1, token0
	}

	println("[INFO] token0:", token0, "token1:", token1)

	// prepare ugnot
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 1_000_000}})
	// testBanker := std.NewBanker(std.BankerTypeRealmIssue)

	// simulate transfer
	testing.SetOriginSend(std.Coins{{"ugnot", 1_000_000}})

	// Deposit(wrap)
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, maxApprove)
	wugnot.Approve(cross, poolAddr, maxApprove)

	// Mint
	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		fooPath,
		consts.WRAPPED_WUGNOT,
		fee500,
		positionAddr,
		test_tickLower,
		test_tickUpper,
		"10000000",
		adminAddr,
	)

	println("[EXPECTED] amount0:", amount0, "expected: should be 295802")
	println("[EXPECTED] amount1:", amount1, "expected: should be 804032")
	println()
}

func TestSwapBuyNative() {
	pools := pool.GetPool(fooPath, consts.WRAPPED_WUGNOT, fee500)

	adminOldT0Bal := common.GetToken(pools.Token0Path()).BalanceOf(adminAddr)
	adminOldT1Bal := common.GetToken(pools.Token1Path()).BalanceOf(adminAddr)
	println("[EXPECTED] adminOldT0Bal:", adminOldT0Bal, "expected: should be 704198")
	println("[EXPECTED] adminOldT1Bal:", adminOldT1Bal, "expected: should be 99999899195968")

	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, 10000)

	testing.SetRealm(rouRealm)
	amount0, amount1 := pool.Swap(
		cross,
		fooPath,               // token0
		consts.WRAPPED_WUGNOT, // token1
		fee500,
		adminAddr,
		true,
		"10000",
		consts.MIN_PRICE,
		adminAddr,
	)

	println("[EXPECTED] amount0:", amount0, "expected: should be 10000")
	println("[EXPECTED] amount1:", amount1, "expected: should be -27123")

	adminNewT0Bal := common.GetToken(pools.Token0Path()).BalanceOf(adminAddr)
	adminNewT1Bal := common.GetToken(pools.Token1Path()).BalanceOf(adminAddr)
	println("[EXPECTED] adminNewT0Bal:", adminNewT0Bal, "expected: should be 694198")
	println("[EXPECTED] adminNewT1Bal:", adminNewT1Bal, "expected: should be 99999899223091")
	println()
}

func TestSwapSellNative() {
	pools := pool.GetPool(fooPath, consts.WRAPPED_WUGNOT, fee500)

	adminOldT0Bal := common.GetToken(pools.Token0Path()).BalanceOf(adminAddr)
	adminOldT1Bal := common.GetToken(pools.Token1Path()).BalanceOf(adminAddr)
	println("[EXPECTED] adminOldT0Bal:", adminOldT0Bal, "expected: should be 694198")
	println("[EXPECTED] adminOldT1Bal:", adminOldT1Bal, "expected: should be 99999899223091")

	testing.SetRealm(adminRealm)
	wugnot.Approve(cross, poolAddr, 27123)

	testing.SetRealm(rouRealm)
	amount0, amount1 := pool.Swap( // ugnot 10_000 > foo ??
		cross,
		fooPath,               // token0
		consts.WRAPPED_WUGNOT, // token1
		fee500,
		adminAddr,
		false,
		"10000",
		consts.MAX_PRICE,
		adminAddr,
	)

	println("[EXPECTED] amount0:", amount0, "expected: should be -3687")
	println("[EXPECTED] amount1:", amount1, "expected: should be 10000")

	adminNewT0Bal := common.GetToken(pools.Token0Path()).BalanceOf(adminAddr)
	adminNewT1Bal := common.GetToken(pools.Token1Path()).BalanceOf(adminAddr)
	println("[EXPECTED] adminNewT0Bal:", adminNewT0Bal, "expected: should be 697885")
	println("[EXPECTED] adminNewT1Bal:", adminNewT1Bal, "expected: should be 99999899213091")
	println()
}

// Output:
// [SCENARIO] 1. Mint LP and Get GNFT
// [INFO] token0: gno.land/r/demo/wugnot token1: gno.land/r/onbloc/foo
// [EXPECTED] amount0: 295802 expected: should be 295802
// [EXPECTED] amount1: 804032 expected: should be 804032
//
// [SCENARIO] 2. Swap Buy Native
// [EXPECTED] adminOldT0Bal: 704198 expected: should be 704198
// [EXPECTED] adminOldT1Bal: 99999999195968 expected: should be 99999899195968
// [EXPECTED] amount0: 10000 expected: should be 10000
// [EXPECTED] amount1: -27123 expected: should be -27123
// [EXPECTED] adminNewT0Bal: 694198 expected: should be 694198
// [EXPECTED] adminNewT1Bal: 99999999223091 expected: should be 99999899223091
//
// [SCENARIO] 3. Swap Sell Native
// [EXPECTED] adminOldT0Bal: 694198 expected: should be 694198
// [EXPECTED] adminOldT1Bal: 99999999223091 expected: should be 99999899223091
// [EXPECTED] amount0: -3687 expected: should be -3687
// [EXPECTED] amount1: 10000 expected: should be 10000
// [EXPECTED] adminNewT0Bal: 697885 expected: should be 697885
// [EXPECTED] adminNewT1Bal: 99999999213091 expected: should be 99999899213091
