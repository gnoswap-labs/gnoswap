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
	halvingCachePoolPath  string = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000"
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

	println("[SCENARIO] 3. Cross first halving boundary and query once")
	skipToFirstHalving(cur)
	firstPostHalvingReward := queryAndAssertLatestCache()
	assertHalvingReducedPoolReward(preHalvingReward, firstPostHalvingReward)
	println("[EXPECTED] first post-halving query synced pool reward cache")
	println()

	println("[SCENARIO] 4. Query again after halving")
	testing.SkipHeights(1)
	secondPostHalvingReward := queryAndAssertLatestCache()
	if secondPostHalvingReward != firstPostHalvingReward {
		panic("post-halving pool reward changed without another halving")
	}
	println("[EXPECTED] post-halving lazy cache kept latest pool reward")
}

func initHalvingCacheScenario(cur realm) {
	testing.SetRealm(halvingCacheAdminRealm)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	emission.ChangeDistributionPct(cross(cur), 7500, 2500, 0, 0)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	testing.SkipHeights(1)
	emission.MintAndDistributeGns(cross(cur))

	pl.CreatePool(cross(cur), "gno.land/r/onbloc/bar", "gno.land/r/onbloc/baz", 3000, "79228162514264337593543950337")
	sr.SetPoolTier(cross(cur), halvingCachePoolPath, 1)
}

func stakeHalvingCachePosition(cur realm) {
	testing.SetRealm(halvingCacheAdminRealm)
	bar.Approve(cross(cur), halvingCachePoolAddr, halvingCacheMaxInt64)
	baz.Approve(cross(cur), halvingCachePoolAddr, halvingCacheMaxInt64)

	positionId, _, _, _ := pn.Mint(
		cross(cur),
		"gno.land/r/onbloc/bar",
		"gno.land/r/onbloc/baz",
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
	sr.CollectableEmissionReward(1)

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

func queryAndAssertLatestCache() int64 {
	sr.CollectableEmissionReward(1)
	return assertLatestPoolRewardCacheMatchesCurrentPoolReward("post-halving")
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

	ids := sr.GetPoolRewardCacheIDs(halvingCachePoolPath, 0, count)
	if len(ids) == 0 {
		panic("pool reward cache ids not found")
	}

	latestId := ids[0]
	for _, id := range ids {
		if id > latestId {
			latestId = id
		}
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
// [SCENARIO] 3. Cross first halving boundary and query once
// [INFO] crossed to halving year: 3
// [INFO] post-halving pool reward cache: 1337756
// [INFO] post-halving current pool reward: 1337756
// [INFO] halving reduced pool reward from 2675513 to 1337756
// [EXPECTED] first post-halving query synced pool reward cache
//
// [SCENARIO] 4. Query again after halving
// [INFO] post-halving pool reward cache: 1337756
// [INFO] post-halving current pool reward: 1337756
// [EXPECTED] post-halving lazy cache kept latest pool reward
