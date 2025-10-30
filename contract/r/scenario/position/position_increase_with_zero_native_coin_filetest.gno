// position increase with zero native coin test

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"chain/banker"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"
)

const MIN_PRICE string = "4295128740"

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	routerRealm     = testing.NewUserRealm(routerAddr)

	wugnotPath        = "gno.land/r/gnoland/wugnot"
	fooPath           = "gno.land/r/onbloc/foo"
	fee500     uint32 = 500
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool with tick 100")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint initial position (-12000~0)")
	checkBalanceChanges(mintInitialPositionWithNativeCoin)
	println()

	ufmt.Println("[SCENARIO] 3. Increase position liquidity")
	checkBalanceChanges(func() { increasePositionLiquidity(50000000, 50000000) })
	println()

	ufmt.Println("[SCENARIO] 4. Increase position liquidity with zero native coin")
	checkBalanceChanges(func() { increasePositionLiquidity(0, 50000000) })
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 100000000}})

	currentBanker := banker.NewBanker(banker.BankerTypeReadonly)
	println("[INFO] GNOT balance of admin", currentBanker.GetCoins(adminAddr).AmountOf("ugnot"))

	ufmt.Println("[INFO] Creating pool at tick 100")
	ufmt.Println("[INFO] Pool path", pool.GetPoolPath(wugnotPath, fooPath, fee500))
	pool.CreatePool(
		cross,
		wugnotPath,
		fooPath,
		fee500,
		common.TickMathGetSqrtRatioAtTick(100).ToString(),
	)
}

func mintInitialPositionWithNativeCoin() {
	testing.SetRealm(adminRealm)

	amount0DesiredInt := int64(0)
	amount1DesiredInt := int64(50000000)

	foo.Approve(cross, poolAddr, amount1DesiredInt)

	// Set none native coin send
	testing.SetOriginSend(chain.Coins{})

	inputToken0Path := "gnot"
	inputToken1Path := fooPath
	minTick := int32(-12000)
	maxTick := int32(0)
	amount0Desired := ufmt.Sprintf("%d", amount0DesiredInt)
	amount1Desired := ufmt.Sprintf("%d", amount1DesiredInt)
	amount0Min := "0"
	amount1Min := "0"

	ufmt.Println("[INFO] Minting initial position with native coin")
	ufmt.Printf("[INFO] Input token0 path: %s\n", inputToken0Path)
	ufmt.Printf("[INFO] Input token1 path: %s\n", inputToken1Path)
	ufmt.Printf("[INFO] Min tick: %d\n", minTick)
	ufmt.Printf("[INFO] Max tick: %d\n", maxTick)
	ufmt.Printf("[INFO] Amount0 desired: %s\n", amount0Desired)
	ufmt.Printf("[INFO] Amount1 desired: %s\n", amount1Desired)
	ufmt.Printf("[INFO] Amount0 min: %s\n", amount0Min)
	ufmt.Printf("[INFO] Amount1 min: %s\n", amount1Min)

	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		inputToken0Path,
		inputToken1Path,
		fee500,
		minTick,
		maxTick,
		amount0Desired,
		amount1Desired,
		amount0Min,
		amount1Min,
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func increasePositionLiquidity(amount0DesiredInt, amount1DesiredInt int64) {
	testing.SetRealm(adminRealm)

	foo.Approve(cross, poolAddr, amount1DesiredInt)

	ufmt.Println("[INFO] Minting initial position with native coin")

	// amount0DesiredInt is 0 if none native coin is sent
	if amount0DesiredInt > 0 {
		wugnot.Approve(cross, poolAddr, amount0DesiredInt)
		wugnot.Approve(cross, positionAddr, amount0DesiredInt)

		// Send coins to pool contract
		sendCoins := chain.Coins{{"ugnot", amount0DesiredInt}}

		currentBanker := banker.NewBanker(banker.BankerTypeRealmSend)
		currentBanker.SendCoins(adminAddr, positionAddr, sendCoins)

		// Set origin send to the same coins as sent to the pool contract
		testing.SetOriginSend(sendCoins)

		ufmt.Printf("[INFO] Origin send ugnot amount: %d\n", amount0DesiredInt)
	} else {
		// Set none native coin send
		testing.SetOriginSend(chain.Coins{})
	}

	amount0Desired := ufmt.Sprintf("%d", amount0DesiredInt)
	amount1Desired := ufmt.Sprintf("%d", amount1DesiredInt)
	amount0Min := "0"
	amount1Min := "0"

	ufmt.Println("[INFO] Increasing position liquidity")
	ufmt.Printf("[INFO] Amount0 desired: %s\n", amount0Desired)
	ufmt.Printf("[INFO] Amount1 desired: %s\n", amount1Desired)
	ufmt.Printf("[INFO] Amount0 min: %s\n", amount0Min)
	ufmt.Printf("[INFO] Amount1 min: %s\n", amount1Min)

	ufmt.Println("[INFO] Increasing position liquidity")
	_, liquidity, amount0, amount1, _ := position.IncreaseLiquidity(
		cross,
		1,
		amount0Desired,
		amount1Desired,
		amount0Min,
		amount1Min,
		9999999999,
	)

	ufmt.Printf("[EXPECTED] Added liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 added should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 added should be %s\n", amount1)
}

func checkBalanceChanges(callback func()) {
	currentBanker := banker.NewBanker(banker.BankerTypeReadonly)
	gnotBalanceBefore := currentBanker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotBalanceBefore := wugnot.BalanceOf(adminAddr)
	fooBalanceBefore := foo.BalanceOf(adminAddr)

	callback()

	currentBanker = banker.NewBanker(banker.BankerTypeReadonly)
	gnotBalanceAfter := currentBanker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotBalanceAfter := wugnot.BalanceOf(adminAddr)
	fooBalanceAfter := foo.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] GNOT balance changed: %d\n", gnotBalanceAfter-gnotBalanceBefore)
	ufmt.Printf("[EXPECTED] WUGNOT balance changed: %d\n", wugnotBalanceAfter-wugnotBalanceBefore)
	ufmt.Printf("[EXPECTED] FOO balance changed: %d\n", fooBalanceAfter-fooBalanceBefore)
}

