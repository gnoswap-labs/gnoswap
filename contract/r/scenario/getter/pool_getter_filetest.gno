package main

import (
	"encoding/base64"
	"strconv"
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

	poolPath    string
	positionKey string
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

	println("[SCENARIO] 1.4 ExactIn Swap Route for tick changes")
	exactInSwapRoute()
	println()

	println("[SCENARIO] 2. Getter Methods")

	println("[SCENARIO] 2.1. GetPoolCount")
	getPoolCount()
	println()

	println("[SCENARIO] 2.2. GetPoolPaths")
	getPoolPaths()
	println()

	println("[SCENARIO] 2.3. ExistsPoolPath")
	existsPoolPath()
	println()

	println("[SCENARIO] 2.4. GetBalances")
	getBalances()
	println()

	println("[SCENARIO] 2.5. GetBalanceToken0")
	getBalanceToken0()
	println()

	println("[SCENARIO] 2.6. GetBalanceToken1")
	getBalanceToken1()
	println()

	println("[SCENARIO] 2.7. GetFee")
	getFee()
	println()

	println("[SCENARIO] 2.8. GetFeeAmountTickSpacings")
	getFeeAmountTickSpacings()
	println()

	println("[SCENARIO] 2.9. GetFeeAmountTickSpacing")
	getFeeAmountTickSpacing()
	println()

	println("[SCENARIO] 2.10. GetFeeGrowthGlobal0X128")
	getFeeGrowthGlobal0X128()
	println()

	println("[SCENARIO] 2.11. GetFeeGrowthGlobal1X128")
	getFeeGrowthGlobal1X128()
	println()

	println("[SCENARIO] 2.12. GetFeeGrowthGlobalX128")
	getFeeGrowthGlobalX128()
	println()

	println("[SCENARIO] 2.13. GetFeeGrowthGlobals")
	getFeeGrowthGlobals()
	println()

	println("[SCENARIO] 2.14. GetLiquidity")
	getLiquidity()
	println()

	println("[SCENARIO] 2.15. GetMaxLiquidityPerTick")
	getMaxLiquidityPerTick()
	println()

	println("[SCENARIO] 2.16. GetObservation")
	getObservation()
	println()

	println("[SCENARIO] 2.17. GetPoolCreationFee")
	getPoolCreationFee()
	println()

	println("[SCENARIO] 2.18. GetPositionFeeGrowthInside0LastX128")
	getPositionFeeGrowthInside0LastX128()
	println()

	println("[SCENARIO] 2.19. GetPositionFeeGrowthInside1LastX128")
	getPositionFeeGrowthInside1LastX128()
	println()

	println("[SCENARIO] 2.20. GetPositionFeeGrowthInsideLastX128")
	getPositionFeeGrowthInsideLastX128()
	println()

	println("[SCENARIO] 2.21. GetPositionFeeGrowthInsideLasts")
	getPositionFeeGrowthInsideLasts()
	println()

	println("[SCENARIO] 2.22. GetPoolPositionCount")
	getPoolPositionCount()
	println()

	println("[SCENARIO] 2.23. GetPoolPositionKeys")
	getPoolPositionKeys()
	println()

	println("[SCENARIO] 2.24. GetPositionLiquidity")
	getPositionLiquidity()
	println()

	println("[SCENARIO] 2.25. GetPositionTokensOwed0")
	getPositionTokensOwed0()
	println()

	println("[SCENARIO] 2.26. GetPositionTokensOwed1")
	getPositionTokensOwed1()
	println()

	println("[SCENARIO] 2.27. GetPositionTokensOwed")
	getPositionTokensOwed()
	println()

	println("[SCENARIO] 2.28. GetProtocolFeesToken0")
	getProtocolFeesToken0()
	println()

	println("[SCENARIO] 2.29. GetProtocolFeesToken1")
	getProtocolFeesToken1()
	println()

	println("[SCENARIO] 2.30. GetProtocolFeesTokens")
	getProtocolFeesTokens()
	println()

	println("[SCENARIO] 2.31. GetSlot0FeeProtocol")
	getSlot0FeeProtocol()
	println()

	println("[SCENARIO] 2.32. GetSlot0SqrtPriceX96")
	getSlot0SqrtPriceX96()
	println()

	println("[SCENARIO] 2.33. GetSlot0Tick")
	getSlot0Tick()
	println()

	println("[SCENARIO] 2.34. GetSlot0Unlocked")
	getSlot0Unlocked()
	println()

	println("[SCENARIO] 2.35. GetTickCumulativeOutside")
	getTickCumulativeOutside()
	println()

	println("[SCENARIO] 2.36. GetTickFeeGrowthOutside0X128")
	getTickFeeGrowthOutside0X128()
	println()

	println("[SCENARIO] 2.37. GetTickFeeGrowthOutside1X128")
	getTickFeeGrowthOutside1X128()
	println()

	println("[SCENARIO] 2.38. GetTickFeeGrowthOutsideX128")
	getTickFeeGrowthOutsideX128()
	println()

	println("[SCENARIO] 2.39. GetTickFeeGrowthOutsides")
	getTickFeeGrowthOutsides()
	println()

	println("[SCENARIO] 2.40. GetTickInitialized")
	getTickInitialized()
	println()

	println("[SCENARIO] 2.41. GetInitializedTicksInRange")
	getInitializedTicksInRange()
	println()

	println("[SCENARIO] 2.42. GetTickLiquidityGross")
	getTickLiquidityGross()
	println()

	println("[SCENARIO] 2.43. GetTickLiquidityNet")
	getTickLiquidityNet()
	println()

	println("[SCENARIO] 2.44. GetTickSecondsOutside")
	getTickSecondsOutside()
	println()

	println("[SCENARIO] 2.45. GetTickSecondsPerLiquidityOutsideX128")
	getTickSecondsPerLiquidityOutsideX128()
	println()

	println("[SCENARIO] 2.46. GetTickSpacing")
	getTickSpacing()
	println()

	println("[SCENARIO] 2.47. GetToken0Path")
	getToken0Path()
	println()

	println("[SCENARIO] 2.48. GetToken1Path")
	getToken1Path()
	println()

	println("[SCENARIO] 2.49. GetWithdrawalFee")
	getWithdrawalFee()
	println()

	println("[SCENARIO] 2.50. GetTWAP")
	getTWAP()
	println()

	println("[SCENARIO] 2.51. GetPool")
	getPool()
	println()

	println("[SCENARIO] 2.52. GetTickInfo")
	getTickInfo()
	println()

	println("[SCENARIO] 2.53. GetTickBitmaps")
	getTickBitmaps()
	println()

	println("[SCENARIO] 2.54. GetPosition")
	getPosition()
	println()

	println("[SCENARIO] 2.55. GetObservationState")
	getObservationState()
	println()
}

