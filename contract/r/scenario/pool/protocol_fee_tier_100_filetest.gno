// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var t *testing.T

const (
	fee100          uint32 = 100
	maxApprove      int64  = 9223372036854775806
	poolCreationFee int64  = 100_000_000
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	rouRealm        = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
)

var (
	liquidityAmount = "1000000000"
	swapAmount      = "100000000"
	MIN_PRICE       = "4295128740"
	MAX_PRICE       = "1461446703485210103287273052203988822378723970341"
)

var poolPath string

func main() {
	println("[SCENARIO] Protocol Fee Calculation - Fee Tier 100 (0.01%)")
	println("[INFO] Fee tier: 100 (0.01%)")
	println("[INFO] Protocol fee setting: 10/10 (10% of swap fee)")
	println()

	setupProtocolFee()
	setupPool()
	testMintPosition()
	testSwapAndCheckFees()
	printSummary()
}

func setupProtocolFee() {
	println("[INFO] Setting protocol fee to 10/10")
	testing.SetRealm(adminRealm)
	pool.SetFeeProtocol(cross, 10, 10)
}

func setupPool() {
	println("[INFO] Creating pool with fee tier 100")
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	poolPath = pool.GetPoolPath(barPath, fooPath, fee100)
	println("[INFO] Pool created:", poolPath)

	initFee0 := pool.GetProtocolFeesToken0(poolPath)
	initFee1 := pool.GetProtocolFeesToken1(poolPath)
	println("[INFO] Initial protocol fees - token0:", initFee0, "token1:", initFee1)
	println()
}

func testMintPosition() {
	println("[SCENARIO] 1. Mint liquidity position")
	testing.SetRealm(posRealm)
	mint0, mint1 := pool.Mint(
		cross,
		barPath,
		fooPath,
		fee100,
		-6000,
		6000,
		liquidityAmount,
		adminAddr,
	)
	println("[EXPECTED] Minted amounts - token0:", mint0, "token1:", mint1)
	println()
}

func testSwapAndCheckFees() {
	// Swap 1: token0 -> token1
	println("[SCENARIO] 2. Swap token0 -> token1")
	testing.SetRealm(rouRealm)
	swap0, swap1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee100,
		adminAddr,
		true,
		swapAmount,
		MIN_PRICE,
		adminAddr,
		swapCallback,
	)
	println("[EXPECTED] Swap result - amount0:", swap0, "amount1:", swap1)

	fee0 := pool.GetProtocolFeesToken0(poolPath)
	fee1 := pool.GetProtocolFeesToken1(poolPath)
	println("[EXPECTED] Protocol fees after swap1 - token0:", fee0, "token1:", fee1)
	println()

	// Swap 2: token1 -> token0
	println("[SCENARIO] 3. Swap token1 -> token0")
	swap0_2, swap1_2 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee100,
		adminAddr,
		false,
		swapAmount,
		MAX_PRICE,
		adminAddr,
		swapCallback,
	)
	println("[EXPECTED] Swap result - amount0:", swap0_2, "amount1:", swap1_2)

	fee0_2 := pool.GetProtocolFeesToken0(poolPath)
	fee1_2 := pool.GetProtocolFeesToken1(poolPath)
	println("[EXPECTED] Protocol fees after swap2 - token0:", fee0_2, "token1:", fee1_2)
	println()
}

func printSummary() {
	println("[SCENARIO] 4. Protocol Fee Summary")
	testing.SetRealm(adminRealm)
	finalFee0 := pool.GetProtocolFeesToken0(poolPath)
	finalFee1 := pool.GetProtocolFeesToken1(poolPath)
	println("[EXPECTED] Fee tier: 100 (0.01%)")
	println("[EXPECTED] Total protocol fee token0:", finalFee0)
	println("[EXPECTED] Total protocol fee token1:", finalFee1)
	println()
	println("[INFO] Scenario completed")
}

func swapCallback(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
	testing.SetRealm(adminRealm)

	const wugnotPath = "gno.land/r/gnoland/wugnot"
	const ugnotDenom = "ugnot"

	if amount0Delta > 0 {
		if barPath == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Delta}})
			wugnot.Deposit(cross)
		}
		common.SafeGRC20Transfer(cross, barPath, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		if fooPath == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Delta}})
			wugnot.Deposit(cross)
		}
		common.SafeGRC20Transfer(cross, fooPath, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] Protocol Fee Calculation - Fee Tier 100 (0.01%)
// [INFO] Fee tier: 100 (0.01%)
// [INFO] Protocol fee setting: 10/10 (10% of swap fee)
//
// [INFO] Setting protocol fee to 10/10
// [INFO] Creating pool with fee tier 100
// [INFO] Pool created: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:100
// [INFO] Initial protocol fees - token0: 0 token1: 0
//
// [SCENARIO] 1. Mint liquidity position
// [EXPECTED] Minted amounts - token0: 259170668 token1: 259170668
//
// [SCENARIO] 2. Swap token0 -> token1
// [EXPECTED] Swap result - amount0: 100000000 amount1: -90900816
// [EXPECTED] Protocol fees after swap1 - token0: 996 token1: 0
//
// [SCENARIO] 3. Swap token1 -> token0
// [EXPECTED] Swap result - amount0: -108997293 amount1: 100000000
// [EXPECTED] Protocol fees after swap2 - token0: 996 token1: 996
//
// [SCENARIO] 4. Protocol Fee Summary
// [EXPECTED] Fee tier: 100 (0.01%)
// [EXPECTED] Total protocol fee token0: 996
// [EXPECTED] Total protocol fee token1: 996
//
// [INFO] Scenario completed
