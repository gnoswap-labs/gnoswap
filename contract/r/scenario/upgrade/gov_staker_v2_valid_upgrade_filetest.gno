// PKGPATH: gno.land/r/gnoswap/v1/main

// Gov/Staker contract upgrade to v2_valid scenario test.
//
// Goal: prove interrealm v2 readonly-taint does NOT occur when the v2_valid
// implementation mutates v1-created data. v2_valid is a symlinked copy of the
// v1 sources under a v2_valid module path (gno.land/r/gnoswap/gov/staker/
// v2_valid). Storage is shared across versions, so delegations / reward states
// created with v1 persist and must remain mutable through v2_valid via
// realm-owned maps / trees and domain methods.
//
// Scenario:
//  1. Initialize gov/staker with v1; set up GNS + emission.
//  2. With v1: Delegate from alice to admin (creates a delegation entry in the
//     delegation map/tree + an emission reward state for the delegatee).
//  3. Accumulate emission rewards (skip blocks), read v1 data via getters.
//  4. Upgrade to v2_valid.
//  5. With v2_valid: MUTATE the v1-created structures via every reachable
//     state-changing entry point exposed by proxy.gno:
//       - SetUnDelegationLockupPeriodByAdmin (admin config RMW)
//       - Delegate            (RMW delegation map/tree + reward state)
//       - Redelegate          (moves delegation between targets; RMW map/tree)
//       - Undelegate          (RMW delegation map/tree + undelegation withdraws)
//       - CollectUndelegatedGns (RMW undelegation withdraw structures)
//       - CollectReward       (RMW reward-state struct)
//       - CleanStakerDelegationSnapshotByAdmin (RMW snapshot history trees)
//     All of these read-modify-write v1-allocated maps / BPTrees / reward
//     structs; a broken migration would panic here with a readonly-taint error.
//     SetAmountByProjectWallet and CollectRewardFromLaunchPad are launchpad
//     role-gated and are NOT reachable from a filetest main (see note in step 5).
//  6. Read final data and show it updated.
package main

import (
	"math"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	govStaker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/gov/staker/v2_valid"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"
)

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	poolAddr      = access.MustGetAddress(prbac.ROLE_POOL.String())
	stakerAddr    = access.MustGetAddress(prbac.ROLE_STAKER.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	aliceAddr = testutils.TestAddress("alice")
	bobAddr   = testutils.TestAddress("bob")

	gnsPath = "gno.land/r/gnoswap/gns"
	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	barFoo3000PoolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
)