func initializeSetup() {
	println("[INFO] Starting scenario: Pool Getter Methods Test")

	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())

	// Set poolPath for later use
	poolPath = barPath + ":" + fooPath + ":3000"

	// Set positionKey for later use (base64 encoded)
	positionKeyRaw := "gno.land/r/gnoswap/position__" + strconv.Itoa(int(min_tick)) + "__" + strconv.Itoa(int(max_tick))
	positionKey = base64.StdEncoding.EncodeToString([]byte(positionKeyRaw))
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

	pn.Mint(cross, barPath, fooPath, 3000, min_tick, max_tick, "100000000", "100000000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	pool, _ := pl.GetPool(barPath, fooPath, FEE_MEDIUM)
	poolLiq := pool.Liquidity()
	println("[EXPECTED] pool liquidity:", poolLiq.ToString(), "expected: 100000000")
}

func exactInSwapRoute() {
	println("[INFO] Executing ExactIn swap")
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

// Getter Methods Tests

func getPoolCount() {
	println("[INFO] Check GetPoolCount method")
	testing.SetRealm(adminRealm)

	poolCount := pl.GetPoolCount()
	ufmt.Printf("[EXPECTED] pool count: %d\n", poolCount)
}

func getPoolPaths() {
	println("[INFO] Check GetPoolPaths method")
	testing.SetRealm(adminRealm)

	poolPaths := pl.GetPoolPaths(0, 10)
	ufmt.Printf("[EXPECTED] pool paths count: %d\n", len(poolPaths))
	for i, path := range poolPaths {
		ufmt.Printf("[EXPECTED] pool path[%d]: %s\n", i, path)
	}
}

func existsPoolPath() {
	println("[INFO] Check ExistsPoolPath method")
	testing.SetRealm(adminRealm)

	exists := pl.ExistsPoolPath(poolPath)
	ufmt.Printf("[EXPECTED] pool exists: %t\n", exists)

	notExists := pl.ExistsPoolPath("invalid:pool:path")
	ufmt.Printf("[EXPECTED] invalid pool exists: %t\n", notExists)
}

func getBalances() {
	println("[INFO] Check GetBalances method")
	testing.SetRealm(adminRealm)

	balance0, balance1 := pl.GetBalances(poolPath)
	println("[EXPECTED] balance0:", balance0)
	println("[EXPECTED] balance1:", balance1)
}

func getBalanceToken0() {
	println("[INFO] Check GetBalanceToken0 method")
	testing.SetRealm(adminRealm)

	balance0 := pl.GetBalanceToken0(poolPath)
	println("[EXPECTED] balance token0:", balance0)
}

func getBalanceToken1() {
	println("[INFO] Check GetBalanceToken1 method")
	testing.SetRealm(adminRealm)

	balance1 := pl.GetBalanceToken1(poolPath)
	println("[EXPECTED] balance token1:", balance1)
}

func getFee() {
	println("[INFO] Check GetFee method")
	testing.SetRealm(adminRealm)

	fee := pl.GetFee(poolPath)
	ufmt.Printf("[EXPECTED] fee: %d\n", fee)
}

func getFeeAmountTickSpacings() {
	println("[INFO] Check GetFeeAmountTickSpacings method")
	testing.SetRealm(adminRealm)

	feeAmountTickSpacings := pl.GetFeeAmountTickSpacings()
	for fee, tickSpacing := range feeAmountTickSpacings {
		ufmt.Printf("[EXPECTED] fee: %d, tickSpacing: %d\n", fee, tickSpacing)
	}
}

func getFeeAmountTickSpacing() {
	println("[INFO] Check GetFeeAmountTickSpacing method")
	testing.SetRealm(adminRealm)

	tickSpacing := pl.GetFeeAmountTickSpacing(FEE_MEDIUM)
	ufmt.Printf("[EXPECTED] tickSpacing for fee 3000: %d\n", tickSpacing)
}

func getFeeGrowthGlobal0X128() {
	println("[INFO] Check GetFeeGrowthGlobal0X128 method")
	testing.SetRealm(adminRealm)

	feeGrowth := pl.GetFeeGrowthGlobal0X128(poolPath)
	println("[EXPECTED] feeGrowthGlobal0X128:", feeGrowth)
}

func getFeeGrowthGlobal1X128() {
	println("[INFO] Check GetFeeGrowthGlobal1X128 method")
	testing.SetRealm(adminRealm)

	feeGrowth := pl.GetFeeGrowthGlobal1X128(poolPath)
	println("[EXPECTED] feeGrowthGlobal1X128:", feeGrowth)
}

func getFeeGrowthGlobalX128() {
	println("[INFO] Check GetFeeGrowthGlobalX128 method")
	testing.SetRealm(adminRealm)

	feeGrowth0, feeGrowth1 := pl.GetFeeGrowthGlobalX128(poolPath)
	println("[EXPECTED] feeGrowthGlobal0X128:", feeGrowth0.ToString())
	println("[EXPECTED] feeGrowthGlobal1X128:", feeGrowth1.ToString())
}

func getFeeGrowthGlobals() {
	println("[INFO] Check GetFeeGrowthGlobals method")
	testing.SetRealm(adminRealm)

	feeGrowth0, feeGrowth1 := pl.GetFeeGrowthGlobals(poolPath)
	println("[EXPECTED] feeGrowthGlobal0:", feeGrowth0)
	println("[EXPECTED] feeGrowthGlobal1:", feeGrowth1)
}

func getLiquidity() {
	println("[INFO] Check GetLiquidity method")
	testing.SetRealm(adminRealm)

	liquidity := pl.GetLiquidity(poolPath)
	println("[EXPECTED] liquidity:", liquidity)
}

func getMaxLiquidityPerTick() {
	println("[INFO] Check GetMaxLiquidityPerTick method")
	testing.SetRealm(adminRealm)

	maxLiquidityPerTick := pl.GetMaxLiquidityPerTick(poolPath)
	println("[EXPECTED] maxLiquidityPerTick:", maxLiquidityPerTick)
}

func getObservation() {
	println("[INFO] Check GetObservation method")
	testing.SetRealm(adminRealm)

	tickCumulative, liquidityCumulative, secondsPerLiquidityCumulativeX128, blockTimestamp := pl.GetObservation(poolPath, 0)
	ufmt.Printf("[EXPECTED] tickCumulative: %d\n", tickCumulative)
	println("[EXPECTED] liquidityCumulative:", liquidityCumulative)
	println("[EXPECTED] secondsPerLiquidityCumulativeX128:", secondsPerLiquidityCumulativeX128)
	ufmt.Printf("[EXPECTED] blockTimestamp: %d\n", blockTimestamp)
}

func getPoolCreationFee() {
	println("[INFO] Check GetPoolCreationFee method")
	testing.SetRealm(adminRealm)

	poolCreationFee := pl.GetPoolCreationFee()
	ufmt.Printf("[EXPECTED] poolCreationFee: %d\n", poolCreationFee)
}

func getPositionFeeGrowthInside0LastX128() {
	println("[INFO] Check GetPositionFeeGrowthInside0LastX128 method")
	testing.SetRealm(adminRealm)

	feeGrowth := pl.GetPositionFeeGrowthInside0LastX128(poolPath, positionKey)
	println("[EXPECTED] positionFeeGrowthInside0LastX128:", feeGrowth)
}

func getPositionFeeGrowthInside1LastX128() {
	println("[INFO] Check GetPositionFeeGrowthInside1LastX128 method")
	testing.SetRealm(adminRealm)

	feeGrowth := pl.GetPositionFeeGrowthInside1LastX128(poolPath, positionKey)
	println("[EXPECTED] positionFeeGrowthInside1LastX128:", feeGrowth)
}

func getPositionFeeGrowthInsideLastX128() {
	println("[INFO] Check GetPositionFeeGrowthInsideLastX128 method")
	testing.SetRealm(adminRealm)

	feeGrowth0, feeGrowth1 := pl.GetPositionFeeGrowthInsideLastX128(poolPath, positionKey)
	println("[EXPECTED] positionFeeGrowthInside0LastX128:", feeGrowth0.ToString())
	println("[EXPECTED] positionFeeGrowthInside1LastX128:", feeGrowth1.ToString())
}

func getPositionFeeGrowthInsideLasts() {
	println("[INFO] Check GetPositionFeeGrowthInsideLasts method")
	testing.SetRealm(adminRealm)

	feeGrowth0, feeGrowth1 := pl.GetPositionFeeGrowthInsideLasts(poolPath, positionKey)
	println("[EXPECTED] positionFeeGrowthInside0Last:", feeGrowth0)
	println("[EXPECTED] positionFeeGrowthInside1Last:", feeGrowth1)
}

func getPoolPositionCount() {
	println("[INFO] Check GetPoolPositionCount method")
	testing.SetRealm(adminRealm)

	positionCount := pl.GetPoolPositionCount(poolPath)
	ufmt.Printf("[EXPECTED] position count: %d\n", positionCount)
}

func getPoolPositionKeys() {
	println("[INFO] Check GetPoolPositionKeys method")
	testing.SetRealm(adminRealm)

	positionKeys := pl.GetPoolPositionKeys(poolPath, 0, 10)
	ufmt.Printf("[EXPECTED] position keys count: %d\n", len(positionKeys))
	for i, key := range positionKeys {
		ufmt.Printf("[EXPECTED] position key[%d]: %s\n", i, key)
	}
}

func getPositionLiquidity() {
	println("[INFO] Check GetPositionLiquidity method")
	testing.SetRealm(adminRealm)

	liquidity := pl.GetPositionLiquidity(poolPath, positionKey)
	println("[EXPECTED] position liquidity:", liquidity.ToString())
}

func getPositionTokensOwed0() {
	println("[INFO] Check GetPositionTokensOwed0 method")
	testing.SetRealm(adminRealm)

	tokensOwed0 := pl.GetPositionTokensOwed0(poolPath, positionKey)
	println("[EXPECTED] position tokensOwed0:", tokensOwed0)
}

func getPositionTokensOwed1() {
	println("[INFO] Check GetPositionTokensOwed1 method")
	testing.SetRealm(adminRealm)

	tokensOwed1 := pl.GetPositionTokensOwed1(poolPath, positionKey)
	println("[EXPECTED] position tokensOwed1:", tokensOwed1)
}

func getPositionTokensOwed() {
	println("[INFO] Check GetPositionTokensOwed method")
	testing.SetRealm(adminRealm)

	tokensOwed0, tokensOwed1 := pl.GetPositionTokensOwed(poolPath, positionKey)
	println("[EXPECTED] position tokensOwed0:", tokensOwed0)
	println("[EXPECTED] position tokensOwed1:", tokensOwed1)
}

func getProtocolFeesToken0() {
	println("[INFO] Check GetProtocolFeesToken0 method")
	testing.SetRealm(adminRealm)

	protocolFee0 := pl.GetProtocolFeesToken0(poolPath)
	println("[EXPECTED] protocol fee token0:", protocolFee0)
}

func getProtocolFeesToken1() {
	println("[INFO] Check GetProtocolFeesToken1 method")
	testing.SetRealm(adminRealm)

	protocolFee1 := pl.GetProtocolFeesToken1(poolPath)
	println("[EXPECTED] protocol fee token1:", protocolFee1)
}

func getProtocolFeesTokens() {
	println("[INFO] Check GetProtocolFeesTokens method")
	testing.SetRealm(adminRealm)

	protocolFee0, protocolFee1 := pl.GetProtocolFeesTokens(poolPath)
	println("[EXPECTED] protocol fee token0:", protocolFee0)
	println("[EXPECTED] protocol fee token1:", protocolFee1)
}

func getSlot0FeeProtocol() {
	println("[INFO] Check GetSlot0FeeProtocol method")
	testing.SetRealm(adminRealm)

	feeProtocol := pl.GetSlot0FeeProtocol(poolPath)
	ufmt.Printf("[EXPECTED] slot0 feeProtocol: %d\n", feeProtocol)
}

func getSlot0SqrtPriceX96() {
	println("[INFO] Check GetSlot0SqrtPriceX96 method")
	testing.SetRealm(adminRealm)

	sqrtPriceX96 := pl.GetSlot0SqrtPriceX96(poolPath)
	println("[EXPECTED] slot0 sqrtPriceX96:", sqrtPriceX96.ToString())
}

func getSlot0Tick() {
	println("[INFO] Check GetSlot0Tick method")
	testing.SetRealm(adminRealm)

	tick := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] slot0 tick: %d\n", tick)
}

