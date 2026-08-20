// PKGPATH: gno.land/r/gnoswap/v1/main

// Staker contract upgrade scenario test with collect reward
package main

import (
	"math"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/scenarioutils"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/staker/v1"
	_ "gno.land/r/gnoswap/staker/v2_invalid"
	_ "gno.land/r/gnoswap/staker/v3_valid"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	fee500  = uint32(500)

	barFoo500PoolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500"
	positionId        = uint64(1)

	// snapshot of the staking state written by v1
	v1DepositOwner       address
	v1DepositPoolPath    string
	v1DepositLiquidity   string
	v1DepositStakeTime   int64
	v1DepositTickLower   int32
	v1DepositTickUpper   int32
	v1DepositWarmupCount int
	v1CollectedInternal  int64
	v1PoolTier           uint64
	v1PoolTierRatio      uint64
	v1PoolStakedLiq      string
	v1UnstakingFee       uint64
	v1DepositGnsAmount   int64
	v1AllowedTokenCount  int
	v1TotalEmissionSent  int64
)

const (
	stakerV1Path        = "gno.land/r/gnoswap/staker/v1"
	stakerV2InvalidPath = "gno.land/r/gnoswap/staker/v2_invalid"
	stakerV3ValidPath   = "gno.land/r/gnoswap/staker/v3_valid"
)

