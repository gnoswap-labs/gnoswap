// Scenario: Swap Balance Validation - Extreme Price Movements
// Purpose: Validate balance conservation during extreme pool swaps with wide price ranges

// PKGPATH: gno.land/r/gnoswap/pool/swap_balance_extreme

package swap_balance_extreme

import (
	"testing"

	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/eth"
	"gno.land/r/gnoswap/test_token/usdc"
)

const (
	maxApprove      int64  = 9223372036854775806
	poolCreationFee int64  = 100_000_000
	fee500          uint32 = 500
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm         = testing.NewUserRealm(adminAddr)
	positionAddr, _    = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm           = testing.NewUserRealm(positionAddr)
	routerRealm        = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	poolAddr, _        = access.GetAddress(prbac.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
)

var (
	ethPath  = "gno.land/r/gnoswap/test_token/eth"
	usdcPath = "gno.land/r/gnoswap/test_token/usdc"
)

const (
	MIN_PRICE = "4295128740"
	MAX_PRICE = "1461446703485210103287273052203988822378723970341"
)

// turn protocol fee on
func init() {
	testing.SetRealm(adminRealm)
	pool.SetFeeProtocol(cross, 6, 6)
}

type BalanceSnapshot struct {
	userEth        int64
	userUsdc       int64
	poolEth        int64
	poolUsdc       int64
	protocolFeeEth int64
	protocolFeeUsdc int64
}

func main() {
	println("[SCENARIO] Swap Balance Validation - Extreme Price Movements")
	println("[INFO] Purpose: Validate balance conservation during extreme pool swaps")
	println()

	println("[SCENARIO] 1. Setup - Create Pool with Wide Range")
	initial := setupWideRangePool()
	printBalanceSnapshot("After Pool Setup", initial)
	println()

	println("[SCENARIO] 2. Extreme Downward Price Movement")
	afterDown := testExtremePriceDown(initial)
	printBalanceSnapshot("After Extreme Down", afterDown)
	validateBalanceChange(initial, afterDown, "Extreme Down")
	println()

	println("[SCENARIO] 3. Extreme Upward Price Movement")
	afterUp := testExtremePriceUp(afterDown)
	printBalanceSnapshot("After Extreme Up", afterUp)
	validateBalanceChange(afterDown, afterUp, "Extreme Up")
	println()

	println("[SCENARIO] 4. Maximum Slippage Test")
	afterSlippage := testMaximumSlippage(afterUp)
	printBalanceSnapshot("After Maximum Slippage", afterSlippage)
	validateBalanceChange(afterUp, afterSlippage, "Maximum Slippage")
	println()

	println("[SCENARIO] Complete - All extreme price movement validations passed")
}

func getBalanceSnapshot() BalanceSnapshot {
	return BalanceSnapshot{
		userEth:         eth.BalanceOf(adminAddr),
		userUsdc:        usdc.BalanceOf(adminAddr),
		poolEth:         eth.BalanceOf(poolAddr),
		poolUsdc:        usdc.BalanceOf(poolAddr),
		protocolFeeEth:  eth.BalanceOf(protocolFeeAddr),
		protocolFeeUsdc: usdc.BalanceOf(protocolFeeAddr),
	}
}

func printBalanceSnapshot(step string, snapshot BalanceSnapshot) {
	println("[INFO]", step)
	println("[EXPECTED] User ETH balance:", snapshot.userEth)
	println("[EXPECTED] User USDC balance:", snapshot.userUsdc)
	println("[EXPECTED] Pool ETH balance:", snapshot.poolEth)
	println("[EXPECTED] Pool USDC balance:", snapshot.poolUsdc)
	println("[EXPECTED] Protocol fee ETH balance:", snapshot.protocolFeeEth)
	println("[EXPECTED] Protocol fee USDC balance:", snapshot.protocolFeeUsdc)
}

func setupWideRangePool() BalanceSnapshot {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, ethPath, usdcPath, fee500, "79228162514264337593543950336")

	usdc.Approve(cross, poolAddr, maxApprove)
	eth.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		ethPath,
		usdcPath,
		fee500,
		-10000,
		10000,
		"10000000000",
		adminAddr,
	)

	pools, _ := pool.GetPool(ethPath, usdcPath, fee500)
	println("[INFO] Pool created with wide-range position (-10000 to 10000)")
	println("[INFO] Minted amounts - eth:", amount0, "usdc:", amount1)
	println("[INFO] Initial tick:", pools.Slot0Tick())

	return getBalanceSnapshot()
}