func getSlot0Unlocked() {
	println("[INFO] Check GetSlot0Unlocked method")
	testing.SetRealm(adminRealm)

	unlocked := pl.GetSlot0Unlocked(poolPath)
	ufmt.Printf("[EXPECTED] slot0 unlocked: %t\n", unlocked)
}

func getTickCumulativeOutside() {
	println("[INFO] Check GetTickCumulativeOutside method")
	testing.SetRealm(adminRealm)

	tickCumulative := pl.GetTickCumulativeOutside(poolPath, min_tick)
	ufmt.Printf("[EXPECTED] tick cumulative outside at min_tick: %d\n", tickCumulative)
}

func getTickFeeGrowthOutside0X128() {
	println("[INFO] Check GetTickFeeGrowthOutside0X128 method")
	testing.SetRealm(adminRealm)

	feeGrowth := pl.GetTickFeeGrowthOutside0X128(poolPath, min_tick)
	println("[EXPECTED] tick feeGrowthOutside0X128 at min_tick:", feeGrowth)
}

func getTickFeeGrowthOutside1X128() {
	println("[INFO] Check GetTickFeeGrowthOutside1X128 method")
	testing.SetRealm(adminRealm)

	feeGrowth := pl.GetTickFeeGrowthOutside1X128(poolPath, min_tick)
	println("[EXPECTED] tick feeGrowthOutside1X128 at min_tick:", feeGrowth)
}