const (
	govStakerV1Path      = "gno.land/r/gnoswap/gov/staker/v1"
	govStakerV2ValidPath = "gno.land/r/gnoswap/gov/staker/v2_valid"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize gov/staker with v1, GNS and emission")
	initializeV1(cur)
	createPool(cur)
	mintPosition(cur)
	initEmission(cur)
	stakePosition(cur, 1)
	println()

	println("[SCENARIO] 2. Create v1 data: delegate alice -> admin")
	delegateWithMint(cur, aliceAddr, adminAddr, 1_000_000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. Accumulate rewards, then read v1 data")
	testing.SkipHeights(10)
	readData(cur)
	println()

	println("[SCENARIO] 4. Upgrade gov/staker to v2_valid")
	upgradeToV2Valid(cur)
	println()

	println("[SCENARIO] 5. Mutate v1-created data through v2_valid (RMW paths)")
	// Admin config RMW: shorten the lockup so CollectUndelegatedGns is reachable.
	setUnDelegationLockupPeriod(cur, 100)
	delegateMore(cur, aliceAddr, adminAddr, 1_000_000)        // RMW delegation map/tree + reward state
	redelegate(cur, aliceAddr, adminAddr, bobAddr, 1_000_000) // RMW delegation map/tree (move target)
	undelegate(cur, aliceAddr, adminAddr, 1_000_000)          // RMW delegation map/tree + withdraw
	collectUndelegatedGns(cur, aliceAddr)                     // RMW undelegation withdraw structures
	collectReward(cur, aliceAddr)                             // RMW reward-state struct
	cleanStakerDelegationSnapshot(cur, 0, aliceAddr)          // RMW snapshot history trees
	println()
	// SetAmountByProjectWallet and CollectRewardFromLaunchPad assert
	// access.AssertIsLaunchpad(caller); only the launchpad realm can pass that
	// check, so they are unreachable from this filetest main and are skipped.
	println("[SKIP] SetAmountByProjectWallet/CollectRewardFromLaunchPad: launchpad-role-gated, unreachable from filetest main")

	println("[SCENARIO] 6. Read final data through v2_valid")
	readData(cur)
	println("[EXPECTED] No readonly-taint panic: migration correct")
	println()
}

func initializeV1(cur realm) {
	testing.SetRealm(adminRealm)
	if govStaker.GetImplementationPackagePath() != govStakerV1Path {
		govStaker.UpgradeImpl(cross(cur), govStakerV1Path)
	}
	ufmt.Printf("[EXPECTED] Gov/Staker initialized with v1: %s\n", govStaker.GetImplementationPackagePath())
}

func createPool(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	pool.CreatePool(cross(cur), barPath, fooPath, 3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	ufmt.Printf("[EXPECTED] Created pool: %s\n", barFoo3000PoolPath)
}

func mintPosition(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)
	positionId, liquidity, _, _ := position.Mint(
		cross(cur), barPath, fooPath, 3000, -960, 960,
		"1000000", "1000000", "0", "0", time.Now().Unix()+3600, adminAddr, "",
	)
	ufmt.Printf("[EXPECTED] Minted position ID: %d liquidity: %s\n", positionId, liquidity)
}

func initEmission(cur realm) {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	testing.SkipHeights(1)
	staker.SetPoolTier(cross(cur), barFoo3000PoolPath, 1)
	ufmt.Printf("[EXPECTED] %s pool tier is 1\n", barFoo3000PoolPath)
}

func stakePosition(cur realm, positionId int64) {
	testing.SetRealm(adminRealm)
	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.FormatInt(positionId, 10)))
	staker.StakeToken(cross(cur), uint64(positionId), "")
	ufmt.Printf("[EXPECTED] Staked position ID: %d\n", positionId)
}

func delegateWithMint(cur realm, from, to address, amount int64) {
	if from != adminAddr {
		testing.SetRealm(adminRealm)
		gns.Transfer(cross(cur), from, amount)
	}
	testing.SetRealm(testing.NewUserRealm(from))
	gns.Approve(cross(cur), govStakerAddr, amount)
	delegationID := govStaker.Delegate(cross(cur), to, amount, "")
	ufmt.Printf("[EXPECTED] v1 delegated %d GNS from alice to admin, delegationID: %d\n", amount, delegationID)
}

func delegateMore(cur realm, from, to address, amount int64) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), from, amount)
	testing.SetRealm(testing.NewUserRealm(from))
	gns.Approve(cross(cur), govStakerAddr, amount)
	delegationID := govStaker.Delegate(cross(cur), to, amount, "")
	ufmt.Printf("[EXPECTED] v2_valid delegated %d more GNS, delegationID: %d\n", amount, delegationID)
}

func undelegate(cur realm, from, to address, amount int64) {
	testing.SetRealm(testing.NewUserRealm(from))
	govStaker.Undelegate(cross(cur), to, amount)
	ufmt.Printf("[EXPECTED] v2_valid undelegated %d GNS from admin\n", amount)
}

func collectReward(cur realm, addr address) {
	testing.SetRealm(testing.NewUserRealm(addr))
	govStaker.CollectReward(cross(cur))
	ufmt.Printf("[EXPECTED] v2_valid collected reward for alice\n")
}

func setUnDelegationLockupPeriod(cur realm, period int64) {
	testing.SetRealm(adminRealm)
	govStaker.SetUnDelegationLockupPeriodByAdmin(cross(cur), period)
	ufmt.Printf("[EXPECTED] v2_valid set undelegation lockup period: %d\n", govStaker.GetUnDelegationLockupPeriod())
}

