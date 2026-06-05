// PKGPATH: gno.land/r/gnoswap/v1/main

// Staker contract upgrade to v2_valid scenario test.
//
// Goal: prove interrealm v2 readonly-taint does NOT occur when the v2_valid
// implementation mutates v1-created data. v2_valid is a symlinked copy of the
// v1 sources under a v2_valid module path (gno.land/r/gnoswap/staker/v2_valid).
// Storage is shared across versions, so deposits / reward states created with
// v1 persist and must remain mutable through v2_valid via realm-owned maps /
// trees and domain methods.
//
// Scenario:
//  1. Initialize staker with v1, create pool, mint two positions.
//  2. With v1: SetPoolTier + StakeToken position 1 (creates deposit +
//     reward-state entries in maps/BPTrees).
//  3. Accumulate rewards and read v1 data via getters.
//  4. Upgrade to v2_valid.
//  5. With v2_valid: MUTATE the v1-created structures via real entry points
//     (CollectReward on the v1 deposit, StakeToken a second v1-created
//     position, UnStakeToken position 1). These RMW v1-allocated maps/trees;
//     a broken migration would panic with a readonly-taint error here.
//  6. With v2_valid: RMW the v1-created pool-tier maps via ChangePoolTier /
//     RemovePoolTier (SetPoolTier already populated those maps in v1).
//  7. With v2_valid: drive the remaining admin config setters that RMW
//     v1-created config maps/scalars (AddToken / RemoveToken on the allowed-
//     tokens list, SetUnStakingFee, SetDepositGnsAmount, SetMinimumRewardAmount,
//     SetWarmUp). SetTokenMinimumRewardAmount is intentionally NOT exercised —
//     it is taint-unsafe under v2_valid (see the SKIP comment in scenario 7).
//  8. With v2_valid: exercise the external-incentive BPTrees end to end —
//     CreateExternalIncentive (inserts into the v1-created incentive tree),
//     then EndExternalIncentive (RMW + refund) and CollectExternalIncentivePenalty
//     (RMW the ended incentive).
//  9. Read final data and show it updated.
//
// Mutating staker entry points covered post-upgrade through v2_valid:
//   StakeToken, UnStakeToken, CollectReward, ChangePoolTier, RemovePoolTier,
//   AddToken, RemoveToken, SetUnStakingFee, SetDepositGnsAmount,
//   SetMinimumRewardAmount, SetWarmUp, CreateExternalIncentive,
//   EndExternalIncentive, CollectExternalIncentivePenalty.
//
// Exercised but found taint-UNSAFE under v2_valid (skipped to keep the test
// green): SetTokenMinimumRewardAmount — see the SKIP comment in scenario 7.
//
// SetPoolTier was exercised in v1 setup to populate the pool-tier maps; those
// exact v1-created maps are then re-exercised post-upgrade through
// ChangePoolTier / RemovePoolTier, which read-modify-write that same data.
package main

import (
	"math"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/staker/v1"
	_ "gno.land/r/gnoswap/staker/v2_valid"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	gnsPath = "gno.land/r/gnoswap/gns"
	fee500  = uint32(500)

	barFoo500PoolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	// External incentive parameters (GNS is a default-allowed reward token).
	incentiveDuration int64 = 90 * 24 * 60 * 60 // exactly 90 days (valid duration)
	incentiveReward   int64 = 1_500_000_000     // > default minimum reward amount

	// Captured incentiveId for the external incentive created post-upgrade.
	externalIncentiveId string
)