func testExtremePriceDown(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools, _ := pool.GetPool(ethPath, usdcPath, fee500)
	tickBefore := pools.Slot0Tick()

	println("[INFO] Swapping 10000000 ETH -> USDC (extreme downward movement)")

	eth.Approve(cross, poolAddr, 10000000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		ethPath,
		usdcPath,
		fee500,
		adminAddr,
		true,
		"10000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(ethPath, usdcPath, amount0Delta, amount1Delta)
		},
	)

	pools, _ = pool.GetPool(ethPath, usdcPath, fee500)
	tickAfter := pools.Slot0Tick()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick moved from", tickBefore, "to", tickAfter)

	return getBalanceSnapshot()
}

func testExtremePriceUp(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools, _ := pool.GetPool(ethPath, usdcPath, fee500)
	tickBefore := pools.Slot0Tick()

	println("[INFO] Swapping 5000000 USDC -> ETH (extreme upward movement)")

	usdc.Approve(cross, poolAddr, 5000000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		ethPath,
		usdcPath,
		fee500,
		adminAddr,
		false,
		"5000000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(ethPath, usdcPath, amount0Delta, amount1Delta)
		},
	)

	pools, _ = pool.GetPool(ethPath, usdcPath, fee500)
	tickAfter := pools.Slot0Tick()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick moved from", tickBefore, "to", tickAfter)

	return getBalanceSnapshot()
}

func testMaximumSlippage(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools, _ := pool.GetPool(ethPath, usdcPath, fee500)
	tickBefore := pools.Slot0Tick()

	println("[INFO] Swapping 20000000 ETH -> USDC (maximum slippage)")

	eth.Approve(cross, poolAddr, 20000000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		ethPath,
		usdcPath,
		fee500,
		adminAddr,
		true,
		"20000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(ethPath, usdcPath, amount0Delta, amount1Delta)
		},
	)

	pools, _ = pool.GetPool(ethPath, usdcPath, fee500)
	tickAfter := pools.Slot0Tick()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick moved from", tickBefore, "to", tickAfter)

	return getBalanceSnapshot()
}

