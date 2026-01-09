package main

import (
	"testing"
	"time"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	min_tick    int32 = -887220
	max_tick    int32 = 887220
	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806

	positionId uint64 = 1
)

const (
	FEE_MEDIUM uint32 = 3000
)

func main() {
	println("[SCENARIO] 1. Initialize")
	println("[SCENARIO] 1.1. Initialize Setup")
	initializeSetup()
	println()

	println("[SCENARIO] 1.2. Create Pool")
	createPool()
	println()

	println("[SCENARIO] 1.3. Mint Position")
	mintPosition()
	println()

	println("[SCENARIO] 1.4 ExactIn Swap Route for fee accumulation")
	exactInSwapRoute()
	println()

	println("[SCENARIO] 2. Position Getter Methods")

	println("[SCENARIO] 2.1. GetPositionCount")
	getPositionCount()
	println()

	println("[SCENARIO] 2.2. GetPositionIDs")
	getPositionIDs()
	println()

	println("[SCENARIO] 2.3. GetPosition")
	getPosition()
	println()

	println("[SCENARIO] 2.4. IsBurned")
	isBurned()
	println()

	println("[SCENARIO] 2.5. IsInRange")
	isInRange()
	println()

	println("[SCENARIO] 2.6. GetPositionTokenBalances")
	getPositionTokenBalances()
	println()

	println("[SCENARIO] 2.7. GetPositionToken0Balance")
	getPositionToken0Balance()
	println()

	println("[SCENARIO] 2.8. GetPositionToken1Balance")
	getPositionToken1Balance()
	println()

	println("[SCENARIO] 2.9. GetPositionFeeGrowthInside0LastX128")
	getPositionFeeGrowthInside0LastX128()
	println()

	println("[SCENARIO] 2.10. GetPositionFeeGrowthInside1LastX128")
	getPositionFeeGrowthInside1LastX128()
	println()

	println("[SCENARIO] 2.11. GetPositionFeeGrowthInsideLastX128")
	getPositionFeeGrowthInsideLastX128()
	println()

	println("[SCENARIO] 2.12. GetPositionLiquidity")
	getPositionLiquidity()
	println()

	println("[SCENARIO] 2.13. GetPositionOperator")
	getPositionOperator()
	println()

	println("[SCENARIO] 2.14. GetPositionPoolKey")
	getPositionPoolKey()
	println()

	println("[SCENARIO] 2.15. GetPositionTickLower")
	getPositionTickLower()
	println()

	println("[SCENARIO] 2.16. GetPositionTickUpper")
	getPositionTickUpper()
	println()

	println("[SCENARIO] 2.17. GetPositionTicks")
	getPositionTicks()
	println()

	println("[SCENARIO] 2.18. GetPositionTokensOwed0")
	getPositionTokensOwed0()
	println()

	println("[SCENARIO] 2.19. GetPositionTokensOwed1")
	getPositionTokensOwed1()
	println()

	println("[SCENARIO] 2.20. GetPositionTokensOwed")
	getPositionTokensOwed()
	println()

	println("[SCENARIO] 2.21. GetUnclaimedFee")
	getUnclaimedFee()
	println()

	println("[SCENARIO] 2.22. GetPositionOwner")
	getPositionOwner()
	println()
}

func initializeSetup() {
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
}

func createPool() {
	println("[INFO] Creating bar-foo pool (fee: 3000)")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for pool operations")
	foo.Approve(cross, poolAddr, max_approve)
	bar.Approve(cross, poolAddr, max_approve)

	println("[INFO] Creating bar-foo pool (fee: 3000)")
	pl.CreatePool(cross, barPath, fooPath, 3000, "79228162514264337593543950336") // encodePriceSqrt(1, 1)
}