func main(cur realm) {
	println("[SCENARIO] 1. Staker Contract Initialize")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Create pool")
	createPool(cur, barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	println()

	println("[SCENARIO] 3. Mint position")
	mintPosition(cur, barPath, fooPath, fee500, -960, 960, "50000000", "50000000", "0", "0", time.Now().Unix()+3600, adminAddr, adminAddr)
	println()

	println("[SCENARIO] 4. Set pool tier for staking")
	setPoolTier(cur, barFoo500PoolPath, 1)
	println()

	println("[SCENARIO] 5. Stake position")
	stakePosition(cur, positionId)
	println()

	println("[SCENARIO] 6. Wait 10 blocks for reward accumulation")
	waitBlocks(cur, 10)
	collectReward(cur, positionId)
	println()

	println("[SCENARIO] 7. Check staking info before upgrade")
	checkStakingInfo(cur, positionId)
	println()

	println("[SCENARIO] 7-1. Snapshot the staking state written by v1")
	captureV1Snapshot()
	println()

	println("[SCENARIO] 8. Staker Contract Upgrade to v2_invalid")
	upgradeStakerContractToV2Invalid(cur)
	println()

	println("[SCENARIO] 9. Collect reward with v2_invalid (should panic)")
	withAbortsWithMessage(
		cur, func() {
			waitBlocks(cur, 10)
			collectReward(cur, positionId)
		},
		"[EXPECTED] Collect reward panics correctly with v2_invalid",
	)
	println()

	println("[SCENARIO] 10. Check staking info with v2_invalid (should panic)")
	withAbortsWithMessage(
		cur, func() {
			checkStakingInfo(cur, positionId)
		},
		"[EXPECTED] Check staking info panics correctly with v2_invalid",
	)
	println()

	println("[SCENARIO] 11. Staker Contract Upgrade to v3_valid")
	upgradeStakerContractToV3Valid(cur)
	println()

	println("[SCENARIO] 11-1. Validate the v1 staking data exactly, before collecting again")
	validateExactAfterUpgrade()
	println()

	println("[SCENARIO] 12. Check staking info after upgrade to v3_valid")
	checkStakingInfo(cur, positionId)
	println()

	println("[SCENARIO] 13. Collect reward with v3_valid")
	collectReward(cur, positionId)
	println()

	println("[SCENARIO] 14. Check staking info after reward collection")
	checkStakingInfo(cur, positionId)
	println()

	println("[SCENARIO] 15. Validate the reward ledgers after the post-upgrade collection")
	validateAccrualAfterUpgrade()
	println()
}

func captureV1Snapshot() {
	v1DepositOwner = staker.GetDepositOwner(positionId)
	v1DepositPoolPath = staker.GetDepositTargetPoolPath(positionId)
	v1DepositLiquidity = staker.GetDepositLiquidityAsString(positionId)
	v1DepositStakeTime = staker.GetDepositStakeTime(positionId)
	v1DepositTickLower = staker.GetDepositTickLower(positionId)
	v1DepositTickUpper = staker.GetDepositTickUpper(positionId)
	v1DepositWarmupCount = len(staker.GetDepositWarmUp(positionId))
	v1CollectedInternal = staker.GetDepositCollectedInternalReward(positionId)
	v1PoolTier = staker.GetPoolTier(barFoo500PoolPath)
	v1PoolTierRatio = staker.GetPoolTierRatio(barFoo500PoolPath)
	v1PoolStakedLiq = staker.GetPoolStakedLiquidity(barFoo500PoolPath)
	v1UnstakingFee = staker.GetUnstakingFee()
	v1DepositGnsAmount = staker.GetDepositGnsAmount()
	v1AllowedTokenCount = len(staker.GetAllowedTokens())
	v1TotalEmissionSent = staker.GetTotalEmissionSent()

	println("[EXPECTED] Deposit owner:", v1DepositOwner)
	println("[EXPECTED] Deposit liquidity:", v1DepositLiquidity)
	println("[EXPECTED] Deposit ticks:", v1DepositTickLower, v1DepositTickUpper)
	println("[EXPECTED] Deposit warmup tiers:", v1DepositWarmupCount)
	println("[EXPECTED] Collected internal reward so far:", v1CollectedInternal)
	println("[EXPECTED] Pool tier / ratio:", v1PoolTier, v1PoolTierRatio)
	println("[EXPECTED] Pool staked liquidity:", v1PoolStakedLiq)
	println("[EXPECTED] Unstaking fee / deposit GNS amount:", v1UnstakingFee, v1DepositGnsAmount)
	println("[EXPECTED] Allowed token count:", v1AllowedTokenCount)
	println("[EXPECTED] Total emission sent:", v1TotalEmissionSent)

	// the deposit must mirror the staked position and already have collected
	// a non-zero internal reward
	uassert.Equal(t, barFoo500PoolPath, v1DepositPoolPath)
	uassert.Equal(t, v1DepositLiquidity, v1PoolStakedLiq)
	uassert.True(t, v1CollectedInternal > 0)
	uassert.Equal(t, uint64(1), v1PoolTier)
}

// validateExactAfterUpgrade runs before any post-upgrade collection, so the
// reward ledgers must still hold exactly their v1 values. Checking only that
// they grew, after a fresh collection, would let a reset-then-refilled ledger
// pass.
func validateExactAfterUpgrade() {
	uassert.Equal(t, v1DepositOwner, staker.GetDepositOwner(positionId))
	uassert.Equal(t, v1DepositPoolPath, staker.GetDepositTargetPoolPath(positionId))
	uassert.Equal(t, v1DepositLiquidity, staker.GetDepositLiquidityAsString(positionId))
	uassert.Equal(t, v1DepositStakeTime, staker.GetDepositStakeTime(positionId))
	uassert.Equal(t, v1DepositTickLower, staker.GetDepositTickLower(positionId))
	uassert.Equal(t, v1DepositTickUpper, staker.GetDepositTickUpper(positionId))
	uassert.Equal(t, v1DepositWarmupCount, len(staker.GetDepositWarmUp(positionId)))
	uassert.Equal(t, v1CollectedInternal, staker.GetDepositCollectedInternalReward(positionId))
	uassert.Equal(t, v1TotalEmissionSent, staker.GetTotalEmissionSent())
	uassert.Equal(t, v1PoolTier, staker.GetPoolTier(barFoo500PoolPath))
	uassert.Equal(t, v1PoolTierRatio, staker.GetPoolTierRatio(barFoo500PoolPath))
	uassert.Equal(t, v1PoolStakedLiq, staker.GetPoolStakedLiquidity(barFoo500PoolPath))
	uassert.Equal(t, v1UnstakingFee, staker.GetUnstakingFee())
	uassert.Equal(t, v1DepositGnsAmount, staker.GetDepositGnsAmount())
	uassert.Equal(t, v1AllowedTokenCount, len(staker.GetAllowedTokens()))
	uassert.True(t, staker.IsStaked(positionId))

	println("[EXPECTED] Every snapshot field matches exactly right after the upgrade")
	println("[EXPECTED] Collected internal reward:", staker.GetDepositCollectedInternalReward(positionId))
	println("[EXPECTED] Total emission sent:", staker.GetTotalEmissionSent())
}

func validateAccrualAfterUpgrade() {
	// deposit identity is immutable across upgrades
	uassert.Equal(t, v1DepositOwner, staker.GetDepositOwner(positionId))
	uassert.Equal(t, v1DepositPoolPath, staker.GetDepositTargetPoolPath(positionId))
	uassert.Equal(t, v1DepositLiquidity, staker.GetDepositLiquidityAsString(positionId))
	uassert.Equal(t, v1DepositStakeTime, staker.GetDepositStakeTime(positionId))
	uassert.Equal(t, v1DepositTickLower, staker.GetDepositTickLower(positionId))
	uassert.Equal(t, v1DepositTickUpper, staker.GetDepositTickUpper(positionId))
	uassert.Equal(t, v1DepositWarmupCount, len(staker.GetDepositWarmUp(positionId)))
	uassert.Equal(t, v1PoolTier, staker.GetPoolTier(barFoo500PoolPath))
	uassert.Equal(t, v1PoolTierRatio, staker.GetPoolTierRatio(barFoo500PoolPath))
	uassert.Equal(t, v1PoolStakedLiq, staker.GetPoolStakedLiquidity(barFoo500PoolPath))
	uassert.Equal(t, v1UnstakingFee, staker.GetUnstakingFee())
	uassert.Equal(t, v1DepositGnsAmount, staker.GetDepositGnsAmount())
	uassert.Equal(t, v1AllowedTokenCount, len(staker.GetAllowedTokens()))
	uassert.True(t, staker.IsStaked(positionId))

	// reward ledgers only ever move forward
	uassert.True(t, staker.GetDepositCollectedInternalReward(positionId) > v1CollectedInternal)
	uassert.True(t, staker.GetTotalEmissionSent() > v1TotalEmissionSent)

	println("[EXPECTED] Deposit identity data is unchanged after the upgrades")
	println("[EXPECTED] Collected internal reward grew from", v1CollectedInternal,
		"to", staker.GetDepositCollectedInternalReward(positionId))
	println("[EXPECTED] Total emission sent grew from", v1TotalEmissionSent,
		"to", staker.GetTotalEmissionSent())
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	staker.UpgradeImpl(cross(cur), stakerV1Path)
	println("[EXPECTED] Initialized staker contract with v1:", stakerV1Path)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+5)
	testing.SkipHeights(1)
}