// Output:
// [SCENARIO] 1. Initialize pool with tick 100
// [INFO] GNOT balance of admin 100000000
// [INFO] Creating pool at tick 100
// [INFO] Pool path gno.land/r/gnoland/wugnot:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 2. Mint initial position (-12000~0)
// [INFO] Minting initial position with native coin
// [INFO] Input token0 path: gnot
// [INFO] Input token1 path: gno.land/r/onbloc/foo
// [INFO] Min tick: -12000
// [INFO] Max tick: 0
// [INFO] Amount0 desired: 0
// [INFO] Amount1 desired: 50000000
// [INFO] Amount0 min: 0
// [INFO] Amount1 min: 0
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 110822504
// [EXPECTED] Amount0 should be 0
// [EXPECTED] Amount1 should be 50000000
// [EXPECTED] GNOT balance changed: 0
// [EXPECTED] WUGNOT balance changed: 0
// [EXPECTED] FOO balance changed: -50000000
//
// [SCENARIO] 3. Increase position liquidity
// [INFO] Minting initial position with native coin
// [INFO] Origin send ugnot amount: 50000000
// [INFO] Increasing position liquidity
// [INFO] Amount0 desired: 50000000
// [INFO] Amount1 desired: 50000000
// [INFO] Amount0 min: 0
// [INFO] Amount1 min: 0
// [INFO] Increasing position liquidity
// [EXPECTED] Added liquidity should be 110822504
// [EXPECTED] Amount0 added should be 0
// [EXPECTED] Amount1 added should be 50000000
// [EXPECTED] GNOT balance changed: 0
// [EXPECTED] WUGNOT balance changed: 0
// [EXPECTED] FOO balance changed: -50000000
//
// [SCENARIO] 4. Increase position liquidity with zero native coin
// [INFO] Minting initial position with native coin
// [INFO] Increasing position liquidity
// [INFO] Amount0 desired: 0
// [INFO] Amount1 desired: 50000000
// [INFO] Amount0 min: 0
// [INFO] Amount1 min: 0
// [INFO] Increasing position liquidity
// [EXPECTED] Added liquidity should be 110822504
// [EXPECTED] Amount0 added should be 0
// [EXPECTED] Amount1 added should be 50000000
// [EXPECTED] GNOT balance changed: 0
// [EXPECTED] WUGNOT balance changed: 0
// [EXPECTED] FOO balance changed: -50000000