func mintPosition() {
	println("[INFO] Minting position in bar-foo pool")
	testing.SetRealm(adminRealm)

	tokenId, liquidity, amount0, amount1 := pn.Mint(cross, barPath, fooPath, 3000, min_tick, max_tick, "100000000", "100000000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	positionId = tokenId

	ufmt.Printf("[EXPECTED] minted position tokenId: %d\n", tokenId)
	println("[EXPECTED] minted position liquidity:", liquidity)
	println("[EXPECTED] minted position amount0:", amount0)
	println("[EXPECTED] minted position amount1:", amount1)
}

func exactInSwapRoute() {
	println("[INFO] Executing ExactIn swap for fee accumulation")
	testing.SetRealm(adminRealm)

	bar.Approve(cross, routerAddr, max_approve)
	foo.Approve(cross, routerAddr, max_approve)

	poolToken0Before := bar.BalanceOf(poolAddr)
	poolToken1Before := foo.BalanceOf(poolAddr)
	user1Token0Before := bar.BalanceOf(adminAddr)
	user1Token1Before := foo.BalanceOf(adminAddr)
	protocolFeeToken0Before := bar.BalanceOf(protocolFeeAddr)
	protocolFeeToken1Before := foo.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		fooPath,   // inputToken
		barPath,   // outputToken
		"1000000", // amountSpecified
		"gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:3000", // strRouteArr
		"100", // quoteArr
		"1",   // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	poolToken0After := bar.BalanceOf(poolAddr)
	poolToken1After := foo.BalanceOf(poolAddr)
	user1Token0After := bar.BalanceOf(adminAddr)
	user1Token1After := foo.BalanceOf(adminAddr)
	protocolFeeToken0After := bar.BalanceOf(protocolFeeAddr)
	protocolFeeToken1After := foo.BalanceOf(protocolFeeAddr)

	println("[EXPECTED] amountIn:", amountIn)
	println("[EXPECTED] amountOut:", amountOut)
	println("[EXPECTED] admin bar balance change:", user1Token0After-user1Token0Before)
	println("[EXPECTED] admin foo balance change:", user1Token1After-user1Token1Before)
	println("[EXPECTED] pool bar balance change:", poolToken0After-poolToken0Before)
	println("[EXPECTED] pool foo balance change:", poolToken1After-poolToken1Before)
	println("[EXPECTED] protocol fee bar balance change:", protocolFeeToken0After-protocolFeeToken0Before)
	println("[EXPECTED] protocol fee foo balance change:", protocolFeeToken1After-protocolFeeToken1Before)
}

// Position Getter Methods Tests

func getPositionCount() {
	println("[INFO] Check GetPositionCount method")
	testing.SetRealm(adminRealm)

	positionCount := pn.GetPositionCount()
	ufmt.Printf("[EXPECTED] position count: %d\n", positionCount)
}

func getPositionIDs() {
	println("[INFO] Check GetPositionIDs method")
	testing.SetRealm(adminRealm)

	positionIDs := pn.GetPositionIDs(0, 10)
	ufmt.Printf("[EXPECTED] position IDs count: %d\n", len(positionIDs))
	for i, id := range positionIDs {
		ufmt.Printf("[EXPECTED] position ID[%d]: %d\n", i, id)
	}
}

func getPosition() {
	println("[INFO] Check GetPosition method")
	testing.SetRealm(adminRealm)

	position, err := pn.GetPosition(positionId)
	if err != nil {
		println("[EXPECTED] GetPosition error:", err.Error())
	} else {
		println("[EXPECTED] position poolKey:", position.PoolKey())
		ufmt.Printf("[EXPECTED] position tickLower: %d\n", position.TickLower())
		ufmt.Printf("[EXPECTED] position tickUpper: %d\n", position.TickUpper())
		println("[EXPECTED] position liquidity:", position.Liquidity().ToString())
		println("[EXPECTED] position feeGrowthInside0LastX128:", position.FeeGrowthInside0LastX128().ToString())
		println("[EXPECTED] position feeGrowthInside1LastX128:", position.FeeGrowthInside1LastX128().ToString())
		println("[EXPECTED] position tokensOwed0:", position.TokensOwed0().ToString())
		println("[EXPECTED] position tokensOwed1:", position.TokensOwed1().ToString())
	}
}

func isBurned() {
	println("[INFO] Check IsBurned method")
	testing.SetRealm(adminRealm)

	burned := pn.IsBurned(positionId)
	ufmt.Printf("[EXPECTED] position %d is burned: %t\n", positionId, burned)
}

func isInRange() {
	println("[INFO] Check IsInRange method")
	testing.SetRealm(adminRealm)

	inRange := pn.IsInRange(positionId)
	ufmt.Printf("[EXPECTED] position %d is in range: %t\n", positionId, inRange)
}

func getPositionTokenBalances() {
	println("[INFO] Check GetPositionTokenBalances method")
	testing.SetRealm(adminRealm)

	balance0, balance1 := pn.GetPositionTokenBalances(positionId)
	println("[EXPECTED] position token0 balance:", balance0)
	println("[EXPECTED] position token1 balance:", balance1)
}

func getPositionToken0Balance() {
	println("[INFO] Check GetPositionToken0Balance method")
	testing.SetRealm(adminRealm)

	balance0 := pn.GetPositionToken0Balance(positionId)
	println("[EXPECTED] position token0 balance:", balance0.ToString())
}

func getPositionToken1Balance() {
	println("[INFO] Check GetPositionToken1Balance method")
	testing.SetRealm(adminRealm)

	balance1 := pn.GetPositionToken1Balance(positionId)
	println("[EXPECTED] position token1 balance:", balance1.ToString())
}

func getPositionFeeGrowthInside0LastX128() {
	println("[INFO] Check GetPositionFeeGrowthInside0LastX128 method")
	testing.SetRealm(adminRealm)

	feeGrowth := pn.GetPositionFeeGrowthInside0LastX128(positionId)
	println("[EXPECTED] position feeGrowthInside0LastX128:", feeGrowth.ToString())
}

func getPositionFeeGrowthInside1LastX128() {
	println("[INFO] Check GetPositionFeeGrowthInside1LastX128 method")
	testing.SetRealm(adminRealm)

	feeGrowth := pn.GetPositionFeeGrowthInside1LastX128(positionId)
	println("[EXPECTED] position feeGrowthInside1LastX128:", feeGrowth.ToString())
}

func getPositionFeeGrowthInsideLastX128() {
	println("[INFO] Check GetPositionFeeGrowthInsideLastX128 method")
	testing.SetRealm(adminRealm)

	feeGrowth0, feeGrowth1 := pn.GetPositionFeeGrowthInsideLastX128(positionId)
	println("[EXPECTED] position feeGrowthInside0LastX128:", feeGrowth0.ToString())
	println("[EXPECTED] position feeGrowthInside1LastX128:", feeGrowth1.ToString())
}

func getPositionLiquidity() {
	println("[INFO] Check GetPositionLiquidity method")
	testing.SetRealm(adminRealm)

	liquidity := pn.GetPositionLiquidity(positionId)
	println("[EXPECTED] position liquidity:", liquidity.ToString())
}

func getPositionOperator() {
	println("[INFO] Check GetPositionOperator method")
	testing.SetRealm(adminRealm)

	operator := pn.GetPositionOperator(positionId)
	println("[EXPECTED] position operator:", operator.String())
}

func getPositionPoolKey() {
	println("[INFO] Check GetPositionPoolKey method")
	testing.SetRealm(adminRealm)

	poolKey := pn.GetPositionPoolKey(positionId)
	println("[EXPECTED] position poolKey:", poolKey)
}

func getPositionTickLower() {
	println("[INFO] Check GetPositionTickLower method")
	testing.SetRealm(adminRealm)

	tickLower := pn.GetPositionTickLower(positionId)
	ufmt.Printf("[EXPECTED] position tickLower: %d\n", tickLower)
}

func getPositionTickUpper() {
	println("[INFO] Check GetPositionTickUpper method")
	testing.SetRealm(adminRealm)

	tickUpper := pn.GetPositionTickUpper(positionId)
	ufmt.Printf("[EXPECTED] position tickUpper: %d\n", tickUpper)
}

func getPositionTicks() {
	println("[INFO] Check GetPositionTicks method")
	testing.SetRealm(adminRealm)

	tickLower, tickUpper := pn.GetPositionTicks(positionId)
	ufmt.Printf("[EXPECTED] position tickLower: %d\n", tickLower)
	ufmt.Printf("[EXPECTED] position tickUpper: %d\n", tickUpper)
}

func getPositionTokensOwed0() {
	println("[INFO] Check GetPositionTokensOwed0 method")
	testing.SetRealm(adminRealm)

	tokensOwed0 := pn.GetPositionTokensOwed0(positionId)
	println("[EXPECTED] position tokensOwed0:", tokensOwed0.ToString())
}

func getPositionTokensOwed1() {
	println("[INFO] Check GetPositionTokensOwed1 method")
	testing.SetRealm(adminRealm)

	tokensOwed1 := pn.GetPositionTokensOwed1(positionId)
	println("[EXPECTED] position tokensOwed1:", tokensOwed1.ToString())
}

func getPositionTokensOwed() {
	println("[INFO] Check GetPositionTokensOwed method")
	testing.SetRealm(adminRealm)

	tokensOwed0, tokensOwed1 := pn.GetPositionTokensOwed(positionId)
	println("[EXPECTED] position tokensOwed0:", tokensOwed0.ToString())
	println("[EXPECTED] position tokensOwed1:", tokensOwed1.ToString())
}

func getUnclaimedFee() {
	println("[INFO] Check GetUnclaimedFee method")
	testing.SetRealm(adminRealm)

	unclaimedFee0, unclaimedFee1 := pn.GetUnclaimedFee(positionId)
	println("[EXPECTED] position unclaimedFee0:", unclaimedFee0.ToString())
	println("[EXPECTED] position unclaimedFee1:", unclaimedFee1.ToString())
}

func getPositionOwner() {
	println("[INFO] Check GetPositionOwner method")
	testing.SetRealm(adminRealm)

	owner := pn.GetPositionOwner(positionId)
	println("[EXPECTED] position owner:", owner.String())
}

// Output:
// [SCENARIO] 1. Initialize
// [SCENARIO] 1.1. Initialize Setup
//
// [SCENARIO] 1.2. Create Pool
// [INFO] Creating bar-foo pool (fee: 3000)
// [INFO] Approving tokens for pool operations
// [INFO] Creating bar-foo pool (fee: 3000)
//
// [SCENARIO] 1.3. Mint Position
// [INFO] Minting position in bar-foo pool
// [EXPECTED] minted position tokenId: 1
// [EXPECTED] minted position liquidity: 100000000
// [EXPECTED] minted position amount0: 100000000
// [EXPECTED] minted position amount1: 100000000
//
// [SCENARIO] 1.4 ExactIn Swap Route for fee accumulation
// [INFO] Executing ExactIn swap for fee accumulation
// [EXPECTED] amountIn: 1000000
// [EXPECTED] amountOut: -985678
// [EXPECTED] admin bar balance change: 985678
// [EXPECTED] admin foo balance change: -1000000
// [EXPECTED] pool bar balance change: -987158
// [EXPECTED] pool foo balance change: 1000000
// [EXPECTED] protocol fee bar balance change: 1480
// [EXPECTED] protocol fee foo balance change: 0
//
// [SCENARIO] 2. Position Getter Methods
// [SCENARIO] 2.1. GetPositionCount
// [INFO] Check GetPositionCount method
// [EXPECTED] position count: 1
//
// [SCENARIO] 2.2. GetPositionIDs
// [INFO] Check GetPositionIDs method
// [EXPECTED] position IDs count: 1
// [EXPECTED] position ID[0]: 1
//
// [SCENARIO] 2.3. GetPosition
// [INFO] Check GetPosition method
// [EXPECTED] position poolKey: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
// [EXPECTED] position tickLower: -887220
// [EXPECTED] position tickUpper: 887220
// [EXPECTED] position liquidity: 100000000
// [EXPECTED] position feeGrowthInside0LastX128: 0
// [EXPECTED] position feeGrowthInside1LastX128: 0
// [EXPECTED] position tokensOwed0: 0
// [EXPECTED] position tokensOwed1: 0
//
// [SCENARIO] 2.4. IsBurned
// [INFO] Check IsBurned method
// [EXPECTED] position 1 is burned: false
//
// [SCENARIO] 2.5. IsInRange
// [INFO] Check IsInRange method
// [EXPECTED] position 1 is in range: true
//
// [SCENARIO] 2.6. GetPositionTokenBalances
// [INFO] Check GetPositionTokenBalances method
// [EXPECTED] position token0 balance: 100000000
// [EXPECTED] position token1 balance: 100000000
//
// [SCENARIO] 2.7. GetPositionToken0Balance
// [INFO] Check GetPositionToken0Balance method
// [EXPECTED] position token0 balance: 100000000
//
// [SCENARIO] 2.8. GetPositionToken1Balance
// [INFO] Check GetPositionToken1Balance method
// [EXPECTED] position token1 balance: 100000000
//
// [SCENARIO] 2.9. GetPositionFeeGrowthInside0LastX128
// [INFO] Check GetPositionFeeGrowthInside0LastX128 method
// [EXPECTED] position feeGrowthInside0LastX128: 0
//
// [SCENARIO] 2.10. GetPositionFeeGrowthInside1LastX128
// [INFO] Check GetPositionFeeGrowthInside1LastX128 method
// [EXPECTED] position feeGrowthInside1LastX128: 0
//
// [SCENARIO] 2.11. GetPositionFeeGrowthInsideLastX128
// [INFO] Check GetPositionFeeGrowthInsideLastX128 method
// [EXPECTED] position feeGrowthInside0LastX128: 0
// [EXPECTED] position feeGrowthInside1LastX128: 0
//
// [SCENARIO] 2.12. GetPositionLiquidity
// [INFO] Check GetPositionLiquidity method
// [EXPECTED] position liquidity: 100000000
//
// [SCENARIO] 2.13. GetPositionOperator
// [INFO] Check GetPositionOperator method
// [EXPECTED] position operator:
//
// [SCENARIO] 2.14. GetPositionPoolKey
// [INFO] Check GetPositionPoolKey method
// [EXPECTED] position poolKey: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
//
// [SCENARIO] 2.15. GetPositionTickLower
// [INFO] Check GetPositionTickLower method
// [EXPECTED] position tickLower: -887220
//
// [SCENARIO] 2.16. GetPositionTickUpper
// [INFO] Check GetPositionTickUpper method
// [EXPECTED] position tickUpper: 887220
//
// [SCENARIO] 2.17. GetPositionTicks
// [INFO] Check GetPositionTicks method
// [EXPECTED] position tickLower: -887220
// [EXPECTED] position tickUpper: 887220
//
// [SCENARIO] 2.18. GetPositionTokensOwed0
// [INFO] Check GetPositionTokensOwed0 method
// [EXPECTED] position tokensOwed0: 0
//
// [SCENARIO] 2.19. GetPositionTokensOwed1
// [INFO] Check GetPositionTokensOwed1 method
// [EXPECTED] position tokensOwed1: 0
//
// [SCENARIO] 2.20. GetPositionTokensOwed
// [INFO] Check GetPositionTokensOwed method
// [EXPECTED] position tokensOwed0: 0
// [EXPECTED] position tokensOwed1: 0
//
// [SCENARIO] 2.21. GetUnclaimedFee
// [INFO] Check GetUnclaimedFee method
// [EXPECTED] position unclaimedFee0: 0
// [EXPECTED] position unclaimedFee1: 2999
//
// [SCENARIO] 2.22. GetPositionOwner
// [INFO] Check GetPositionOwner method
// [EXPECTED] position owner: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