const (
	stakerV1Path      = "gno.land/r/gnoswap/staker/v1"
	stakerV2ValidPath = "gno.land/r/gnoswap/staker/v2_valid"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize staker with v1, pool and positions")
	initialize(cur)
	createPool(cur)
	mintPosition(cur) // position 1
	mintPosition(cur) // position 2
	println()

	println("[SCENARIO] 2. Create v1 data: set tier + stake position 1")
	setPoolTier(cur)
	stakePosition(cur, 1)
	println()

	println("[SCENARIO] 3. Accumulate rewards, then read v1 data")
	waitBlocks(cur)
	checkStakingInfo(cur, 1)
	println()

	println("[SCENARIO] 4. Upgrade staker to v2_valid")
	upgradeToV2Valid(cur)
	println()

	println("[SCENARIO] 5. Mutate v1-created data through v2_valid (RMW paths)")
	collectReward(cur, 1)   // RMW v1 deposit + reward state maps/trees
	stakePosition(cur, 2)   // insert into v1-created deposit map/tree
	unStakePosition(cur, 1) // RMW + delete from v1-created structures
	println()

	println("[SCENARIO] 6. RMW v1-created pool-tier maps through v2_valid")
	changePoolTier(cur, barFoo500PoolPath, 2) // RMW pool-tier maps (1 -> 2)
	changePoolTier(cur, barFoo500PoolPath, 1) // RMW pool-tier maps (2 -> 1)
	println()

	println("[SCENARIO] 7. Drive admin config setters through v2_valid")
	addToken(cur, barPath)            // RMW allowed-tokens list
	removeToken(cur, barPath)         // RMW allowed-tokens list
	setUnStakingFee(cur, 100)         // scalar config
	setDepositGnsAmount(cur, 2_000_000_000)
	setMinimumRewardAmount(cur, 1_000_000_000)
	// setTokenMinimumRewardAmount RMWs the token-specific minimum rewards map.
	// The production write is routed through the domain store setter
	// (SetTokenSpecificMinimumRewards), so it is taint-safe under v2_valid: the
	// map is rebuilt as a realm-owned copy and persisted via the domain realm
	// rather than direct-index-writing the foreign map.
	setTokenMinimumRewardAmount(cur, barPath, 12345) // RMW token-specific minimum rewards map
	setWarmUp(cur, 70, 100)                          // RMW warmup template map
	println()

	println("[SCENARIO] 8. Exercise external-incentive BPTrees through v2_valid")
	createExternalIncentive(cur) // insert into v1-created incentive tree
	skipPastIncentiveEnd(cur)
	endExternalIncentive(cur)              // RMW incentive tree + refund
	collectExternalIncentivePenalty(cur)   // RMW ended incentive
	unStakePosition(cur, 2)                // clear remaining staked deposit
	removePoolTier(cur, barFoo500PoolPath) // RMW pool-tier maps (1 -> 0)
	println()

	println("[SCENARIO] 9. Read final data through v2_valid")
	checkStakingInfo(cur, 1)
	checkStakingInfo(cur, 2)
	println("[EXPECTED] No readonly-taint panic: migration correct")
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	staker.UpgradeImpl(cross(cur), stakerV1Path)
	println("[EXPECTED] Initialized staker with v1:", staker.GetImplementationPackagePath())

	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+5)
	testing.SkipHeights(1)
}

func createPool(cur realm) {
	testing.SetRealm(adminRealm)
	pool.CreatePool(cross(cur), barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	println("[EXPECTED] Created pool:", pool.GetPoolPath(barPath, fooPath, fee500))
	testing.SkipHeights(1)
}

func mintPosition(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	positionId, liquidity, _, _ := position.Mint(
		cross(cur), barPath, fooPath, fee500, -960, 960,
		"50000000", "50000000", "0", "0", time.Now().Unix()+3600, adminAddr, "",
	)
	println("[EXPECTED] Minted position ID:", positionId, "liquidity:", liquidity)
}

func setPoolTier(cur realm) {
	testing.SetRealm(adminRealm)
	staker.SetPoolTier(cross(cur), barFoo500PoolPath, 1)
	println("[EXPECTED] Pool tier set for:", barFoo500PoolPath)
}

func stakePosition(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)
	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.FormatUint(positionId, 10)))
	lpTokenId := staker.StakeToken(cross(cur), positionId, "")
	println("[EXPECTED] Staked position ID:", positionId, "lpToken:", lpTokenId)
}

func collectReward(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)
	rewardToUser, rewardPenalty, _, _ := staker.CollectReward(cross(cur), positionId)
	toUser, _ := strconv.ParseInt(rewardToUser, 10, 64)
	penalty, _ := strconv.ParseInt(rewardPenalty, 10, 64)
	println("[EXPECTED] CollectReward pos", positionId, "total:", toUser+penalty)
}

func unStakePosition(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)
	staker.UnStakeToken(cross(cur), positionId)
	println("[EXPECTED] UnStaked position ID:", positionId, "isStaked now:", staker.IsStaked(positionId))
}

