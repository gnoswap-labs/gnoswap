// warmup period penalty scenario test - verifies that rewards are reduced during warmup
// and penalties are properly distributed to community pool

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _    = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _      = access.GetAddress(prabc.ROLE_POOL.String())
	govAddr, _       = access.GetAddress(prabc.ROLE_GOVERNANCE.String())
	devOpsAddr, _    = access.GetAddress(prabc.ROLE_DEVOPS.String())
	communityAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"

	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999
	maxInt64    int64 = 9223372036854775807

	blockTimeSeconds             int64 = 5
	warmupPenaltyDurationSeconds int64 = 1800 + 3600 + 7200
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pool and set tier")
	createPoolAndSetTier()
	println()

	println("[SCENARIO] 3. Mint large position")
	positionId := mintLargePosition()
	println()

	println("[SCENARIO] 4. Stake position and record time")
	stakeTime := stakePosition(positionId)
	println()

	println("[SCENARIO] 5. Skip one hour within warmup period")
	skipTimeWithinWarmup()
	println()

	println("[SCENARIO] 6. Collect rewards during warmup and verify penalty")
	collectRewardsAndVerifyPenalty(positionId, stakeTime)
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] set emission start time")
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	println("[INFO] set unstaking fee to 5%")
	testing.SetRealm(testing.NewUserRealm(govAddr))
	sr.SetUnStakingFee(cross, 500) // 5% fee

	testing.SetRealm(adminRealm)
	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] mint and distribute initial GNS")
	emission.MintAndDistributeGns(cross)
	emission.MintAndDistributeGns(cross)

	ufmt.Printf("[EXPECTED] initialization completed\n")
	testing.SkipHeights(1)
}

func createPoolAndSetTier() {
	testing.SetRealm(adminRealm)

	println("[INFO] create atom:atone:3000 pool")
	pl.CreatePool(cross, atomPath, atonePath, fee3000, "79228162514264337593543950336")
	poolPath := pl.GetPoolPath(atomPath, atonePath, fee3000)

	println("[INFO] set pool to tier 1")
	sr.SetPoolTier(cross, poolPath, 1)

	println("[INFO] set warmup period tiers")
	// Set up warmup tiers with the last one having MaxInt64
	sr.SetWarmUp(cross, 30, 1800)                 // 30% reduction for 30 minutes
	sr.SetWarmUp(cross, 50, 3600)                 // 50% reduction for 1 hour
	sr.SetWarmUp(cross, 70, 7200)                 // 70% reduction for 2 hours
	sr.SetWarmUp(cross, 100, 9223372036854775807) // 100% (no reduction) after 2 hours

	ufmt.Printf("[EXPECTED] pool created and configured with warmup period\n")
	testing.SkipHeights(1)
}

func mintLargePosition() uint64 {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	atom.Approve(cross, poolAddr, maxInt64)
	atone.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint large position for meaningful rewards")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		atomPath,       // token0
		atonePath,       // token1
		fee3000,       // fee
		int32(-18000), // tickLower
		int32(18000),  // tickUpper
		"100000000",   // amount0Desired - large amount
		"100000000",   // amount1Desired - large amount
		"0",           // amount0Min
		"0",           // amount1Min
		max_timeout,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position minted: ID=%d, liquidity=%s\n", positionId, liquidity)

	// Verify ownership
	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	if owner != adminAddr {
		panic("position should be owned by admin")
	}

	testing.SkipHeights(1)
	return positionId
}

func stakePosition(positionId uint64) int64 {
	testing.SetRealm(adminRealm)

	println("[INFO] approve and stake position")
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))

	stakeTime := time.Now().Unix()
	sr.StakeToken(cross, positionId, "")

	ufmt.Printf("[EXPECTED] position staked at time: %d\n", stakeTime)
	testing.SkipHeights(1)

	return stakeTime
}

func skipTimeWithinWarmup() {
	blocksToSkip := int64(3600) / blockTimeSeconds
	println("[INFO] skip 1 hour (720 blocks) - staying within warmup period")
	testing.SkipHeights(blocksToSkip)

	currentTime := time.Now().Unix()
	ufmt.Printf("[EXPECTED] current time advanced to: %d\n", currentTime)
}