func createPool(cur realm, barPath, fooPath string, fee uint32, sqrtPriceX96 string) {
	println("[INFO] Create pool")
	testing.SetRealm(adminRealm)

	pool.CreatePool(cross(cur), barPath, fooPath, fee, sqrtPriceX96)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee)

	println("[EXPECTED] Created pool path:", poolPath)

	staker.SetPoolTier(cross(cur), poolPath, 1)
	testing.SkipHeights(1)
}

func mintPosition(cur realm, barPath, fooPath string, fee uint32, tickLower, tickUpper int32, amount0Desired, amount1Desired string, amount0Min, amount1Min string, deadline int64, recipient, operator address) {
	println("[INFO] Mint position")

	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	positionId, liquidity, amount0, amount1 := position.Mint(cross(cur), barPath, fooPath, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, adminAddr, "")
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Liquidity:", liquidity)
	println("[EXPECTED] Amount0:", amount0)
	println("[EXPECTED] Amount1:", amount1)
}

func setPoolTier(cur realm, poolPath string, tier uint64) {
	println("[INFO] Set pool tier")
	testing.SetRealm(adminRealm)

	staker.SetPoolTier(cross(cur), poolPath, tier)
	println("[EXPECTED] Pool tier set to:", tier)
}

func stakePosition(cur realm, positionId uint64) {
	println("[INFO] Stake position")
	testing.SetRealm(adminRealm)

	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.FormatUint(positionId, 10)))

	lpTokenId := staker.StakeToken(cross(cur), positionId, "")
	println("[EXPECTED] Staked position ID:", positionId)
	println("[EXPECTED] LP Token ID:", lpTokenId)
}

func collectReward(cur realm, positionId uint64) {
	println("[INFO] Collect reward")
	testing.SetRealm(adminRealm)

	rewardToUser, rewardPenalty, _, _ := staker.CollectReward(cross(cur), positionId)
	rewardToUserInt, _ := strconv.ParseInt(rewardToUser, 10, 64)
	rewardPenaltyInt, _ := strconv.ParseInt(rewardPenalty, 10, 64)

	println("[EXPECTED] Total reward amount:", rewardToUserInt+rewardPenaltyInt)
	println("[EXPECTED] Reward to user:", rewardToUser)
	println("[EXPECTED] Reward penalty:", rewardPenalty)
}

