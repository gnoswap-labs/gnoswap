// DCA order - multi user claim scenario

package main

import (
	"chain"
	"math"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/rbac"
	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/qux"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/dca_order"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	poolAddr = access.MustGetAddress(prbac.ROLE_POOL.String())

	user1Addr = testutils.TestAddress("user1")
	user2Addr = testutils.TestAddress("user2")

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000"

	// DCA interval in seconds (simulating with block time)
	intervalSeconds int64 = 60
)

func main() {
	println("[SCENARIO] 1. Create pool")
	createPoolByAdmin(barPath, quxPath, 3000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 2. Mint position to provide liquidity")
	mintPositionByAdmin(barPath, quxPath, 3000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. Enable processMissedIntervals flag")
	enableProcessMissedIntervals()
	println()

	println("[SCENARIO] 4. User1 creates DCA order (1M/execution x 5 executions)")
	transferTokensToUser(user1Addr, barPath, 10_000_000)
	orderID1 := createOrderByUser(user1Addr, poolPath, true, intervalSeconds, 1_000_000, 5)
	ufmt.Printf("[EXPECTED] User1 order created with ID: %s\n", orderID1)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 5. Skip 5 intervals and execute batch swap (should process all 5 missed intervals)")
	// Skip 5 intervals worth of time
	testing.SkipHeights(intervalSeconds / 5 * 10)
	// Execute batch swap - should process all 5 missed intervals
	executeBatchSwapByAdmin()
	println()

	println("[SCENARIO] 6. User1 claims all rewards (should be ~5M worth of output tokens)")
	claimByUser(user1Addr, orderID1)
	println()

	println("[SCENARIO] 7. Check final balances")
	printUserBalances(user1Addr, "User1")
}

func createPoolByAdmin(token0, token1 string, fee int64) {
	testing.SetRealm(adminRealm)

	pool.SetPoolCreationFee(cross, 0)
	poolCreationFee := pool.GetPoolCreationFee()
	pool.CreatePool(cross, token0, token1, uint32(fee), common.TickMathGetSqrtRatioAtTick(0).ToString())

	ufmt.Printf("[INFO] Created %s:%s:%d pool (poolCreationFee: %d)\n", token0, token1, fee, poolCreationFee)
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
		"1000000000",
		"1000000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position minted with ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0: %s, Amount1: %s\n", amount0, amount1)
}

func transferTokensToUser(user address, tokenPath string, amount int64) {
	testing.SetRealm(adminRealm)
	common.SafeGRC20Transfer(cross, tokenPath, user, amount)
	ufmt.Printf("[INFO] Transferred %d tokens (%s) to %s\n", amount, tokenPath, user)
}

func createOrderByUser(user address, poolPath string, zeroForOne bool, interval int64, amountPerExecution int64, totalExecutions int) string {
	testing.SetRealm(testing.NewUserRealm(user))

	dcaOrderAddr := chain.PackageAddress("gno.land/r/gnoswap/dca_order")

	// Approve DCA order contract to spend tokens
	common.SafeGRC20Approve(cross, barPath, dcaOrderAddr, amountPerExecution*int64(totalExecutions))

	orderID := dca_order.CreateOrder(
		cross,
		poolPath,
		zeroForOne,
		interval,
		amountPerExecution,
		totalExecutions,
	)

	ufmt.Printf("[INFO] Created DCA order: poolPath=%s, zeroForOne=%t, interval=%d, amountPerExecution=%d, totalExecutions=%d\n",
		poolPath, zeroForOne, interval, amountPerExecution, totalExecutions)

	return orderID
}

func enableProcessMissedIntervals() {
	testing.SetRealm(adminRealm)
	dca_order.SetProcessMissedIntervals(cross, true)
	ufmt.Printf("[INFO] ProcessMissedIntervals flag enabled: %t\n", dca_order.GetProcessMissedIntervals())
}

func executeBatchSwapByAdmin() {
	testing.SetRealm(adminRealm)

	beforeBarPoolBalance := common.BalanceOf(barPath, poolAddr)
	beforeQuxPoolBalance := common.BalanceOf(quxPath, poolAddr)
	results := dca_order.ExecuteBatchSwap(cross)
	afterBarPoolBalance := common.BalanceOf(barPath, poolAddr)
	afterQuxPoolBalance := common.BalanceOf(quxPath, poolAddr)
	ufmt.Printf("[INFO] Batch swap changes - BAR: %d, QUX: %d\n", afterBarPoolBalance-beforeBarPoolBalance, afterQuxPoolBalance-beforeQuxPoolBalance)

	for _, result := range results {
		if result.Success {
			ufmt.Printf("[INFO] Batch swap executed for group %s: amountIn=%d, amountOut=%d\n",
				result.GroupID, result.AmountIn, result.AmountOut)
		} else {
			ufmt.Printf("[INFO] Batch swap failed for group %s: %s\n", result.GroupID, result.Error)
		}
	}
}

func claimByUser(user address, orderID string) {
	testing.SetRealm(testing.NewUserRealm(user))

	balanceBefore := common.BalanceOf(quxPath, user)

	claimed := dca_order.Claim(cross, orderID)

	balanceAfter := common.BalanceOf(quxPath, user)

	ufmt.Printf("[EXPECTED] %s claimed %d tokens (balance change: %d)\n", user, claimed, balanceAfter-balanceBefore)
}

func printUserBalances(user address, name string) {
	barBalance := common.BalanceOf(barPath, user)
	quxBalance := common.BalanceOf(quxPath, user)

	ufmt.Printf("[EXPECTED] %s balances - BAR: %d, QUX: %d\n", name, barBalance, quxBalance)
}

// Output:
// [SCENARIO] 1. Create pool
// [INFO] Created gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000 pool (poolCreationFee: 0)
//
// [SCENARIO] 2. Mint position to provide liquidity
// [EXPECTED] Position minted with ID: 1
// [EXPECTED] Liquidity: 21338374629
// [EXPECTED] Amount0: 1000000000, Amount1: 1000000000
//
// [SCENARIO] 3. Enable processMissedIntervals flag
// [INFO] ProcessMissedIntervals flag enabled: true
//
// [SCENARIO] 4. User1 creates DCA order (1M/execution x 5 executions)
// [INFO] Transferred 10000000 tokens (gno.land/r/onbloc/bar) to g1w4ek2u33ta047h6lta047h6lta047h6ldvdwpn
// [INFO] Created DCA order: poolPath=gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000, zeroForOne=true, interval=60, amountPerExecution=1000000, totalExecutions=5
// [EXPECTED] User1 order created with ID: gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000*1*60*1
//
// [SCENARIO] 5. Skip 5 intervals and execute batch swap (should process all 5 missed intervals)
// [INFO] Batch swap changes - BAR: 5000000, QUX: -4983833
// [INFO] Batch swap executed for group gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000*1*60: amountIn=1000000, amountOut=996953
// [INFO] Batch swap executed for group gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000*1*60: amountIn=1000000, amountOut=996860
// [INFO] Batch swap executed for group gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000*1*60: amountIn=1000000, amountOut=996767
// [INFO] Batch swap executed for group gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000*1*60: amountIn=1000000, amountOut=996673
// [INFO] Batch swap executed for group gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000*1*60: amountIn=1000000, amountOut=996580
//
// [SCENARIO] 6. User1 claims all rewards (should be ~5M worth of output tokens)
// [EXPECTED] g1w4ek2u33ta047h6lta047h6lta047h6ldvdwpn claimed 4983832 tokens (balance change: 4983832)
//
// [SCENARIO] 7. Check final balances
// [EXPECTED] User1 balances - BAR: 5000000, QUX: 4983832