func validateBalanceChange(before, after BalanceSnapshot, swapType string) {
	println("[INFO] Validating balance changes for", swapType)

	userEthDiff := after.userEth - before.userEth
	userUsdcDiff := after.userUsdc - before.userUsdc
	poolEthDiff := after.poolEth - before.poolEth
	poolUsdcDiff := after.poolUsdc - before.poolUsdc
	protocolFeeEthDiff := after.protocolFeeEth - before.protocolFeeEth
	protocolFeeUsdcDiff := after.protocolFeeUsdc - before.protocolFeeUsdc

	println("[EXPECTED] User ETH change:", userEthDiff)
	println("[EXPECTED] User USDC change:", userUsdcDiff)
	println("[EXPECTED] Pool ETH change:", poolEthDiff)
	println("[EXPECTED] Pool USDC change:", poolUsdcDiff)
	println("[EXPECTED] Protocol Fee ETH change:", protocolFeeEthDiff)
	println("[EXPECTED] Protocol Fee USDC change:", protocolFeeUsdcDiff)

	// Exact conservation: user + pool + protocol fee changes must sum to 0
	totalEthChange := userEthDiff + poolEthDiff + protocolFeeEthDiff
	totalUsdcChange := userUsdcDiff + poolUsdcDiff + protocolFeeUsdcDiff

	if totalEthChange != 0 {
		panic(ufmt.Sprintf("[ERROR] ETH not conserved! Total change: %d", totalEthChange))
	}
	if totalUsdcChange != 0 {
		panic(ufmt.Sprintf("[ERROR] USDC not conserved! Total change: %d", totalUsdcChange))
	}

	println("[EXPECTED] Exact balance conservation verified for", swapType)
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] Swap Balance Validation - Extreme Price Movements
// [INFO] Purpose: Validate balance conservation during extreme pool swaps
//
// [SCENARIO] 1. Setup - Create Pool with Wide Range
// [INFO] Pool created with wide-range position (-10000 to 10000)
// [INFO] Minted amounts - eth: 3934541779 usdc: 3934541779
// [INFO] Initial tick: 0
// [INFO] After Pool Setup
// [EXPECTED] User ETH balance: 119996065458221
// [EXPECTED] User USDC balance: 69999996065458221
// [EXPECTED] Pool ETH balance: 3934541779
// [EXPECTED] Pool USDC balance: 3934541779
// [EXPECTED] Protocol fee ETH balance: 0
// [EXPECTED] Protocol fee USDC balance: 0
//
// [SCENARIO] 2. Extreme Downward Price Movement
// [INFO] Swapping 10000000 ETH -> USDC (extreme downward movement)
// [INFO] Swap - In: 10000000 Out: -9985019
// [INFO] Tick moved from 0 to -20
// [INFO] After Extreme Down
// [EXPECTED] User ETH balance: 119996055458221
// [EXPECTED] User USDC balance: 69999996075443240
// [EXPECTED] Pool ETH balance: 3944541779
// [EXPECTED] Pool USDC balance: 3924556760
// [EXPECTED] Protocol fee ETH balance: 0
// [EXPECTED] Protocol fee USDC balance: 0
// [INFO] Validating balance changes for Extreme Down
// [EXPECTED] User ETH change: -10000000
// [EXPECTED] User USDC change: 9985019
// [EXPECTED] Pool ETH change: 10000000
// [EXPECTED] Pool USDC change: -9985019
// [EXPECTED] Protocol Fee ETH change: 0
// [EXPECTED] Protocol Fee USDC change: 0
// [EXPECTED] Exact balance conservation verified for Extreme Down
//
// [SCENARIO] 3. Extreme Upward Price Movement
// [INFO] Swapping 5000000 USDC -> ETH (extreme upward movement)
// [INFO] Swap - In: -5004988 Out: 5000000
// [INFO] Tick moved from -20 to -10
// [INFO] After Extreme Up
// [EXPECTED] User ETH balance: 119996060463209
// [EXPECTED] User USDC balance: 69999996070443240
// [EXPECTED] Pool ETH balance: 3939536791
// [EXPECTED] Pool USDC balance: 3929556760
// [EXPECTED] Protocol fee ETH balance: 0
// [EXPECTED] Protocol fee USDC balance: 0
// [INFO] Validating balance changes for Extreme Up
// [EXPECTED] User ETH change: 5004988
// [EXPECTED] User USDC change: -5000000
// [EXPECTED] Pool ETH change: -5004988
// [EXPECTED] Pool USDC change: 5000000
// [EXPECTED] Protocol Fee ETH change: 0
// [EXPECTED] Protocol Fee USDC change: 0
// [EXPECTED] Exact balance conservation verified for Extreme Up
//
// [SCENARIO] 4. Maximum Slippage Test
// [INFO] Swapping 20000000 ETH -> USDC (maximum slippage)
// [INFO] Swap - In: 20000000 Out: -19930244
// [INFO] Tick moved from -10 to -50
// [INFO] After Maximum Slippage
// [EXPECTED] User ETH balance: 119996040463209
// [EXPECTED] User USDC balance: 69999996090373484
// [EXPECTED] Pool ETH balance: 3959536791
// [EXPECTED] Pool USDC balance: 3909626516
// [EXPECTED] Protocol fee ETH balance: 0
// [EXPECTED] Protocol fee USDC balance: 0
// [INFO] Validating balance changes for Maximum Slippage
// [EXPECTED] User ETH change: -20000000
// [EXPECTED] User USDC change: 19930244
// [EXPECTED] Pool ETH change: 20000000
// [EXPECTED] Pool USDC change: -19930244
// [EXPECTED] Protocol Fee ETH change: 0
// [EXPECTED] Protocol Fee USDC change: 0
// [EXPECTED] Exact balance conservation verified for Maximum Slippage
//
// [SCENARIO] Complete - All extreme price movement validations passed