func getTickFeeGrowthOutsideX128() {
	println("[INFO] Check GetTickFeeGrowthOutsideX128 method")
	testing.SetRealm(adminRealm)

	feeGrowth0, feeGrowth1 := pl.GetTickFeeGrowthOutsideX128(poolPath, min_tick)
	println("[EXPECTED] tick feeGrowthOutside0X128 at min_tick:", feeGrowth0.ToString())
	println("[EXPECTED] tick feeGrowthOutside1X128 at min_tick:", feeGrowth1.ToString())
}

func getTickFeeGrowthOutsides() {
	println("[INFO] Check GetTickFeeGrowthOutsides method")
	testing.SetRealm(adminRealm)

	feeGrowth0, feeGrowth1 := pl.GetTickFeeGrowthOutsides(poolPath, min_tick)
	println("[EXPECTED] tick feeGrowthOutside0 at min_tick:", feeGrowth0)
	println("[EXPECTED] tick feeGrowthOutside1 at min_tick:", feeGrowth1)
}

func getTickInitialized() {
	println("[INFO] Check GetTickInitialized method")
	testing.SetRealm(adminRealm)

	initialized := pl.GetTickInitialized(poolPath, max_tick)
	ufmt.Printf("[EXPECTED] tick initialized at min_tick: %t\n", initialized)
}

