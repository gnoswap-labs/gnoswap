// Staker contract upgrade scenario test with collect reward
package main

import (
	"math"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	mock "gno.land/r/gnoswap/staker/mock"

	_ "gno.land/r/gnoswap/staker/v1"
	_ "gno.land/r/gnoswap/staker/v3_valid"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee500  = uint32(500)

	barFoo500PoolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	positionId        = uint64(1)
)

const (
	stakerV1Path      = "gno.land/r/gnoswap/staker/v1"
	stakerV2MockPath  = "gno.land/r/gnoswap/staker/v2_mock"
	stakerV3ValidPath = "gno.land/r/gnoswap/staker/v3_valid"
)

func main() {
	println("[SCENARIO] 1. Staker Contract Initialize")
	initialize()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool(barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	println()

	println("[SCENARIO] 3. Mint position")
	mintPosition(barPath, fooPath, fee500, -960, 960, "50000000", "50000000", "0", "0", time.Now().Unix()+3600, adminAddr, adminAddr)
	println()

	println("[SCENARIO] 4. Set pool tier for staking")
	setPoolTier(barFoo500PoolPath, 1)
	println()

	println("[SCENARIO] 5. Stake position")
	stakePosition(positionId)
	println()

	println("[SCENARIO] 6. Wait 10 blocks for reward accumulation")
	waitBlocks(10)
	collectReward(positionId, false)
	println()

	println("[SCENARIO] 7. Check staking info before upgrade")
	checkStakingInfo(positionId)
	println()

	println("[SCENARIO] 8. Staker Contract Upgrade to v2_mock")
	upgradeStakerContractToV2Invalid()
	println()

	println("[SCENARIO] 9. Collect reward with v2_mock (invalid logic)")
	waitBlocks(10)
	collectReward(positionId, false)
	println()

	println("[SCENARIO] 10. Check staking info with v2_mock (invalid logic)")
	checkStakingInfo(positionId)
	println()

	println("[SCENARIO] 11. Staker Contract Upgrade to v3_valid")
	upgradeStakerContractToV3Valid()
	println()

	println("[SCENARIO] 12. Check staking info after upgrade to v3_valid")
	checkStakingInfo(positionId)
	println()

	println("[SCENARIO] 13. Collect reward with v3_valid")
	collectReward(positionId, false)
	println()

	println("[SCENARIO] 14. Check staking info after reward collection")
	checkStakingInfo(positionId)
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)
	staker.UpgradeImpl(cross, stakerV1Path)
	println("[EXPECTED] Initialized staker contract with v1:", stakerV1Path)

	emission.SetDistributionStartTime(cross, time.Now().Unix()+5)
	testing.SkipHeights(1)

	initializeV2Mock()
}

func initializeV2Mock() {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v2_mock"))

	staker.RegisterInitializer(cross, func(stakerStore staker.IStakerStore, poolAccessor staker.PoolAccessor, emissionAccessor staker.EmissionAccessor, nftAccessor staker.NFTAccessor) staker.IStaker {
		instance := mock.NewMockStaker(stakerStore, poolAccessor, emissionAccessor, nftAccessor)
		instance.SetMockFn("CollectReward", func(args ...any) any {
			return []any{"10000000", "10000000", make(map[string]int64), make(map[string]int64)}
		})
		return instance
	})
}

func createPool(barPath, fooPath string, fee uint32, sqrtPriceX96 string) {
	println("[INFO] Create pool")
	testing.SetRealm(adminRealm)

	pool.CreatePool(cross, barPath, fooPath, fee, sqrtPriceX96)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee)

	println("[EXPECTED] Created pool path:", poolPath)

	staker.SetPoolTier(cross, poolPath, 1)
	testing.SkipHeights(1)
}

func mintPosition(barPath, fooPath string, fee uint32, tickLower, tickUpper int32, amount0Desired, amount1Desired string, amount0Min, amount1Min string, deadline int64, recipient, operator address) {
	println("[INFO] Mint position")

	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, math.MaxInt64)
	foo.Approve(cross, poolAddr, math.MaxInt64)

	positionId, liquidity, amount0, amount1 := position.Mint(cross, barPath, fooPath, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, recipient, operator, "")
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Liquidity:", liquidity)
	println("[EXPECTED] Amount0:", amount0)
	println("[EXPECTED] Amount1:", amount1)
}

func setPoolTier(poolPath string, tier uint64) {
	println("[INFO] Set pool tier")
	testing.SetRealm(adminRealm)

	staker.SetPoolTier(cross, poolPath, tier)
	println("[EXPECTED] Pool tier set to:", tier)
}

func stakePosition(positionId uint64) {
	println("[INFO] Stake position")
	testing.SetRealm(adminRealm)

	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.FormatUint(positionId, 10)))

	lpTokenId := staker.StakeToken(cross, positionId, "")
	println("[EXPECTED] Staked position ID:", positionId)
	println("[EXPECTED] LP Token ID:", lpTokenId)
}