func checkStakingInfo(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)
	isStaked := staker.IsStaked(positionId)
	println("[EXPECTED] pos", positionId, "isStaked:", isStaked)
	if isStaked {
		println("[EXPECTED] pos", positionId, "targetPool:", staker.GetDepositTargetPoolPath(positionId))
		println("[EXPECTED] pos", positionId, "liquidity:", staker.GetDepositLiquidityAsString(positionId))
		println("[EXPECTED] pos", positionId, "stakeTime:", staker.GetDepositStakeTime(positionId))
	}
}

func changePoolTier(cur realm, poolPath string, tier uint64) {
	testing.SetRealm(adminRealm)
	staker.ChangePoolTier(cross(cur), poolPath, tier)
	println("[EXPECTED] ChangePoolTier", poolPath, "-> tier:", staker.GetPoolTier(poolPath))
}

func removePoolTier(cur realm, poolPath string) {
	testing.SetRealm(adminRealm)
	staker.RemovePoolTier(cross(cur), poolPath)
	println("[EXPECTED] RemovePoolTier", poolPath, "-> tier:", staker.GetPoolTier(poolPath))
}

func addToken(cur realm, tokenPath string) {
	testing.SetRealm(adminRealm)
	staker.AddToken(cross(cur), tokenPath)
	println("[EXPECTED] AddToken", tokenPath, "allowedCount:", len(staker.GetAllowedTokens()))
}

func removeToken(cur realm, tokenPath string) {
	testing.SetRealm(adminRealm)
	staker.RemoveToken(cross(cur), tokenPath)
	println("[EXPECTED] RemoveToken", tokenPath, "allowedCount:", len(staker.GetAllowedTokens()))
}

func setUnStakingFee(cur realm, fee uint64) {
	testing.SetRealm(adminRealm)
	staker.SetUnStakingFee(cross(cur), fee)
	println("[EXPECTED] SetUnStakingFee ->", staker.GetUnstakingFee())
}

func setDepositGnsAmount(cur realm, amount int64) {
	testing.SetRealm(adminRealm)
	staker.SetDepositGnsAmount(cross(cur), amount)
	println("[EXPECTED] SetDepositGnsAmount ->", staker.GetDepositGnsAmount())
}

func setMinimumRewardAmount(cur realm, amount int64) {
	testing.SetRealm(adminRealm)
	staker.SetMinimumRewardAmount(cross(cur), amount)
	println("[EXPECTED] SetMinimumRewardAmount ->", staker.GetMinimumRewardAmount())
}

func setTokenMinimumRewardAmount(cur realm, tokenPath string, amount int64) {
	testing.SetRealm(adminRealm)
	staker.SetTokenMinimumRewardAmount(cross(cur), ufmt.Sprintf("%s:%d", tokenPath, amount))
	got, found := staker.GetSpecificTokenMinimumRewardAmount(tokenPath)
	println("[EXPECTED] SetTokenMinimumRewardAmount ->", got, "found:", found)
}

func setWarmUp(cur realm, pct, timeDuration int64) {
	testing.SetRealm(adminRealm)
	staker.SetWarmUp(cross(cur), pct, timeDuration)
	println("[EXPECTED] SetWarmUp warmupTiers:", len(staker.GetWarmupTemplate()))
}

func createExternalIncentive(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), stakerAddr, math.MaxInt64)

	createTimestamp := time.Now().Unix()
	// Start at the next UTC midnight to satisfy start-time validation.
	startTime := ((createTimestamp / 86400) + 1) * 86400
	endTime := startTime + incentiveDuration
	// NextIncentiveID format: "<creator>:<createTimestamp>:<counter>"; counter is 1
	// for the first incentive on this freshly-initialized staker.
	externalIncentiveId = ufmt.Sprintf("%s:%d:%d", adminAddr.String(), createTimestamp, 1)

	staker.CreateExternalIncentive(
		cross(cur),
		barFoo500PoolPath,
		gnsPath,
		incentiveReward,
		startTime,
		endTime,
	)
	println("[EXPECTED] CreateExternalIncentive id:", externalIncentiveId)
	println("[EXPECTED] incentive rewardToken:", staker.GetIncentiveRewardToken(barFoo500PoolPath, externalIncentiveId))
	println("[EXPECTED] incentive totalReward:", staker.GetIncentiveTotalRewardAmount(barFoo500PoolPath, externalIncentiveId))
}