func getInitializedTicksInRange() {
	println("[INFO] Check GetInitializedTicksInRange method")
	testing.SetRealm(adminRealm)

	initializedTicks := pl.GetInitializedTicksInRange(poolPath, min_tick, max_tick)
	ufmt.Printf("[EXPECTED] initialized ticks count: %d\n", len(initializedTicks))
	for i, tick := range initializedTicks {
		ufmt.Printf("[EXPECTED] initialized tick[%d]: %d\n", i, tick)
	}
}

func getTickLiquidityGross() {
	println("[INFO] Check GetTickLiquidityGross method")
	testing.SetRealm(adminRealm)

	liquidityGross := pl.GetTickLiquidityGross(poolPath, min_tick)
	println("[EXPECTED] tick liquidityGross at min_tick:", liquidityGross)
}

func getTickLiquidityNet() {
	println("[INFO] Check GetTickLiquidityNet method")
	testing.SetRealm(adminRealm)

	liquidityNet := pl.GetTickLiquidityNet(poolPath, min_tick)
	println("[EXPECTED] tick liquidityNet at min_tick:", liquidityNet)
}

func getTickSecondsOutside() {
	println("[INFO] Check GetTickSecondsOutside method")
	testing.SetRealm(adminRealm)

	secondsOutside := pl.GetTickSecondsOutside(poolPath, min_tick)
	ufmt.Printf("[EXPECTED] tick secondsOutside at min_tick: %d\n", secondsOutside)
}

func getTickSecondsPerLiquidityOutsideX128() {
	println("[INFO] Check GetTickSecondsPerLiquidityOutsideX128 method")
	testing.SetRealm(adminRealm)

	secondsPerLiquidity := pl.GetTickSecondsPerLiquidityOutsideX128(poolPath, min_tick)
	println("[EXPECTED] tick secondsPerLiquidityOutsideX128 at min_tick:", secondsPerLiquidity)
}

func getTickSpacing() {
	println("[INFO] Check GetTickSpacing method")
	testing.SetRealm(adminRealm)

	tickSpacing := pl.GetTickSpacing(poolPath)
	ufmt.Printf("[EXPECTED] tick spacing: %d\n", tickSpacing)
}

func getToken0Path() {
	println("[INFO] Check GetToken0Path method")
	testing.SetRealm(adminRealm)

	token0Path := pl.GetToken0Path(poolPath)
	println("[EXPECTED] token0 path:", token0Path)
}

func getToken1Path() {
	println("[INFO] Check GetToken1Path method")
	testing.SetRealm(adminRealm)

	token1Path := pl.GetToken1Path(poolPath)
	println("[EXPECTED] token1 path:", token1Path)
}

func getWithdrawalFee() {
	println("[INFO] Check GetWithdrawalFee method")
	testing.SetRealm(adminRealm)

	withdrawalFee := pl.GetWithdrawalFee()
	ufmt.Printf("[EXPECTED] withdrawal fee: %d\n", withdrawalFee)
}

func getTWAP() {
	println("[INFO] Check GetTWAP method")
	testing.SetRealm(adminRealm)

	arithmeticMeanTick, harmonicMeanLiquidity, err := pl.GetTWAP(poolPath, 0)
	if err != nil {
		println("[EXPECTED] GetTWAP error:", err.Error())
	} else {
		ufmt.Printf("[EXPECTED] arithmeticMeanTick: %d\n", arithmeticMeanTick)
		println("[EXPECTED] harmonicMeanLiquidity:", harmonicMeanLiquidity.ToString())
	}
}

func getPool() {
	println("[INFO] Check GetPool method")
	testing.SetRealm(adminRealm)

	pool, err := pl.GetPool(barPath, fooPath, FEE_MEDIUM)
	if err != nil {
		println("[EXPECTED] GetPool error:", err.Error())
	} else {
		println("[EXPECTED] pool token0Path:", pool.Token0Path())
		println("[EXPECTED] pool token1Path:", pool.Token1Path())
		ufmt.Printf("[EXPECTED] pool fee: %d\n", pool.Fee())
		println("[EXPECTED] pool liquidity:", pool.Liquidity().ToString())
	}
}

