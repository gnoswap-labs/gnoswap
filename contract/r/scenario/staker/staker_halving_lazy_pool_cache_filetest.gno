// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/scenarioutils"
	sr "gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/rbac"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

const (
	halvingCacheBlockTime int64  = 5
	halvingCachePoolPath  string = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:3000"
)

var (
	halvingCacheAdminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	halvingCacheAdminRealm   = testing.NewUserRealm(halvingCacheAdminAddr)
	halvingCacheStakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	halvingCachePoolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())

	halvingCacheMaxTimeout int64 = 9999999999
	halvingCacheMaxInt64   int64 = 9223372036854775807
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize emission and pool")
	initHalvingCacheScenario(cur)
	println("[EXPECTED] initialized staker halving cache scenario")
	println()

	println("[SCENARIO] 2. Stake position and cache pre-halving reward")
	stakeHalvingCachePosition(cur)
	preHalvingReward := cacheBeforeHalving(cur)
	println("[EXPECTED] pre-halving pool reward cache uses year 1 pool reward")
	println()

	println("[SCENARIO] 3. Cross first halving boundary and collect once")
	skipToFirstHalving(cur)
	firstPostHalvingReward := collectAndAssertLatestCache(cur, "first post-halving")
	assertHalvingReducedPoolReward(preHalvingReward, firstPostHalvingReward)
	println("[EXPECTED] first post-halving collect persisted the reduced pool reward")
	println()

	println("[SCENARIO] 4. Collect again after halving")
	testing.SkipHeights(1)
	secondPostHalvingReward := collectAndAssertLatestCache(cur, "second post-halving")
	if secondPostHalvingReward != firstPostHalvingReward {
		panic("post-halving pool reward changed without another halving")
	}
	println("[EXPECTED] second post-halving collect persisted the reduced pool reward")
}

func initHalvingCacheScenario(cur realm) {
	testing.SetRealm(halvingCacheAdminRealm)
	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	emission.ChangeDistributionPct(cross(cur), 7500, 2500, 0, 0)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	testing.SkipHeights(1)
	emission.MintAndDistributeGns(cross(cur))

	pl.CreatePool(cross(cur), "gno.land/r/onbloc/bar.BAR", "gno.land/r/onbloc/baz.BAZ", 3000, "79228162514264337593543950337")
	sr.SetPoolTier(cross(cur), halvingCachePoolPath, 1)
}

func stakeHalvingCachePosition(cur realm) {
	testing.SetRealm(halvingCacheAdminRealm)
	bar.Approve(cross(cur), halvingCachePoolAddr, halvingCacheMaxInt64)
	baz.Approve(cross(cur), halvingCachePoolAddr, halvingCacheMaxInt64)

	positionId, _, _, _ := pn.Mint(
		cross(cur),
		"gno.land/r/onbloc/bar.BAR",
		"gno.land/r/onbloc/baz.BAZ",
		3000,
		int32(-1020),
		int32(1020),
		"1000000",
		"1000000",
		"1",
		"1",
		halvingCacheMaxTimeout,
		halvingCacheAdminAddr,
		"",
	)
	if positionId != 1 {
		panic("unexpected position id")
	}

	gnft.Approve(cross(cur), halvingCacheStakerAddr, halvingCachePositionIdFrom(positionId))
	sr.StakeToken(cross(cur), positionId, "")
}

func cacheBeforeHalving(cur realm) int64 {
	testing.SetRealm(halvingCacheAdminRealm)
	testing.SkipHeights(10)
	sr.CollectReward(cross(cur), 1)

	if gns.GetCurrentYear() != 1 {
		panic("expected pre-halving year 1")
	}
	return assertLatestPoolRewardCacheMatchesCurrentPoolReward("pre-halving")
}

func skipToFirstHalving(cur realm) {
	testing.SetRealm(halvingCacheAdminRealm)
	year3Start := gns.GetHalvingYearStartTimestamp(3)
	now := time.Now().Unix()
	if now >= year3Start {
		panic("test setup already passed first halving")
	}

	blocksToYear3 := (year3Start-now)/halvingCacheBlockTime + 2
	testing.SkipHeights(blocksToYear3)

	if gns.GetCurrentYear() != 3 {
		panic("expected first halving to enter year 3")
	}
	println("[INFO] crossed to halving year:", gns.GetCurrentYear())
}

func collectAndAssertLatestCache(cur realm, label string) int64 {
	sr.CollectReward(cross(cur), 1)
	return assertLatestPoolRewardCacheMatchesCurrentPoolReward(label)
}

func assertLatestPoolRewardCacheMatchesCurrentPoolReward(label string) int64 {
	latestCache := latestPoolRewardCache()
	currentPoolReward := sr.GetPoolReward(1)
	println("[INFO]", label, "pool reward cache:", latestCache)
	println("[INFO]", label, "current pool reward:", currentPoolReward)
	if latestCache != currentPoolReward {
		panic("pool reward cache did not use the latest halving pool reward")
	}
	return latestCache
}

func assertHalvingReducedPoolReward(before, after int64) {
	if after >= before {
		panic("halving did not reduce the pool reward")
	}
	println("[INFO] halving reduced pool reward from", before, "to", after)
}

func latestPoolRewardCache() int64 {
	count := int(sr.GetPoolRewardCacheCount(halvingCachePoolPath))
	if count == 0 {
		panic("pool reward cache is empty")
	}

	// Cache keys are zero-padded timestamps, so the last entry is the latest one.
	latestId := int64(-1)
	sr.GetPoolRewardCaches(halvingCachePoolPath).ReverseIterateByOffset(0, 1, func(key string, _ any) bool {
		latestId = sr.DecodeInt64(key)
		return true
	})

	if latestId < 0 {
		panic("pool reward cache ids not found")
	}

	return sr.GetPoolRewardCache(halvingCachePoolPath, uint64(latestId))
}

func halvingCachePositionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Initialize emission and pool
// [EXPECTED] initialized staker halving cache scenario
//
// [SCENARIO] 2. Stake position and cache pre-halving reward
// [INFO] pre-halving pool reward cache: 2675513
// [INFO] pre-halving current pool reward: 2675513
// [EXPECTED] pre-halving pool reward cache uses year 1 pool reward
//
// [SCENARIO] 3. Cross first halving boundary and collect once
// [INFO] crossed to halving year: 3
// [INFO] first post-halving pool reward cache: 1337756
// [INFO] first post-halving current pool reward: 1337756
// [INFO] halving reduced pool reward from 2675513 to 1337756
// [EXPECTED] first post-halving collect persisted the reduced pool reward
//
// [SCENARIO] 4. Collect again after halving
// [INFO] second post-halving pool reward cache: 1337756
// [INFO] second post-halving current pool reward: 1337756
// [EXPECTED] second post-halving collect persisted the reduced pool reward
