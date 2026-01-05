// staker protocol fee reward - delegation added in the middle (swap fee)

package main

import (
	"math"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"
	"gno.land/r/gnoswap/router"
	_ "gno.land/r/gnoswap/router/v1"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gov/staker"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	poolAddr      = access.MustGetAddress(prbac.ROLE_POOL.String())
	stakerAddr    = access.MustGetAddress(prbac.ROLE_STAKER.String())
	gnoStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	routerAddr    = access.MustGetAddress(prbac.ROLE_ROUTER.String())

	aliceAddr = testutils.TestAddress("alice")

	gnsPath = "gno.land/r/gnoswap/gns"
	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
)

func main() {
	println("[SCENARIO] 1. Admin delegates first")
	delegateWithMint(adminAddr, adminAddr, 1_000_000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 2. Create pool and mint position")
	createPoolByAdmin(barPath, quxPath, 3000)
	mintPositionByAdmin(barPath, quxPath, 3000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. First swap (before alice delegation)")
	exactInSingleSwapRouteByAdmin(barPath, quxPath, "10000", "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000", "", "1")
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4. Alice delegates in the middle")
	delegateWithMint(aliceAddr, adminAddr, 1_000_000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 5. Second swap (after alice delegation)")
	exactInSingleSwapRouteByAdmin(barPath, quxPath, "10000", "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000", "", "1")
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 6. Check and collect protocol fee reward for admin")
	checkBalanceFn(quxPath, adminAddr, func() {
		collectProtocolFee(adminAddr)
	})
	println()

	println("[SCENARIO] 7. Check and collect protocol fee reward for alice")
	checkBalanceFn(quxPath, aliceAddr, func() {
		collectProtocolFee(aliceAddr)
	})
	println("[EXPECTED] remained protocol fee reward is", common.BalanceOf(quxPath, gnoStakerAddr))
}

func delegateWithMint(from, to address, amount int64) {
	if from != adminAddr {
		testing.SetRealm(adminRealm)
		gns.Transfer(cross, from, amount)
	}

	testing.SetRealm(testing.NewUserRealm(from))
	gns.Approve(cross, gnoStakerAddr, amount)
	staker.Delegate(cross, to, int64(amount), "")

	ufmt.Printf("[INFO] delegated %d GNS from %s to %s\n", amount, from, to)
}

func createPoolByAdmin(token0, token1 string, fee int64) {
	testing.SetRealm(adminRealm)

	pool.SetPoolCreationFee(cross, 0)
	poolCreationFee := pool.GetPoolCreationFee()
	pool.CreatePool(cross, token0, token1, uint32(fee), common.TickMathGetSqrtRatioAtTick(0).ToString())

	ufmt.Printf("[INFO] created %s:%s:%d pool (poolCreationFee: %d)\n", token0, token1, fee, poolCreationFee)
}

func mintPositionByAdmin(token0, token1 string, fee int64) {
	testing.SetRealm(adminRealm)

	common.SafeGRC20Approve(cross, token0, poolAddr, math.MaxInt64)
	common.SafeGRC20Approve(cross, token1, poolAddr, math.MaxInt64)

	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		token0,
		token1,
		uint32(fee),
		-960,
		960,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position minted successfully with ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0: %s, Amount1: %s\n", amount0, amount1)
}

func exactInSingleSwapRouteByAdmin(
	inputToken string,
	outputToken string,
	specifiedAmount string,
	routeQueryString string,
	queryRatios string,
	minAmountOut string,
) {
	testing.SetRealm(adminRealm)

	common.SafeGRC20Approve(cross, inputToken, routerAddr, math.MaxInt64)

	inputTokenAmount, outputTokenAmount := router.ExactInSingleSwapRoute(
		cross,
		inputToken,
		outputToken,
		specifiedAmount,
		routeQueryString,
		minAmountOut,
		common.TickMathGetSqrtRatioAtTick(-1000).ToString(),
		int64(9999999999),
		"",
	)

	ufmt.Printf("[EXPECTED] pool current tick: %d\n", pool.GetSlot0Tick(routeQueryString))
	ufmt.Printf("[EXPECTED] inputTokenAmount(%s): %s\n", inputToken, inputTokenAmount)
	ufmt.Printf("[EXPECTED] outputTokenAmount(%s): %s\n", outputToken, outputTokenAmount)
}

func collectProtocolFee(addr address) {
	testing.SetRealm(testing.NewUserRealm(addr))
	staker.CollectReward(cross)

	println("[INFO] collected protocol fee reward for", addr)
}

func checkBalanceFn(tokenPath string, addr address, fn func()) {
	testing.SetRealm(testing.NewUserRealm(addr))

	balanceBefore := common.BalanceOf(tokenPath, addr)
	fn()
	balanceAfter := common.BalanceOf(tokenPath, addr)

	ufmt.Printf("[EXPECTED] %s's balance of %s: %d\n", addr, tokenPath, balanceAfter-balanceBefore)
}

// Output:
// [SCENARIO] 1. Admin delegates first
// [INFO] delegated 1000000 GNS from g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
//
// [SCENARIO] 2. Create pool and mint position
// [INFO] created gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000 pool (poolCreationFee: 0)
// [EXPECTED] Position minted successfully with ID: 1
// [EXPECTED] Liquidity: 213383746
// [EXPECTED] Amount0: 10000000, Amount1: 10000000
//
// [SCENARIO] 3. First swap (before alice delegation)
// [EXPECTED] pool current tick: -1
// [EXPECTED] inputTokenAmount(gno.land/r/onbloc/bar): 10000
// [EXPECTED] outputTokenAmount(gno.land/r/onbloc/qux): -9955
//
// [SCENARIO] 4. Alice delegates in the middle
// [INFO] delegated 1000000 GNS from g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
//
// [SCENARIO] 5. Second swap (after alice delegation)
// [EXPECTED] pool current tick: -2
// [EXPECTED] inputTokenAmount(gno.land/r/onbloc/bar): 10000
// [EXPECTED] outputTokenAmount(gno.land/r/onbloc/qux): -9954
//
// [SCENARIO] 6. Check and collect protocol fee reward for admin
// [INFO] collected protocol fee reward for g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [EXPECTED] g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5's balance of gno.land/r/onbloc/qux: 20
//
// [SCENARIO] 7. Check and collect protocol fee reward for alice
// [INFO] collected protocol fee reward for g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
// [EXPECTED] g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh's balance of gno.land/r/onbloc/qux: 6
// [EXPECTED] remained protocol fee reward is 2