func collectReward(positionId uint64, unwrapResult bool) {
	println("[INFO] Collect reward")
	testing.SetRealm(adminRealm)

	rewardToUser, rewardPenalty, _, _ := staker.CollectReward(cross, positionId, unwrapResult)
	rewardToUserInt, _ := strconv.ParseInt(rewardToUser, 10, 64)
	rewardPenaltyInt, _ := strconv.ParseInt(rewardPenalty, 10, 64)

	println("[EXPECTED] Total reward:", rewardToUserInt+rewardPenaltyInt)
	println("[EXPECTED] Reward to user:", rewardToUserInt)
	println("[EXPECTED] Reward penalty:", rewardPenaltyInt)
}

func checkStakingInfo(positionId uint64) {
	println("[INFO] Check staking info")
	testing.SetRealm(adminRealm)

	isStaked := staker.IsStaked(positionId)
	println("[EXPECTED] Is staked:", isStaked)

	if isStaked {
		targetPoolPath := staker.GetDepositTargetPoolPath(positionId)
		liquidity := staker.GetDepositLiquidityAsString(positionId)
		stakeTime := staker.GetDepositStakeTime(positionId)

		println("[EXPECTED] Target pool path:", targetPoolPath)
		println("[EXPECTED] Staked liquidity:", liquidity)
		println("[EXPECTED] Stake time:", stakeTime)
	}
}

func waitBlocks(n int) {
	println("[INFO] Waiting", n, "blocks")
	testing.SkipHeights(10)
}

func upgradeStakerContractToV2Invalid() {
	println("[INFO] Upgrade staker contract to v2_mock")
	testing.SetRealm(adminRealm)

	staker.UpgradeImpl(cross, stakerV2MockPath)
	println("[EXPECTED] Upgraded staker contract to v2_mock:", stakerV2MockPath)
}

func upgradeStakerContractToV3Valid() {
	println("[INFO] Upgrade staker contract to v3_valid")
	testing.SetRealm(adminRealm)

	staker.UpgradeImpl(cross, stakerV3ValidPath)
	println("[EXPECTED] Upgraded staker contract to v3_valid:", stakerV3ValidPath)
}

func withAbortsWithMessage(callback func(), logMessage string) {
	uassert.AbortsContains(t, "implementation", func() {
		callback()
	})
	println(logMessage)
}

// Output:
// [SCENARIO] 1. Staker Contract Initialize
// [EXPECTED] Initialized staker contract with v1: gno.land/r/gnoswap/staker/v1
//
// [SCENARIO] 2. Create pool
// [INFO] Create pool
// [EXPECTED] Created pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 3. Mint position
// [INFO] Mint position
// [EXPECTED] Position ID: 1
// [EXPECTED] Liquidity: 1066918731
// [EXPECTED] Amount0: 50000000
// [EXPECTED] Amount1: 50000000
//
// [SCENARIO] 4. Set pool tier for staking
// [INFO] Set pool tier
// [EXPECTED] Pool tier set to: 1
//
// [SCENARIO] 5. Stake position
// [INFO] Stake position
// [EXPECTED] Staked position ID: 1
// [EXPECTED] LP Token ID: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 6. Wait 10 blocks for reward accumulation
// [INFO] Waiting 10 blocks
// [INFO] Collect reward
// [EXPECTED] Total reward: 133374323
// [EXPECTED] Reward to user: 39731368
// [EXPECTED] Reward penalty: 93642955
//
// [SCENARIO] 7. Check staking info before upgrade
// [INFO] Check staking info
// [EXPECTED] Is staked: true
// [EXPECTED] Target pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Staked liquidity: 1066918731
// [EXPECTED] Stake time: 1234567900
//
// [SCENARIO] 8. Staker Contract Upgrade to v2_mock
// [INFO] Upgrade staker contract to v2_mock
// [EXPECTED] Upgraded staker contract to v2_mock: gno.land/r/gnoswap/staker/v2_mock
//
// [SCENARIO] 9. Collect reward with v2_mock (invalid logic)
// [INFO] Waiting 10 blocks
// [INFO] Collect reward
// [EXPECTED] Total reward: 20000000
// [EXPECTED] Reward to user: 10000000
// [EXPECTED] Reward penalty: 10000000
//
// [SCENARIO] 10. Check staking info with v2_mock (invalid logic)
// [INFO] Check staking info
// [EXPECTED] Is staked: true
// [EXPECTED] Target pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Staked liquidity: 1066918731
// [EXPECTED] Stake time: 1234567900
//
// [SCENARIO] 11. Staker Contract Upgrade to v3_valid
// [INFO] Upgrade staker contract to v3_valid
// [EXPECTED] Upgraded staker contract to v3_valid: gno.land/r/gnoswap/staker/v3_valid
//
// [SCENARIO] 12. Check staking info after upgrade to v3_valid
// [INFO] Check staking info
// [EXPECTED] Is staked: true
// [EXPECTED] Target pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Staked liquidity: 1066918731
// [EXPECTED] Stake time: 1234567900
//
// [SCENARIO] 13. Collect reward with v3_valid
// [INFO] Collect reward
// [EXPECTED] Total reward: 133374323
// [EXPECTED] Reward to user: 39731368
// [EXPECTED] Reward penalty: 93642955
//
// [SCENARIO] 14. Check staking info after reward collection
// [INFO] Check staking info
// [EXPECTED] Is staked: true
// [EXPECTED] Target pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Staked liquidity: 1066918731
// [EXPECTED] Stake time: 1234567900