func getTickInfo() {
	println("[INFO] Check GetTickInfo method")
	testing.SetRealm(adminRealm)

	tickInfo, err := pl.GetTickInfo(poolPath, min_tick)
	if err != nil {
		println("[EXPECTED] GetTickInfo error:", err.Error())
	} else {
		println("[EXPECTED] tickInfo liquidityGross:", tickInfo.LiquidityGross().ToString())
		println("[EXPECTED] tickInfo liquidityNet:", tickInfo.LiquidityNet().ToString())
		println("[EXPECTED] tickInfo feeGrowthOutside0X128:", tickInfo.FeeGrowthOutside0X128().ToString())
		println("[EXPECTED] tickInfo feeGrowthOutside1X128:", tickInfo.FeeGrowthOutside1X128().ToString())
		ufmt.Printf("[EXPECTED] tickInfo initialized: %t\n", tickInfo.Initialized())
	}
}

func getTickBitmaps() {
	println("[INFO] Check GetTickBitmaps method")
	testing.SetRealm(adminRealm)

	// Calculate word position for min_tick with tick spacing 60
	// wordPos = tick / tickSpacing / 256
	wordPos := int16(min_tick / 60 / 256)
	tickBitmap, err := pl.GetTickBitmaps(poolPath, wordPos)
	if err != nil {
		println("[EXPECTED] GetTickBitmaps error:", err.Error())
	} else {
		println("[EXPECTED] tickBitmap at wordPos:", tickBitmap.ToString())
	}
}

func getPosition() {
	println("[INFO] Check GetPosition method")
	testing.SetRealm(adminRealm)

	position, err := pl.GetPosition(poolPath, positionKey)
	if err != nil {
		println("[EXPECTED] GetPosition error:", err.Error())
	} else {
		println("[EXPECTED] position liquidity:", position.Liquidity().ToString())
		println("[EXPECTED] position feeGrowthInside0LastX128:", position.FeeGrowthInside0LastX128().ToString())
		println("[EXPECTED] position feeGrowthInside1LastX128:", position.FeeGrowthInside1LastX128().ToString())
		println("[EXPECTED] position tokensOwed0:", position.TokensOwed0().ToString())
		println("[EXPECTED] position tokensOwed1:", position.TokensOwed1().ToString())
	}
}

func getObservationState() {
	println("[INFO] Check GetObservationState method")
	testing.SetRealm(adminRealm)

	observationState, err := pl.GetObservationState(poolPath)
	if err != nil {
		println("[EXPECTED] GetObservationState error:", err.Error())
	} else {
		ufmt.Printf("[EXPECTED] observationState index: %d\n", observationState.Index())
		ufmt.Printf("[EXPECTED] observationState cardinality: %d\n", observationState.Cardinality())
	}
}

