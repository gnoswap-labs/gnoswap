// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"strconv"
	"testing"

	"gno.land/r/gnoland/wugnot"

	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/onbloc/foo"

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
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341"

	WRAPPED_WUGNOT string = "gno.land/r/gnoland/wugnot"
)

func main() {
	// call gns faucet to get creation fee
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, WRAPPED_WUGNOT, fooPath, fee500, "130621891405341611593710811006") // x2.7

	println("[SCENARIO] 1. Mint LP and Get GNFT")
	TestMint()

	println("[SCENARIO] 2. Swap Buy Native")
	TestSwapBuyNative()

	println("[SCENARIO] 3. Swap Sell Native")
	TestSwapSellNative()
}

// 2. Mint LP and Get GNFT
func TestMint() {
	token0, token1 := fooPath, WRAPPED_WUGNOT
	if token1 < token0 {
		token0, token1 = token1, token0
	}

	println("[INFO] token0:", token0, "token1:", token1)

	// prepare ugnot
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 1_000_000}})
	// testBanker := std.NewBanker(std.BankerTypeRealmIssue)

	// simulate transfer
	testing.SetOriginSend(chain.Coins{{"ugnot", 1_000_000}})

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
		WRAPPED_WUGNOT,
		fee500,
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
	pools := pool.GetPool(fooPath, WRAPPED_WUGNOT, fee500)

	adminOldT0Bal := common.GetToken(pools.Token0Path()).BalanceOf(adminAddr)
	adminOldT1Bal := common.GetToken(pools.Token1Path()).BalanceOf(adminAddr)

	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, 10000)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/v1/router"))
	amount0, amount1 := pool.Swap(
		cross,
		WRAPPED_WUGNOT, // token0
		fooPath,        // token1
		fee500,
		adminAddr,
		true,
		"10000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta string) error {
			return mockSwapCallback(WRAPPED_WUGNOT, fooPath, amount0Delta, amount1Delta, true)
		},
	)

	println("[EXPECTED] amount0:", amount0, "expected: should be 10000")
	println("[EXPECTED] amount1:", amount1, "expected: should be -27123")

	adminNewT0Bal := common.GetToken(pools.Token0Path()).BalanceOf(adminAddr)
	adminNewT1Bal := common.GetToken(pools.Token1Path()).BalanceOf(adminAddr)
	println("[EXPECTED] admin token0 changed:", adminNewT0Bal-adminOldT0Bal, "expected: should be 694198")
	println("[EXPECTED] admin token1 changed:", adminNewT1Bal-adminOldT1Bal, "expected: should be 99999899223091")
	println()
}

func TestSwapSellNative() {
	pools := pool.GetPool(fooPath, WRAPPED_WUGNOT, fee500)

	adminOldT0Bal := common.GetToken(pools.Token0Path()).BalanceOf(adminAddr)
	adminOldT1Bal := common.GetToken(pools.Token1Path()).BalanceOf(adminAddr)

	testing.SetRealm(adminRealm)
	wugnot.Approve(cross, poolAddr, 27123)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/v1/router"))
	amount0, amount1 := pool.Swap( // ugnot 10_000 > foo ??
		cross,
		WRAPPED_WUGNOT, // token0
		fooPath,        // token1
		fee500,
		adminAddr,
		false,
		"10000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta string) error {
			return mockSwapCallback(WRAPPED_WUGNOT, fooPath, amount0Delta, amount1Delta, false)
		},
	)

	println("[EXPECTED] amount0:", amount0, "expected: should be -3687")
	println("[EXPECTED] amount1:", amount1, "expected: should be 10000")

	adminNewT0Bal := common.GetToken(pools.Token0Path()).BalanceOf(adminAddr)
	adminNewT1Bal := common.GetToken(pools.Token1Path()).BalanceOf(adminAddr)
	println("[EXPECTED] admin token0 changed:", adminNewT0Bal-adminOldT0Bal, "expected: should be 697885")
	println("[EXPECTED] admin token1 changed:", adminNewT1Bal-adminOldT1Bal, "expected: should be 99999899213091")
	println()
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
// [SCENARIO] 1. Mint LP and Get GNFT
// [INFO] token0: gno.land/r/gnoland/wugnot token1: gno.land/r/onbloc/foo
// [EXPECTED] amount0: 295802 expected: should be 295802
// [EXPECTED] amount1: 804032 expected: should be 804032
//
// [SCENARIO] 2. Swap Buy Native
// [EXPECTED] amount0: 10000 expected: should be 10000
// [EXPECTED] amount1: -27123 expected: should be -27123
// [EXPECTED] admin token0 changed: 0 expected: should be 694198
// [EXPECTED] admin token1 changed: 27123 expected: should be 99999899223091
//
// [SCENARIO] 3. Swap Sell Native
// [EXPECTED] amount0: -3687 expected: should be -3687
// [EXPECTED] amount1: 10000 expected: should be 10000
// [EXPECTED] admin token0 changed: 3687 expected: should be 697885
// [EXPECTED] admin token1 changed: -10000 expected: should be 99999899213091
