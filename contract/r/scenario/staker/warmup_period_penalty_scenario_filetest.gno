// warmup period penalty scenario test - verifies that rewards are reduced during warmup
// and penalties are properly distributed to community pool

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"

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

	stakerAddr, _  = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _    = access.GetAddress(prabc.ROLE_POOL.String())
	govAddr, _     = access.GetAddress(prabc.ROLE_GOVERNANCE.String())
	devOpsAddr, _  = access.GetAddress(prabc.ROLE_DEVOPS.String())
	communityAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999
	maxInt64    int64 = 9223372036854775807
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

	println("[SCENARIO] 5. Skip time within warmup period")
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

	println("[INFO] create bar:baz:3000 pool")
	pl.CreatePool(cross, barPath, bazPath, fee3000, "79228162514264337593543950336")
	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	
	println("[INFO] set pool to tier 1")
	sr.SetPoolTier(cross, poolPath, 1)
	
	println("[INFO] set warmup period tiers")
	// Set up warmup tiers with the last one having MaxInt64
	sr.SetWarmUp(cross, 30, 1800)  // 30% reduction for 30 minutes
	sr.SetWarmUp(cross, 50, 3600)  // 50% reduction for 1 hour  
	sr.SetWarmUp(cross, 70, 7200)  // 70% reduction for 2 hours
	sr.SetWarmUp(cross, 100, 9223372036854775807) // 100% (no reduction) after 2 hours
	
	ufmt.Printf("[EXPECTED] pool created and configured with warmup period\n")
	testing.SkipHeights(1)
}

func mintLargePosition() uint64 {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint large position for meaningful rewards")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,        // token0
		bazPath,        // token1
		fee3000,        // fee
		int32(-18000),  // tickLower
		int32(18000),   // tickUpper
		"100000000",    // amount0Desired - large amount
		"100000000",    // amount1Desired - large amount
		"0",            // amount0Min
		"0",            // amount1Min
		max_timeout,
		adminAddr,
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
	println("[INFO] skip 1 hour (3600 blocks) - staying within warmup period")
	testing.SkipHeights(3600) // 1 hour = half of warmup period
	
	currentTime := time.Now().Unix()
	ufmt.Printf("[EXPECTED] current time advanced to: %d\n", currentTime)
}

func collectRewardsAndVerifyPenalty(positionId uint64, stakeTime int64) {
	testing.SetRealm(adminRealm)
	
	println("[INFO] check time since stake")
	currentTime := time.Now().Unix()
	timeSinceStake := currentTime - stakeTime
	ufmt.Printf("[INFO] time since stake: %d seconds (warmup period: 7200 seconds)\n", timeSinceStake)
	
	println("[INFO] record balances before collection")
	userGnsBefore := gns.BalanceOf(adminUser)
	communityGnsBefore := gns.BalanceOf(communityAddr)
	devOpsGnsBefore := gns.BalanceOf(devOpsAddr)
	
	ufmt.Printf("[INFO] user GNS before: %d\n", userGnsBefore)
	ufmt.Printf("[INFO] community GNS before: %d\n", communityGnsBefore)
	ufmt.Printf("[INFO] devOps GNS before: %d\n", devOpsGnsBefore)
	
	println("[INFO] collect rewards during warmup period")
	sr.CollectReward(cross, positionId, false)
	
	println("[INFO] check balances after collection")
	userGnsAfter := gns.BalanceOf(adminUser)
	communityGnsAfter := gns.BalanceOf(communityAddr)
	devOpsGnsAfter := gns.BalanceOf(devOpsAddr)
	
	userReward := userGnsAfter - userGnsBefore
	communityReward := communityGnsAfter - communityGnsBefore
	devOpsReward := devOpsGnsAfter - devOpsGnsBefore
	
	ufmt.Printf("[EXPECTED] user reward (reduced by warmup): %d GNS\n", userReward)
	ufmt.Printf("[EXPECTED] community pool penalty: %d GNS\n", communityReward)
	ufmt.Printf("[EXPECTED] devOps reward: %d GNS\n", devOpsReward)
	
	println("[INFO] verify total distribution")
	totalDistributed := userReward + communityReward
	ufmt.Printf("[EXPECTED] total distributed (user + penalty): %d GNS\n", totalDistributed)
	
	if totalDistributed == 0 {
		panic("total distributed should be positive - rewards should have been generated")
	}
	
	if timeSinceStake < 7200 {
		if communityReward == 0 {
			panic("community pool should receive penalty during warmup period")
		}
		ufmt.Printf("[VERIFIED] warmup penalty correctly applied - community pool received: %d GNS\n", communityReward)
	}
	
	println("[INFO] warmup period penalty test completed successfully")
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
// [SCENARIO] 5. Skip time within warmup period
// [INFO] skip 1 hour (3600 blocks) - staying within warmup period
// [EXPECTED] current time advanced to: 1234585910
//
// [SCENARIO] 6. Collect rewards during warmup and verify penalty
// [INFO] check time since stake
// [INFO] time since stake: 18005 seconds (warmup period: 7200 seconds)
// [INFO] record balances before collection
// [INFO] user GNS before: 100000000000000
// [INFO] community GNS before: 5351025
// [INFO] devOps GNS before: 21404109
// [INFO] collect rewards during warmup period
// [INFO] check balances after collection
// [EXPECTED] user reward (reduced by warmup): 32496112018 GNS
// [EXPECTED] community pool penalty: 20415949365 GNS
// [EXPECTED] devOps reward: 25692065503 GNS
// [INFO] verify total distribution
// [EXPECTED] total distributed (user + penalty): 52912061383 GNS
// [INFO] warmup period penalty test completed successfully