// Output:
// [SCENARIO] 1. Initialize
// [SCENARIO] 1.1. Initialize Setup
// [INFO] Starting scenario: Pool Getter Methods Test
// [INFO] Approving pool creation fee
//
// [SCENARIO] 1.2. Create Pool
// [INFO] Creating bar-foo pool (fee: 3000)
// [INFO] Approving tokens for pool operations
// [INFO] Creating bar-foo pool (fee: 3000)
//
// [SCENARIO] 1.3. Mint Position
// [INFO] Minting position in bar-foo pool
// [EXPECTED] pool liquidity: 100000000 expected: 100000000
//
// [SCENARIO] 1.4 ExactIn Swap Route for tick changes
// [INFO] Executing ExactIn swap
// [EXPECTED] amountIn: 1000000
// [EXPECTED] amountOut: -985678
// [EXPECTED] admin bar balance change: 985678
// [EXPECTED] admin foo balance change: -1000000
// [EXPECTED] pool bar balance change: -987158
// [EXPECTED] pool foo balance change: 1000000
// [EXPECTED] protocol fee bar balance change: 1480
// [EXPECTED] protocol fee foo balance change: 0
//
// [SCENARIO] 2. Getter Methods
// [SCENARIO] 2.1. GetPoolCount
// [INFO] Check GetPoolCount method
// [EXPECTED] pool count: 1
//
// [SCENARIO] 2.2. GetPoolPaths
// [INFO] Check GetPoolPaths method
// [EXPECTED] pool paths count: 1
// [EXPECTED] pool path[0]: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
//
// [SCENARIO] 2.3. ExistsPoolPath
// [INFO] Check ExistsPoolPath method
// [EXPECTED] pool exists: true
// [EXPECTED] invalid pool exists: false
//
// [SCENARIO] 2.4. GetBalances
// [INFO] Check GetBalances method
// [EXPECTED] balance0: 99012842
// [EXPECTED] balance1: 101000000
//
// [SCENARIO] 2.5. GetBalanceToken0
// [INFO] Check GetBalanceToken0 method
// [EXPECTED] balance token0: 99012842
//
// [SCENARIO] 2.6. GetBalanceToken1
// [INFO] Check GetBalanceToken1 method
// [EXPECTED] balance token1: 101000000
//
// [SCENARIO] 2.7. GetFee
// [INFO] Check GetFee method
// [EXPECTED] fee: 3000
//
// [SCENARIO] 2.8. GetFeeAmountTickSpacings
// [INFO] Check GetFeeAmountTickSpacings method
// [EXPECTED] fee: 100, tickSpacing: 1
// [EXPECTED] fee: 500, tickSpacing: 10
// [EXPECTED] fee: 3000, tickSpacing: 60
// [EXPECTED] fee: 10000, tickSpacing: 200
//
// [SCENARIO] 2.9. GetFeeAmountTickSpacing
// [INFO] Check GetFeeAmountTickSpacing method
// [EXPECTED] tickSpacing for fee 3000: 60
//
// [SCENARIO] 2.10. GetFeeGrowthGlobal0X128
// [INFO] Check GetFeeGrowthGlobal0X128 method
// [EXPECTED] feeGrowthGlobal0X128: 0
//
// [SCENARIO] 2.11. GetFeeGrowthGlobal1X128
// [INFO] Check GetFeeGrowthGlobal1X128 method
// [EXPECTED] feeGrowthGlobal1X128: 10208471007628153903901238222953046
//
// [SCENARIO] 2.12. GetFeeGrowthGlobalX128
// [INFO] Check GetFeeGrowthGlobalX128 method
// [EXPECTED] feeGrowthGlobal0X128: 0
// [EXPECTED] feeGrowthGlobal1X128: 10208471007628153903901238222953046
//
// [SCENARIO] 2.13. GetFeeGrowthGlobals
// [INFO] Check GetFeeGrowthGlobals method
// [EXPECTED] feeGrowthGlobal0: 0
// [EXPECTED] feeGrowthGlobal1: 10208471007628153903901238222953046
//
// [SCENARIO] 2.14. GetLiquidity
// [INFO] Check GetLiquidity method
// [EXPECTED] liquidity: 100000000
//
// [SCENARIO] 2.15. GetMaxLiquidityPerTick
// [INFO] Check GetMaxLiquidityPerTick method
// [EXPECTED] maxLiquidityPerTick: 11505743598341114571880798222544994
//
// [SCENARIO] 2.16. GetObservation
// [INFO] Check GetObservation method
// [EXPECTED] tickCumulative: 0
// [EXPECTED] liquidityCumulative: 0
// [EXPECTED] secondsPerLiquidityCumulativeX128: 0
// [EXPECTED] blockTimestamp: 1234567890
//
// [SCENARIO] 2.17. GetPoolCreationFee
// [INFO] Check GetPoolCreationFee method
// [EXPECTED] poolCreationFee: 100000000
//
// [SCENARIO] 2.18. GetPositionFeeGrowthInside0LastX128
// [INFO] Check GetPositionFeeGrowthInside0LastX128 method
// [EXPECTED] positionFeeGrowthInside0LastX128: 0
//
// [SCENARIO] 2.19. GetPositionFeeGrowthInside1LastX128
// [INFO] Check GetPositionFeeGrowthInside1LastX128 method
// [EXPECTED] positionFeeGrowthInside1LastX128: 0
//
// [SCENARIO] 2.20. GetPositionFeeGrowthInsideLastX128
// [INFO] Check GetPositionFeeGrowthInsideLastX128 method
// [EXPECTED] positionFeeGrowthInside0LastX128: 0
// [EXPECTED] positionFeeGrowthInside1LastX128: 0
//
// [SCENARIO] 2.21. GetPositionFeeGrowthInsideLasts
// [INFO] Check GetPositionFeeGrowthInsideLasts method
// [EXPECTED] positionFeeGrowthInside0Last: 0
// [EXPECTED] positionFeeGrowthInside1Last: 0
//
// [SCENARIO] 2.22. GetPoolPositionCount
// [INFO] Check GetPoolPositionCount method
// [EXPECTED] position count: 1
//
// [SCENARIO] 2.23. GetPoolPositionKeys
// [INFO] Check GetPoolPositionKeys method
// [EXPECTED] position keys count: 1
// [EXPECTED] position key[0]: Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18tODg3MjIwX184ODcyMjA=
//
// [SCENARIO] 2.24. GetPositionLiquidity
// [INFO] Check GetPositionLiquidity method
// [EXPECTED] position liquidity: 100000000
//
// [SCENARIO] 2.25. GetPositionTokensOwed0
// [INFO] Check GetPositionTokensOwed0 method
// [EXPECTED] position tokensOwed0: 0
//
// [SCENARIO] 2.26. GetPositionTokensOwed1
// [INFO] Check GetPositionTokensOwed1 method
// [EXPECTED] position tokensOwed1: 0
//
// [SCENARIO] 2.27. GetPositionTokensOwed
// [INFO] Check GetPositionTokensOwed method
// [EXPECTED] position tokensOwed0: 0
// [EXPECTED] position tokensOwed1: 0
//
// [SCENARIO] 2.28. GetProtocolFeesToken0
// [INFO] Check GetProtocolFeesToken0 method
// [EXPECTED] protocol fee token0: 0
//
// [SCENARIO] 2.29. GetProtocolFeesToken1
// [INFO] Check GetProtocolFeesToken1 method
// [EXPECTED] protocol fee token1: 0
//
// [SCENARIO] 2.30. GetProtocolFeesTokens
// [INFO] Check GetProtocolFeesTokens method
// [EXPECTED] protocol fee token0: 0
// [EXPECTED] protocol fee token1: 0
//
// [SCENARIO] 2.31. GetSlot0FeeProtocol
// [INFO] Check GetSlot0FeeProtocol method
// [EXPECTED] slot0 feeProtocol: 0
//
// [SCENARIO] 2.32. GetSlot0SqrtPriceX96
// [INFO] Check GetSlot0SqrtPriceX96 method
// [EXPECTED] slot0 sqrtPriceX96: 80018067294531553039351583520
//
// [SCENARIO] 2.33. GetSlot0Tick
// [INFO] Check GetSlot0Tick method
// [EXPECTED] slot0 tick: 198
//
// [SCENARIO] 2.34. GetSlot0Unlocked
// [INFO] Check GetSlot0Unlocked method
// [EXPECTED] slot0 unlocked: true
//
// [SCENARIO] 2.35. GetTickCumulativeOutside
// [INFO] Check GetTickCumulativeOutside method
// [EXPECTED] tick cumulative outside at min_tick: 0
//
// [SCENARIO] 2.36. GetTickFeeGrowthOutside0X128
// [INFO] Check GetTickFeeGrowthOutside0X128 method
// [EXPECTED] tick feeGrowthOutside0X128 at min_tick: 0
//
// [SCENARIO] 2.37. GetTickFeeGrowthOutside1X128
// [INFO] Check GetTickFeeGrowthOutside1X128 method
// [EXPECTED] tick feeGrowthOutside1X128 at min_tick: 0
//
// [SCENARIO] 2.38. GetTickFeeGrowthOutsideX128
// [INFO] Check GetTickFeeGrowthOutsideX128 method
// [EXPECTED] tick feeGrowthOutside0X128 at min_tick: 0
// [EXPECTED] tick feeGrowthOutside1X128 at min_tick: 0
//
// [SCENARIO] 2.39. GetTickFeeGrowthOutsides
// [INFO] Check GetTickFeeGrowthOutsides method
// [EXPECTED] tick feeGrowthOutside0 at min_tick: 0
// [EXPECTED] tick feeGrowthOutside1 at min_tick: 0
//
// [SCENARIO] 2.40. GetTickInitialized
// [INFO] Check GetTickInitialized method
// [EXPECTED] tick initialized at min_tick: true
//
// [SCENARIO] 2.41. GetInitializedTicksInRange
// [INFO] Check GetInitializedTicksInRange method
// [EXPECTED] initialized ticks count: 1
// [EXPECTED] initialized tick[0]: -887220
//
// [SCENARIO] 2.42. GetTickLiquidityGross
// [INFO] Check GetTickLiquidityGross method
// [EXPECTED] tick liquidityGross at min_tick: 100000000
//
// [SCENARIO] 2.43. GetTickLiquidityNet
// [INFO] Check GetTickLiquidityNet method
// [EXPECTED] tick liquidityNet at min_tick: 100000000
//
// [SCENARIO] 2.44. GetTickSecondsOutside
// [INFO] Check GetTickSecondsOutside method
// [EXPECTED] tick secondsOutside at min_tick: 0
//
// [SCENARIO] 2.45. GetTickSecondsPerLiquidityOutsideX128
// [INFO] Check GetTickSecondsPerLiquidityOutsideX128 method
// [EXPECTED] tick secondsPerLiquidityOutsideX128 at min_tick: 0
//
// [SCENARIO] 2.46. GetTickSpacing
// [INFO] Check GetTickSpacing method
// [EXPECTED] tick spacing: 60
//
// [SCENARIO] 2.47. GetToken0Path
// [INFO] Check GetToken0Path method
// [EXPECTED] token0 path: gno.land/r/onbloc/bar
//
// [SCENARIO] 2.48. GetToken1Path
// [INFO] Check GetToken1Path method
// [EXPECTED] token1 path: gno.land/r/onbloc/foo
//
// [SCENARIO] 2.49. GetWithdrawalFee
// [INFO] Check GetWithdrawalFee method
// [EXPECTED] withdrawal fee: 100
//
// [SCENARIO] 2.50. GetTWAP
// [INFO] Check GetTWAP method
// [EXPECTED] GetTWAP error: secondsAgo must be greater than 0
//
// [SCENARIO] 2.51. GetPool
// [INFO] Check GetPool method
// [EXPECTED] pool token0Path: gno.land/r/onbloc/bar
// [EXPECTED] pool token1Path: gno.land/r/onbloc/foo
// [EXPECTED] pool fee: 3000
// [EXPECTED] pool liquidity: 100000000
//
// [SCENARIO] 2.52. GetTickInfo
// [INFO] Check GetTickInfo method
// [EXPECTED] tickInfo liquidityGross: 100000000
// [EXPECTED] tickInfo liquidityNet: 100000000
// [EXPECTED] tickInfo feeGrowthOutside0X128: 0
// [EXPECTED] tickInfo feeGrowthOutside1X128: 0
// [EXPECTED] tickInfo initialized: true
//
// [SCENARIO] 2.53. GetTickBitmaps
// [INFO] Check GetTickBitmaps method
// [EXPECTED] GetTickBitmaps error: tick bitmap -57 not found
//
// [SCENARIO] 2.54. GetPosition
// [INFO] Check GetPosition method
// [EXPECTED] position liquidity: 100000000
// [EXPECTED] position feeGrowthInside0LastX128: 0
// [EXPECTED] position feeGrowthInside1LastX128: 0
// [EXPECTED] position tokensOwed0: 0
// [EXPECTED] position tokensOwed1: 0
//
// [SCENARIO] 2.55. GetObservationState
// [INFO] Check GetObservationState method
// [EXPECTED] observationState index: 0
// [EXPECTED] observationState cardinality: 1
