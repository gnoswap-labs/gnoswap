// emission halt distribution
//
// Scenario:
//   1. Collect emission reward before halt
//   2. Halt emission
//   3. Collect emission reward after halt with insufficient balance
//   4. Resume emission
//   5. Collect emission reward after resume

// PKGPATH: gno.land/r/demo/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	_ "gno.land/r/gnoswap/rbac"
	"gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	t *testing.T

	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm         = testing.NewUserRealm(adminAddr)
	poolAddr, _        = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _      = access.GetAddress(prbac.ROLE_ROUTER.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	emissionAddr, _    = access.GetAddress(prbac.ROLE_EMISSION.String())
	routerRealm        = testing.NewUserRealm(routerAddr)

	barPath        = "gno.land/r/onbloc/bar"
	fooPath        = "gno.land/r/onbloc/foo"
	fee500  uint32 = 500

	barFooPoolPath = ufmt.Sprintf("%s:%s:%d", barPath, fooPath, fee500)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize emission state and pool")
	initEmissionState()
	initPool()
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 2. Mint position and stake")
	mintPositionAndStake()
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 3. Collect rewards before halt")
	collectRewards(1)
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 4. Set emission halt and skip 9 blocks")
	setEmissionHaltState(true)
	testing.SkipHeights(9)
	println()

	ufmt.Println("[SCENARIO] 5. Collect rewards after halt with insufficient balance")
	collectRewardsWithInsufficientBalance(1)
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 6. Resume emission")
	setEmissionHaltState(false)
	println()

	ufmt.Println("[SCENARIO] 7. Collect rewards after resume")
	collectRewards(1)
	testing.SkipHeights(1)
	println()
}

func initEmissionState() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	ufmt.Println("[INFO] Initializing emission state")
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.SetRealm(adminRealm)

	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	staker.SetPoolTier(cross, barFooPoolPath, 1)

	ufmt.Println("[INFO] Pool created: %s (tier: 1)", barFooPoolPath)
}

func mintPositionAndStake() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting and staking position")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-1000,
		1000,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		adminAddr,
		adminAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	staker.StakeToken(cross, positionId, "")

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func setEmissionHaltState(halted bool) {
	testing.SetRealm(adminRealm)
	halt.SetOperationStatus(cross, halt.OpTypeEmission, halted)

	ufmt.Printf("[INFO] Emission halt state set to %t\n", halted)
}

func collectRewards(positionId uint64) {
	testing.SetRealm(adminRealm)

	var rewardAmountAccumulated int64
	var rewardAmountPerBlock int64

	checkEmissionDistributionChangesFn(func() {
		initializedGns := gns.BalanceOf(adminAddr)
		staker.CollectReward(cross, positionId, false)
		testing.SkipHeights(1)

		beforeGns := gns.BalanceOf(adminAddr)
		staker.CollectReward(cross, positionId, false)
		afterGns := gns.BalanceOf(adminAddr)

		rewardAmountAccumulated = beforeGns - initializedGns
		rewardAmountPerBlock = afterGns - beforeGns
	})

	ufmt.Printf("[EXPECTED] reward accumulated: %d, reward per block: %d\n", rewardAmountAccumulated, rewardAmountPerBlock)
	ufmt.Printf("[EXPECTED] total reward: %d\n", rewardAmountAccumulated+rewardAmountPerBlock)
}

func collectRewardsWithInsufficientBalance(positionId uint64) {
	uassert.AbortsContains(t, "insufficient balance", func() {
		collectRewards(positionId)
	})

	expectedRewardAmount := 3973137 * 10 // 10 blocks

	ufmt.Printf("[EXPECTED] Should abort with insufficient balance error when collect rewards\n")
	ufmt.Printf("[EXPECTED] The staker's balance is greater than the amount of rewards that need to be transferred to the user.\n")
	ufmt.Printf("[EXPECTED] The staker's balance is %d and expected reward amount is %d\n", gns.BalanceOf(stakerAddr), expectedRewardAmount)
}

func checkEmissionDistributionChangesFn(fn func()) {
	beforeTimestamp := time.Now().Unix()
	beforeEmissionDistributionBalance := emission.GetDistributedToStaker()
	fn()
	afterTimestamp := time.Now().Unix()
	afterEmissionDistributionBalance := emission.GetDistributedToStaker()
	lastDistributedTimestamp := emission.GetLastExecutedTimestamp()
	ufmt.Printf("[INFO] Check emission distribution amount to staker (last distributed: %d)\n", lastDistributedTimestamp)
	ufmt.Printf("[INFO] Emission distribution balance changed: %d (%d seconds)\n", afterEmissionDistributionBalance-beforeEmissionDistributionBalance, afterTimestamp-beforeTimestamp)
}

// Output:
// [SCENARIO] 1. Initialize emission state and pool
// [INFO] Initializing emission state
// [INFO] Pool created: %s (tier: 1) gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 2. Mint position and stake
// [INFO] Minting and staking position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 1025258313
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Collect rewards before halt
// [INFO] Check emission distribution amount to staker (last distributed: 1234567905)
// [INFO] Emission distribution balance changed: 53510274 (5 seconds)
// [EXPECTED] reward accumulated: 3973137, reward per block: 3973137
// [EXPECTED] total reward: 7946274
//
// [SCENARIO] 4. Set emission halt and skip 9 blocks
// [INFO] Emission halt state set to true
//
// [SCENARIO] 5. Collect rewards after halt with insufficient balance
// [EXPECTED] Should abort with insufficient balance error when collect rewards
// [EXPECTED] The staker's balance is greater than the amount of rewards that need to be transferred to the user.
// [EXPECTED] The staker's balance is 2675536 and expected reward amount is 39731370
//
// [SCENARIO] 6. Resume emission
// [INFO] Emission halt state set to false
//
// [SCENARIO] 7. Collect rewards after resume
// [INFO] Check emission distribution amount to staker (last distributed: 1234567965)
// [INFO] Emission distribution balance changed: 321061636 (5 seconds)
// [EXPECTED] reward accumulated: 3973137, reward per block: 3973137
// [EXPECTED] total reward: 7946274