func checkStakingInfo(cur realm, positionId uint64) {
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

func waitBlocks(cur realm, n int) {
	println("[INFO] Waiting", n, "blocks")
	testing.SkipHeights(10)
}

func upgradeStakerContractToV2Invalid(cur realm) {
	println("[INFO] Upgrade staker contract to v2_invalid")
	testing.SetRealm(adminRealm)

	staker.UpgradeImpl(cross(cur), stakerV2InvalidPath)
	println("[EXPECTED] Upgraded staker contract to v2_invalid:", stakerV2InvalidPath)
}

func upgradeStakerContractToV3Valid(cur realm) {
	println("[INFO] Upgrade staker contract to v3_valid")
	testing.SetRealm(adminRealm)

	staker.UpgradeImpl(cross(cur), stakerV3ValidPath)
	println("[EXPECTED] Upgraded staker contract to v3_valid:", stakerV3ValidPath)
}

func withAbortsWithMessage(cur realm, callback func(), logMessage string) {
	uassert.AbortsContains(t, cur, "implementation", func() {
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
// [EXPECTED] Created pool path: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
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
// [EXPECTED] LP Token ID: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
//
// [SCENARIO] 6. Wait 10 blocks for reward accumulation
// [INFO] Waiting 10 blocks
// [INFO] Collect reward
// [EXPECTED] Total reward amount: 133374323
// [EXPECTED] Reward to user: 39731368
// [EXPECTED] Reward penalty: 93642955
//
// [SCENARIO] 7. Check staking info before upgrade
// [INFO] Check staking info
// [EXPECTED] Is staked: true
// [EXPECTED] Target pool path: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Staked liquidity: 1066918731
// [EXPECTED] Stake time: 1234567900
//
// [SCENARIO] 7-1. Snapshot the staking state written by v1
// [EXPECTED] Deposit owner: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [EXPECTED] Deposit liquidity: 1066918731
// [EXPECTED] Deposit ticks: -960 960
// [EXPECTED] Deposit warmup tiers: 4
// [EXPECTED] Collected internal reward so far: 133775649
// [EXPECTED] Pool tier / ratio: 1 100
// [EXPECTED] Pool staked liquidity: 1066918731
// [EXPECTED] Unstaking fee / deposit GNS amount: 100 1000000000
// [EXPECTED] Allowed token count: 2
// [EXPECTED] Total emission sent: 146751888
//
// [SCENARIO] 8. Staker Contract Upgrade to v2_invalid
// [INFO] Upgrade staker contract to v2_invalid
// [EXPECTED] Upgraded staker contract to v2_invalid: gno.land/r/gnoswap/staker/v2_invalid
//
// [SCENARIO] 9. Collect reward with v2_invalid (should panic)
// [INFO] Waiting 10 blocks
// [INFO] Collect reward
// [EXPECTED] Collect reward panics correctly with v2_invalid
//
// [SCENARIO] 10. Check staking info with v2_invalid (should panic)
// [INFO] Check staking info
// [EXPECTED] Check staking info panics correctly with v2_invalid
//
// [SCENARIO] 11. Staker Contract Upgrade to v3_valid
// [INFO] Upgrade staker contract to v3_valid
// [EXPECTED] Upgraded staker contract to v3_valid: gno.land/r/gnoswap/staker/v3_valid
//
// [SCENARIO] 11-1. Validate the v1 staking data exactly, before collecting again
// [EXPECTED] Every snapshot field matches exactly right after the upgrade
// [EXPECTED] Collected internal reward: 133775649
// [EXPECTED] Total emission sent: 146751888
//
// [SCENARIO] 12. Check staking info after upgrade to v3_valid
// [INFO] Check staking info
// [EXPECTED] Is staked: true
// [EXPECTED] Target pool path: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Staked liquidity: 1066918731
// [EXPECTED] Stake time: 1234567900
//
// [SCENARIO] 13. Collect reward with v3_valid
// [INFO] Collect reward
// [EXPECTED] Total reward amount: 133374324
// [EXPECTED] Reward to user: 39731369
// [EXPECTED] Reward penalty: 93642955
//
// [SCENARIO] 14. Check staking info after reward collection
// [INFO] Check staking info
// [EXPECTED] Is staked: true
// [EXPECTED] Target pool path: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Staked liquidity: 1066918731
// [EXPECTED] Stake time: 1234567900
//
// [SCENARIO] 15. Validate the reward ledgers after the post-upgrade collection
// [EXPECTED] Deposit identity data is unchanged after the upgrades
// [EXPECTED] Collected internal reward grew from 133775649 to 267551299
// [EXPECTED] Total emission sent grew from 146751888 to 280126212