func redelegate(cur realm, from, delegatee, newDelegatee address, amount int64) {
	testing.SetRealm(testing.NewUserRealm(from))
	redelegated := govStaker.Redelegate(cross(cur), delegatee, newDelegatee, amount)
	ufmt.Printf("[EXPECTED] v2_valid redelegated %d GNS from admin to bob\n", redelegated)
	ufmt.Printf("[EXPECTED] alice->bob delegation count: %d\n", govStaker.GetUserDelegationCount(from, newDelegatee))
}

func collectUndelegatedGns(cur realm, addr address) {
	// Advance past the lockup period (blockTime is 5s/height, lockup is 100s).
	testing.SkipHeights(100)
	testing.SetRealm(testing.NewUserRealm(addr))
	collected := govStaker.CollectUndelegatedGns(cross(cur))
	ufmt.Printf("[EXPECTED] v2_valid collected undelegated GNS: %d\n", collected)
	ufmt.Printf("[EXPECTED] total locked amount: %d\n", govStaker.GetTotalLockedAmount())
}

func cleanStakerDelegationSnapshot(cur realm, snapshotTime int64, target address) {
	testing.SetRealm(adminRealm)
	govStaker.CleanStakerDelegationSnapshotByAdmin(cross(cur), snapshotTime, target)
	ufmt.Printf("[EXPECTED] v2_valid cleaned delegation snapshot up to: %d\n", snapshotTime)
}

func readData(cur realm) {
	totalDelegated := govStaker.GetTotalDelegated()
	ufmt.Printf("[EXPECTED] total delegated: %d\n", totalDelegated)
	emissionReward, _, err := govStaker.GetClaimableRewardByAddress(aliceAddr)
	if err != nil {
		ufmt.Printf("[EXPECTED] alice claimable emission reward error: %s\n", err.Error())
		return
	}
	ufmt.Printf("[EXPECTED] alice claimable emission reward: %d\n", emissionReward)
}

func upgradeToV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross(cur), govStakerV2ValidPath)
	ufmt.Printf("[EXPECTED] Upgraded gov/staker to: %s\n", govStaker.GetImplementationPackagePath())
}

// Output:
// [SCENARIO] 1. Initialize gov/staker with v1, GNS and emission
// [EXPECTED] Gov/Staker initialized with v1: gno.land/r/gnoswap/gov/staker/v1
// [EXPECTED] Created pool: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
// [EXPECTED] Minted position ID: 1 liquidity: 21338374
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000 pool tier is 1
// [EXPECTED] Staked position ID: 1
//
// [SCENARIO] 2. Create v1 data: delegate alice -> admin
// [EXPECTED] v1 delegated 1000000 GNS from alice to admin, delegationID: 1000000
//
// [SCENARIO] 3. Accumulate rewards, then read v1 data
// [EXPECTED] total delegated: 1000000
// [EXPECTED] alice claimable emission reward: 0
//
// [SCENARIO] 4. Upgrade gov/staker to v2_valid
// [EXPECTED] Upgraded gov/staker to: gno.land/r/gnoswap/gov/staker/v2_valid
//
// [SCENARIO] 5. Mutate v1-created data through v2_valid (RMW paths)
// [EXPECTED] v2_valid set undelegation lockup period: 100
// [EXPECTED] v2_valid delegated 1000000 more GNS, delegationID: 1000000
// [EXPECTED] v2_valid redelegated 1000000 GNS from admin to bob
// [EXPECTED] alice->bob delegation count: 1
// [EXPECTED] v2_valid undelegated 1000000 GNS from admin
// [EXPECTED] v2_valid collected undelegated GNS: 1000000
// [EXPECTED] total locked amount: 1000000
// [EXPECTED] v2_valid collected reward for alice
// [EXPECTED] v2_valid cleaned delegation snapshot up to: 0
//
// [SKIP] SetAmountByProjectWallet/CollectRewardFromLaunchPad: launchpad-role-gated, unreachable from filetest main
// [SCENARIO] 6. Read final data through v2_valid
// [EXPECTED] total delegated: 1000000
// [EXPECTED] alice claimable emission reward: 0
// [EXPECTED] No readonly-taint panic: migration correct
//