func collectRewardsAndVerifyPenalty(positionId uint64, stakeTime int64) {
	testing.SetRealm(adminRealm)

	println("[INFO] check time since stake")
	currentTime := time.Now().Unix()
	timeSinceStake := currentTime - stakeTime
	ufmt.Printf("[INFO] time since stake: %d seconds (warmup penalty period: %d seconds)\n", timeSinceStake, warmupPenaltyDurationSeconds)
	if timeSinceStake >= warmupPenaltyDurationSeconds {
		panic("collection should happen during warmup penalty period")
	}

	println("[INFO] record balances before collection")
	userGnsBefore := gns.BalanceOf(adminUser)
	communityGnsBefore := gns.BalanceOf(communityAddr)
	devOpsGnsBefore := gns.BalanceOf(devOpsAddr)

	ufmt.Printf("[INFO] user GNS before: %d\n", userGnsBefore)
	ufmt.Printf("[INFO] community GNS before: %d\n", communityGnsBefore)
	ufmt.Printf("[INFO] devOps GNS before: %d\n", devOpsGnsBefore)

	println("[INFO] collect rewards during warmup period")
	internalRewardToUserStr, internalWarmupPenaltyStr, _, _ := sr.CollectReward(cross, positionId)
	internalRewardToUser := mustParseInt64(internalRewardToUserStr)
	internalWarmupPenalty := mustParseInt64(internalWarmupPenaltyStr)

	println("[INFO] check balances after collection")
	userGnsAfter := gns.BalanceOf(adminUser)
	communityGnsAfter := gns.BalanceOf(communityAddr)
	devOpsGnsAfter := gns.BalanceOf(devOpsAddr)

	userReward := userGnsAfter - userGnsBefore
	communityReward := communityGnsAfter - communityGnsBefore
	devOpsReward := devOpsGnsAfter - devOpsGnsBefore
	communityEmissionReward := communityReward - internalWarmupPenalty

	ufmt.Printf("[EXPECTED] user reward (reduced by warmup and fee): %d GNS\n", userReward)
	ufmt.Printf("[EXPECTED] warmup penalty: %d GNS\n", internalWarmupPenalty)
	ufmt.Printf("[EXPECTED] community pool total increase: %d GNS\n", communityReward)
	ufmt.Printf("[EXPECTED] community pool emission distribution: %d GNS\n", communityEmissionReward)
	ufmt.Printf("[EXPECTED] devOps reward: %d GNS\n", devOpsReward)

	println("[INFO] verify total distribution")
	totalDistributed := userReward + internalWarmupPenalty
	ufmt.Printf("[EXPECTED] total distributed (user + warmup penalty): %d GNS\n", totalDistributed)

	if totalDistributed == 0 {
		panic("total distributed should be positive - rewards should have been generated")
	}

	if userReward != internalRewardToUser {
		panic("user balance delta should match CollectReward return value")
	}

	if internalWarmupPenalty == 0 {
		panic("community pool should receive penalty during warmup period")
	}
	if communityReward < internalWarmupPenalty {
		panic("community pool increase should include at least the warmup penalty")
	}
	ufmt.Printf("[VERIFIED] warmup penalty correctly applied - penalty amount: %d GNS\n", internalWarmupPenalty)

	println("[INFO] warmup period penalty test completed successfully")
}

func mustParseInt64(value string) int64 {
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		panic(err)
	}
	return parsed
}

func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic("positionId is nil")
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize and setup
// [INFO] set emission start time
// [INFO] set unstaking fee to 5%
// [INFO] set pool creation fee to 0
// [INFO] mint and distribute initial GNS
// [EXPECTED] initialization completed
//
// [SCENARIO] 2. Create pool and set tier
// [INFO] create atom:atone:3000 pool
// [INFO] set pool to tier 1
// [INFO] set warmup period tiers
// [EXPECTED] pool created and configured with warmup period
//
// [SCENARIO] 3. Mint large position
// [INFO] approve tokens for minting
// [INFO] mint large position for meaningful rewards
// [EXPECTED] position minted: ID=1, liquidity=168516970
//
// [SCENARIO] 4. Stake position and record time
// [INFO] approve and stake position
// [EXPECTED] position staked at time: 1234567905
//
// [SCENARIO] 5. Skip one hour within warmup period
// [INFO] skip 1 hour (720 blocks) - staying within warmup period
// [EXPECTED] current time advanced to: 1234571510
//
// [SCENARIO] 6. Collect rewards during warmup and verify penalty
// [INFO] check time since stake
// [INFO] time since stake: 3605 seconds (warmup penalty period: 12600 seconds)
// [INFO] record balances before collection
// [INFO] user GNS before: 100000000000000
// [INFO] community GNS before: 5351025
// [INFO] devOps GNS before: 21404109
// [INFO] collect rewards during warmup period
// [INFO] check balances after collection
// [EXPECTED] user reward (reduced by warmup and fee): 3666456126 GNS
// [EXPECTED] warmup penalty: 5785796862 GNS
// [EXPECTED] community pool total increase: 7098582207 GNS
// [EXPECTED] community pool emission distribution: 1312785345 GNS
// [EXPECTED] devOps reward: 5144120863 GNS
// [INFO] verify total distribution
// [EXPECTED] total distributed (user + warmup penalty): 9452252988 GNS
// [VERIFIED] warmup penalty correctly applied - penalty amount: 5785796862 GNS
// [INFO] warmup period penalty test completed successfully