func skipPastIncentiveEnd(cur realm) {
	// Jump past the full 90-day incentive window plus a 1-day buffer so
	// EndExternalIncentive's end-time precondition is satisfied.
	blocksToSkip := (incentiveDuration + 24*60*60) / 5
	testing.SkipHeights(blocksToSkip)
}

func endExternalIncentive(cur realm) {
	testing.SetRealm(adminRealm)
	staker.EndExternalIncentive(cross(cur), barFoo500PoolPath, externalIncentiveId, adminAddr)
	println("[EXPECTED] EndExternalIncentive refunded:", staker.GetIncentiveRefunded(barFoo500PoolPath, externalIncentiveId))
}

func collectExternalIncentivePenalty(cur realm) {
	testing.SetRealm(adminRealm)
	penalty := staker.CollectExternalIncentivePenalty(cross(cur), barFoo500PoolPath, externalIncentiveId, adminAddr)
	println("[EXPECTED] CollectExternalIncentivePenalty penalty:", penalty)
}

func waitBlocks(cur realm) {
	testing.SkipHeights(10)
}

func upgradeToV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	staker.UpgradeImpl(cross(cur), stakerV2ValidPath)
	println("[EXPECTED] Upgraded staker to:", staker.GetImplementationPackagePath())
}

// Output:
// [SCENARIO] 1. Initialize staker with v1, pool and positions
// [EXPECTED] Initialized staker with v1: gno.land/r/gnoswap/staker/v1
// [EXPECTED] Created pool: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Minted position ID: 1 liquidity: 1066918731
// [EXPECTED] Minted position ID: 2 liquidity: 1066918731
//
// [SCENARIO] 2. Create v1 data: set tier + stake position 1
// [EXPECTED] Pool tier set for: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Staked position ID: 1 lpToken: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 3. Accumulate rewards, then read v1 data
// [EXPECTED] pos 1 isStaked: true
// [EXPECTED] pos 1 targetPool: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] pos 1 liquidity: 1066918731
// [EXPECTED] pos 1 stakeTime: 1234567900
//
// [SCENARIO] 4. Upgrade staker to v2_valid
// [EXPECTED] Upgraded staker to: gno.land/r/gnoswap/staker/v2_valid
//
// [SCENARIO] 5. Mutate v1-created data through v2_valid (RMW paths)
// [EXPECTED] CollectReward pos 1 total: 133374323
// [EXPECTED] Staked position ID: 2 lpToken: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] UnStaked position ID: 1 isStaked now: false
//
// [SCENARIO] 6. RMW v1-created pool-tier maps through v2_valid
// [EXPECTED] ChangePoolTier gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500 -> tier: 2
// [EXPECTED] ChangePoolTier gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500 -> tier: 1
//
// [SCENARIO] 7. Drive admin config setters through v2_valid
// [EXPECTED] AddToken gno.land/r/onbloc/bar allowedCount: 3
// [EXPECTED] RemoveToken gno.land/r/onbloc/bar allowedCount: 2
// [EXPECTED] SetUnStakingFee -> 100
// [EXPECTED] SetDepositGnsAmount -> 2000000000
// [EXPECTED] SetMinimumRewardAmount -> 1000000000
// [EXPECTED] SetTokenMinimumRewardAmount -> 12345 found: true
// [EXPECTED] SetWarmUp warmupTiers: 4
//
// [SCENARIO] 8. Exercise external-incentive BPTrees through v2_valid
// [EXPECTED] CreateExternalIncentive id: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5:1234567950:1
// [EXPECTED] incentive rewardToken: gno.land/r/gnoswap/gns
// [EXPECTED] incentive totalReward: 1500000000
// [EXPECTED] EndExternalIncentive refunded: true
// [EXPECTED] CollectExternalIncentivePenalty penalty: 0
// [EXPECTED] UnStaked position ID: 2 isStaked now: false
// [EXPECTED] RemovePoolTier gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500 -> tier: 0
//
// [SCENARIO] 9. Read final data through v2_valid
// [EXPECTED] pos 1 isStaked: false
// [EXPECTED] pos 2 isStaked: false
// [EXPECTED] No readonly-taint panic: migration correct
//
