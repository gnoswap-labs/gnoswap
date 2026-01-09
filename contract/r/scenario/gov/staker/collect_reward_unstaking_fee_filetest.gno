// staker protocol fee reward

package main

import (
	"math"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"

	"gno.land/r/gnoswap/access"

	govStaker "gno.land/r/gnoswap/gov/staker"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	poolAddr      = access.MustGetAddress(prbac.ROLE_POOL.String())
	stakerAddr    = access.MustGetAddress(prbac.ROLE_STAKER.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	routerAddr    = access.MustGetAddress(prbac.ROLE_ROUTER.String())

	aliceAddr = testutils.TestAddress("alice")

	gnsPath = "gno.land/r/gnoswap/gns"
	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
)

func main() {
	println("[SCENARIO] 1. Delegate GNS from alice to admin")
	delegateWithMint(aliceAddr, adminAddr, 1_000_000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 2. Create pool and mint position")
	createPoolByAdmin(barPath, quxPath, 3000)
	mintPositionByAdmin(barPath, quxPath, 3000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. Initialize emission")
	initEmission()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4. Stake position")
	stakePositionByAdmin(1)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 5. Collect rewards for staked position")
	collectRewardsByAdmin(1)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4. Check and collect protocol fee reward for alice")
	checkBalanceFn(gnsPath, aliceAddr, func() {
		collectProtocolFee(aliceAddr)
	})
	testing.SkipHeights(1)
	println("[EXPECTED] remained unstaking fee reward(gns) is with delegate", common.BalanceOf(gnsPath, govStakerAddr))
}

func initEmission() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	testing.SkipHeights(1)

	staker.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000", 1)
	ufmt.Printf("[EXPECTED] %s pool tier is 1\n", "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000")
}

func delegateWithMint(from, to address, amount int64) {
	// if from is not admin, transfer GNS from admin to from
	if from != adminAddr {
		testing.SetRealm(adminRealm)
		gns.Transfer(cross, from, amount)
	}

	testing.SetRealm(testing.NewUserRealm(from))
	gns.Approve(cross, govStakerAddr, amount)
	govStaker.Delegate(cross, to, int64(amount), "")

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
		"1000000",
		"1000000",
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

func stakePositionByAdmin(positionId int64) {
	testing.SetRealm(adminRealm)
	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.FormatInt(positionId, 10)))
	staker.StakeToken(cross, uint64(positionId), "")
	ufmt.Printf("[EXPECTED] Position staked successfully with ID: %d\n", positionId)
}

func collectRewardsByAdmin(positionId int64) {
	testing.SetRealm(adminRealm)
	staker.CollectReward(cross, uint64(positionId), false)
	ufmt.Printf("[EXPECTED] Rewards collected successfully for position ID: %d\n", positionId)
}

func collectProtocolFee(addr address) {
	testing.SetRealm(testing.NewUserRealm(addr))
	govStaker.CollectReward(cross)

	ufmt.Printf("[EXPECTED] Protocol fee reward collected successfully for %s\n", addr)
}

func checkBalanceFn(tokenPath string, addr address, fn func()) {
	testing.SetRealm(testing.NewUserRealm(addr))

	balanceBefore := common.BalanceOf(tokenPath, addr)
	fn()
	balanceAfter := common.BalanceOf(tokenPath, addr)

	ufmt.Printf("[EXPECTED] %s's balance of %s: %d\n", addr, tokenPath, balanceAfter-balanceBefore)
}

// Output:
// [SCENARIO] 1. Delegate GNS from alice to admin
// [INFO] delegated 1000000 GNS from g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
//
// [SCENARIO] 2. Create pool and mint position
// [INFO] created gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000 pool (poolCreationFee: 0)
// [EXPECTED] Position minted successfully with ID: 1
// [EXPECTED] Liquidity: 21338374
// [EXPECTED] Amount0: 1000000, Amount1: 1000000
//
// [SCENARIO] 3. Initialize emission
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000 pool tier is 1
//
// [SCENARIO] 4. Stake position
// [EXPECTED] Position staked successfully with ID: 1
//
// [SCENARIO] 5. Collect rewards for staked position
// [EXPECTED] Rewards collected successfully for position ID: 1
//
// [SCENARIO] 4. Check and collect protocol fee reward for alice
// [EXPECTED] Protocol fee reward collected successfully for g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
// [EXPECTED] g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh's balance of gno.land/r/gnoswap/gns: 40131
// [EXPECTED] remained unstaking fee reward(gns) is with delegate 1000001
