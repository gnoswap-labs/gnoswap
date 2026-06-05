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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
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

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999
	maxInt64    int64 = 9223372036854775807

	blockTimeSeconds             int64 = 5
	warmupPenaltyDurationSeconds int64 = 1800 + 3600 + 7200
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Create pool and set tier")
	createPoolAndSetTier(cur)
	println()

	println("[SCENARIO] 3. Mint large position")
	positionId := mintLargePosition(cur)
	println()

	println("[SCENARIO] 4. Stake position and record time")
	stakeTime := stakePosition(cur, positionId)
	println()

	println("[SCENARIO] 5. Skip one hour within warmup period")
	skipTimeWithinWarmup(cur)
	println()

	println("[SCENARIO] 6. Collect rewards during warmup and verify penalty")
	collectRewardsAndVerifyPenalty(cur, positionId, stakeTime)
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] set emission start time")
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	println("[INFO] set unstaking fee to 5%")
	testing.SetRealm(testing.NewUserRealm(govAddr))
	sr.SetUnStakingFee(cross(cur), 500) // 5% fee

	testing.SetRealm(adminRealm)
	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross(cur), 0)

	println("[INFO] mint and distribute initial GNS")
	emission.MintAndDistributeGns(cross(cur))
	emission.MintAndDistributeGns(cross(cur))

	ufmt.Printf("[EXPECTED] initialization completed\n")
	testing.SkipHeights(1)
}

func createPoolAndSetTier(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:3000 pool")
	pl.CreatePool(cross(cur), barPath, bazPath, fee3000, "79228162514264337593543950336")
	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)

	println("[INFO] set pool to tier 1")
	sr.SetPoolTier(cross(cur), poolPath, 1)

	println("[INFO] set warmup period tiers")
	// Set up warmup tiers with the last one having MaxInt64
	sr.SetWarmUp(cross(cur), 30, 1800)                 // 30% reduction for 30 minutes
	sr.SetWarmUp(cross(cur), 50, 3600)                 // 50% reduction for 1 hour
	sr.SetWarmUp(cross(cur), 70, 7200)                 // 70% reduction for 2 hours
	sr.SetWarmUp(cross(cur), 100, 9223372036854775807) // 100% (no reduction) after 2 hours

	ufmt.Printf("[EXPECTED] pool created and configured with warmup period\n")
	testing.SkipHeights(1)
}

func mintLargePosition(cur realm) uint64 {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)

	println("[INFO] mint large position for meaningful rewards")
	positionId, liquidity, _, _ := pn.Mint(
		cross(cur),
		barPath,       // token0
		bazPath,       // token1
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
	owner := gnft.MustOwnerOf(positionIdFrom(cur, positionId))
	if owner != adminAddr {
		panic("position should be owned by admin")
	}

	testing.SkipHeights(1)
	return positionId
}

func stakePosition(cur realm, positionId uint64) int64 {
	testing.SetRealm(adminRealm)

	println("[INFO] approve and stake position")
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, positionId))

	stakeTime := time.Now().Unix()
	sr.StakeToken(cross(cur), positionId, "")

	ufmt.Printf("[EXPECTED] position staked at time: %d\n", stakeTime)
	testing.SkipHeights(1)

	return stakeTime
}

func skipTimeWithinWarmup(cur realm) {
	blocksToSkip := int64(3600) / blockTimeSeconds
	println("[INFO] skip 1 hour (720 blocks) - staying within warmup period")
	testing.SkipHeights(blocksToSkip)

	currentTime := time.Now().Unix()
	ufmt.Printf("[EXPECTED] current time advanced to: %d\n", currentTime)
}

func collectRewardsAndVerifyPenalty(cur realm, positionId uint64, stakeTime int64) {
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
	internalRewardToUserStr, internalWarmupPenaltyStr, _, _ := sr.CollectReward(cross(cur), positionId)
	internalRewardToUser := mustParseInt64(cur, internalRewardToUserStr)
	internalWarmupPenalty := mustParseInt64(cur, internalWarmupPenaltyStr)

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

func mustParseInt64(cur realm, value string) int64 {
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		panic(err)
	}
	return parsed
}

func positionIdFrom(cur realm, positionId any) grc721.TokenID {
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
// [INFO] create bar:baz:3000 pool
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
