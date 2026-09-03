// PKGPATH: gno.land/r/gnoswap/v1/main

// Gov/Staker contract upgrade scenario test with data validation.
//
// Delegations, undelegation withdraw queues and the delegation snapshot history
// live in the shared KV store, so an upgrade must leave every value untouched.
// This test builds a delegation graph with v1, snapshots what the public getters
// expose, walks the implementation through v2_invalid (which must block the
// calls) up to v3_valid, asserts the snapshot is unchanged, and then keeps
// operating on the v1-created delegations through the new implementation.
package main

import (
	"strconv"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	govStaker "gno.land/r/gnoswap/gov/staker"

	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/gov/staker/v2_invalid"
	_ "gno.land/r/gnoswap/gov/staker/v3_valid"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"
)

var t *testing.T

const (
	govStakerV1Path        = "gno.land/r/gnoswap/gov/staker/v1"
	govStakerV2InvalidPath = "gno.land/r/gnoswap/gov/staker/v2_invalid"
	govStakerV3ValidPath   = "gno.land/r/gnoswap/gov/staker/v3_valid"

	blockTimeSeconds = int64(5)

	lockupPeriod    = int64(100)
	aliceDelegation = int64(2_000_000_000)
	bobDelegation   = int64(1_000_000_000)
	redelegateSize  = int64(500_000_000)
	undelegateSize  = int64(200_000_000)
)

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	adminRealm = testing.NewUserRealm(adminAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	bobAddr  = testutils.TestAddress("bob")
	bobRealm = testing.NewUserRealm(bobAddr)

	// snapshot of the v1-written state
	v1TotalDelegated    int64
	v1TotalXGnsSupply   int64
	v1TotalLocked       int64
	v1LockupPeriod      int64
	v1DelegationCount   int
	v1DelegationIDs     []int64
	v1AliceToAdminCount int
	v1AliceToAliceCount int
	v1FirstDelegateFrom address
	v1FirstDelegateTo   address
	v1FirstDelegateAmt  int64
	v1CollectableAlice  int64
	v1WithdrawCount     int
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize gov/staker contract with v1")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Build the delegation graph with v1")
	delegateWithV1(cur)
	println()

	println("[SCENARIO] 3. Redelegate and undelegate with v1")
	redelegateAndUndelegateWithV1(cur)
	println()

	println("[SCENARIO] 4. Snapshot v1 data through the getters")
	captureV1Snapshot()
	println()

	println("[SCENARIO] 5. Upgrade to v2_invalid")
	upgradeTo(cur, govStakerV2InvalidPath)
	println()

	println("[SCENARIO] 6. Mutating calls must be blocked by v2_invalid")
	assertAborts(cur, func() {
		testing.SetRealm(bobRealm)
		gns.Approve(cross(cur), govStakerAddr, bobDelegation)
		govStaker.Delegate(cross(cur), adminAddr, bobDelegation, "")
	}, "[EXPECTED] Delegate is blocked by v2_invalid")
	assertAborts(cur, func() {
		testing.SetRealm(aliceRealm)
		govStaker.CollectReward(cross(cur))
	}, "[EXPECTED] CollectReward is blocked by v2_invalid")
	println()

	println("[SCENARIO] 7. Upgrade to v3_valid")
	upgradeTo(cur, govStakerV3ValidPath)
	println()

	println("[SCENARIO] 8. Validate the v1 delegation data through v3_valid")
	validateSnapshot()
	println()

	println("[SCENARIO] 9. Keep operating on the v1-created delegations")
	operateWithV3Valid(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross(cur), govStakerV1Path)
	govStaker.SetUnDelegationLockupPeriodByAdmin(cross(cur), lockupPeriod)

	println("[EXPECTED] implementation:", govStaker.GetImplementationPackagePath())
	println("[EXPECTED] undelegation lockup period:", govStaker.GetUnDelegationLockupPeriod())
	uassert.Equal(t, lockupPeriod, govStaker.GetUnDelegationLockupPeriod())
}

func delegateWithV1(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), aliceAddr, aliceDelegation)
	gns.Transfer(cross(cur), bobAddr, bobDelegation)

	testing.SetRealm(aliceRealm)
	gns.Approve(cross(cur), govStakerAddr, aliceDelegation)
	aliceAmount := govStaker.Delegate(cross(cur), adminAddr, aliceDelegation, "")
	testing.SkipHeights(1)

	testing.SetRealm(bobRealm)
	gns.Approve(cross(cur), govStakerAddr, bobDelegation)
	bobAmount := govStaker.Delegate(cross(cur), bobAddr, bobDelegation, "")
	testing.SkipHeights(1)

	println("[EXPECTED] alice delegated amount:", aliceAmount)
	println("[EXPECTED] bob delegated amount:", bobAmount)
	println("[EXPECTED] delegation count:", govStaker.GetDelegations().Size())
	println("[EXPECTED] total delegated:", govStaker.GetTotalDelegated())
	println("[EXPECTED] total xGNS supply:", govStaker.GetTotalxGnsSupply())
	println("[EXPECTED] total locked amount:", govStaker.GetTotalLockedAmount())

	// xGNS is minted 1:1 against the delegated GNS
	uassert.Equal(t, aliceDelegation+bobDelegation, govStaker.GetTotalDelegated())
	uassert.Equal(t, aliceDelegation+bobDelegation, govStaker.GetTotalxGnsSupply())
	uassert.Equal(t, 2, govStaker.GetDelegations().Size())
}

func redelegateAndUndelegateWithV1(cur realm) {
	testing.SetRealm(aliceRealm)
	redelegated := govStaker.Redelegate(cross(cur), adminAddr, aliceAddr, redelegateSize)
	testing.SkipHeights(1)
	println("[EXPECTED] redelegated:", redelegated)
	println("[EXPECTED] alice->admin delegation count:", len(govStaker.GetUserDelegationIDs(aliceAddr, adminAddr)))
	println("[EXPECTED] alice->alice delegation count:", len(govStaker.GetUserDelegationIDs(aliceAddr, aliceAddr)))
	println("[EXPECTED] alice delegatee count:", govStaker.GetDelegatorDelegations(aliceAddr).Size())

	undelegated := govStaker.Undelegate(cross(cur), aliceAddr, undelegateSize)
	testing.SkipHeights(1)
	println("[EXPECTED] undelegated:", undelegated)
	println("[EXPECTED] total delegated after undelegate:", govStaker.GetTotalDelegated())
	println("[EXPECTED] total xGNS supply after undelegate:", govStaker.GetTotalxGnsSupply())

	// the redelegation must not change the totals, the undelegation must
	uassert.Equal(t, redelegateSize, redelegated)
	uassert.Equal(t, undelegateSize, undelegated)
	uassert.Equal(t, aliceDelegation+bobDelegation-undelegateSize, govStaker.GetTotalDelegated())
}

func captureV1Snapshot() {
	v1TotalDelegated = govStaker.GetTotalDelegated()
	v1TotalXGnsSupply = govStaker.GetTotalxGnsSupply()
	v1TotalLocked = govStaker.GetTotalLockedAmount()
	v1LockupPeriod = govStaker.GetUnDelegationLockupPeriod()
	v1DelegationCount = govStaker.GetDelegations().Size()
	v1DelegationIDs = collectDelegationIDs(0, 10)
	v1AliceToAdminCount = len(govStaker.GetUserDelegationIDs(aliceAddr, adminAddr))
	v1AliceToAliceCount = len(govStaker.GetUserDelegationIDs(aliceAddr, aliceAddr))

	firstDelegation, err := delegationByID(v1DelegationIDs[0])
	if err != nil {
		panic(err)
	}
	v1FirstDelegateFrom = firstDelegation.DelegateFrom()
	v1FirstDelegateTo = firstDelegation.DelegateTo()
	v1FirstDelegateAmt = firstDelegation.TotalDelegatedAmount()
	v1WithdrawCount = govStaker.GetDelegationWithdrawCount(v1DelegationIDs[0])
	v1CollectableAlice = govStaker.GetCollectableWithdrawAmount(v1DelegationIDs[0])

	println("[EXPECTED] snapshot total delegated:", v1TotalDelegated)
	println("[EXPECTED] snapshot total xGNS supply:", v1TotalXGnsSupply)
	println("[EXPECTED] snapshot total locked:", v1TotalLocked)
	println("[EXPECTED] snapshot delegation count:", v1DelegationCount)
	println("[EXPECTED] snapshot delegation ids:", len(v1DelegationIDs))
	println("[EXPECTED] snapshot first delegation amount:", v1FirstDelegateAmt)
	println("[EXPECTED] snapshot withdraw count:", v1WithdrawCount)
	println("[EXPECTED] snapshot collectable withdraw amount:", v1CollectableAlice)
}

func upgradeTo(cur realm, packagePath string) {
	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross(cur), packagePath)
	println("[EXPECTED] implementation:", govStaker.GetImplementationPackagePath())
	uassert.Equal(t, packagePath, govStaker.GetImplementationPackagePath())
}

func validateSnapshot() {
	firstDelegation, err := delegationByID(v1DelegationIDs[0])
	if err != nil {
		panic(err)
	}

	uassert.Equal(t, v1TotalDelegated, govStaker.GetTotalDelegated())
	uassert.Equal(t, v1TotalXGnsSupply, govStaker.GetTotalxGnsSupply())
	uassert.Equal(t, v1TotalLocked, govStaker.GetTotalLockedAmount())
	uassert.Equal(t, v1LockupPeriod, govStaker.GetUnDelegationLockupPeriod())
	uassert.Equal(t, v1DelegationCount, govStaker.GetDelegations().Size())
	uassert.Equal(t, len(v1DelegationIDs), len(collectDelegationIDs(0, 10)))
	uassert.Equal(t, v1AliceToAdminCount, len(govStaker.GetUserDelegationIDs(aliceAddr, adminAddr)))
	uassert.Equal(t, v1AliceToAliceCount, len(govStaker.GetUserDelegationIDs(aliceAddr, aliceAddr)))
	uassert.Equal(t, v1FirstDelegateFrom, firstDelegation.DelegateFrom())
	uassert.Equal(t, v1FirstDelegateTo, firstDelegation.DelegateTo())
	uassert.Equal(t, v1FirstDelegateAmt, firstDelegation.TotalDelegatedAmount())
	uassert.Equal(t, v1WithdrawCount, govStaker.GetDelegationWithdrawCount(v1DelegationIDs[0]))
	uassert.Equal(t, v1CollectableAlice, govStaker.GetCollectableWithdrawAmount(v1DelegationIDs[0]))
	uassert.True(t, govStaker.ExistsDelegation(v1DelegationIDs[0]))

	println("[EXPECTED] total delegated:", govStaker.GetTotalDelegated())
	println("[EXPECTED] total xGNS supply:", govStaker.GetTotalxGnsSupply())
	println("[EXPECTED] delegation count:", govStaker.GetDelegations().Size())
	println("[EXPECTED] first delegation from/to/amount:",
		firstDelegation.DelegateFrom(), firstDelegation.DelegateTo(), firstDelegation.TotalDelegatedAmount())
	println("[EXPECTED] every v1 delegation value survived the upgrade")
}

func operateWithV3Valid(cur realm) {
	// the undelegated GNS is claimable once the lockup period has passed
	testing.SkipHeights(lockupPeriod/blockTimeSeconds + 1)

	testing.SetRealm(aliceRealm)
	collected := govStaker.CollectUndelegatedGns(cross(cur))
	testing.SkipHeights(1)
	println("[EXPECTED] collected undelegated gns:", collected)
	println("[EXPECTED] total locked amount:", govStaker.GetTotalLockedAmount())

	// bob adds to the v1-created delegation tree through v3_valid
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), bobAddr, bobDelegation)

	testing.SetRealm(bobRealm)
	gns.Approve(cross(cur), govStakerAddr, bobDelegation)
	bobAmount := govStaker.Delegate(cross(cur), bobAddr, bobDelegation, "")
	testing.SkipHeights(1)
	println("[EXPECTED] bob delegated again:", bobAmount)
	println("[EXPECTED] delegation count:", govStaker.GetDelegations().Size())
	println("[EXPECTED] total delegated:", govStaker.GetTotalDelegated())

	// reward collection through the new implementation
	testing.SetRealm(aliceRealm)
	govStaker.CollectReward(cross(cur))
	testing.SkipHeights(1)
	claimable, protocolFeeRewards, err := govStaker.GetClaimableRewardByAddress(aliceAddr)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] alice claimable emission reward after collect:", claimable)
	println("[EXPECTED] alice claimable protocol fee token count:", len(protocolFeeRewards))
	println("[EXPECTED] emission distributed amount:", govStaker.GetEmissionDistributedAmount())

	// snapshot pruning is only allowed beyond the maximum smoothing period
	testing.SetRealm(adminRealm)
	govStaker.CleanStakerDelegationSnapshotByAdmin(cross(cur), time.Now().Unix()-31*86400, aliceAddr)
	testing.SkipHeights(1)
	println("[EXPECTED] delegation snapshots present:", govStaker.HasDelegationSnapshotsKey())

	uassert.Equal(t, undelegateSize, collected)
	uassert.Equal(t, v1DelegationCount+1, govStaker.GetDelegations().Size())
	uassert.Equal(t, v1TotalDelegated+bobDelegation, govStaker.GetTotalDelegated())
}

func assertAborts(cur realm, callback func(), logMessage string) {
	uassert.AbortsContains(t, cur, "implementation", callback)
	println(logMessage)
}

// Output:
// [SCENARIO] 1. Initialize gov/staker contract with v1
// [EXPECTED] implementation: gno.land/r/gnoswap/gov/staker/v1
// [EXPECTED] undelegation lockup period: 100
//
// [SCENARIO] 2. Build the delegation graph with v1
// [EXPECTED] alice delegated amount: 2000000000
// [EXPECTED] bob delegated amount: 1000000000
// [EXPECTED] delegation count: 2
// [EXPECTED] total delegated: 3000000000
// [EXPECTED] total xGNS supply: 3000000000
// [EXPECTED] total locked amount: 3000000000
//
// [SCENARIO] 3. Redelegate and undelegate with v1
// [EXPECTED] redelegated: 500000000
// [EXPECTED] alice->admin delegation count: 1
// [EXPECTED] alice->alice delegation count: 1
// [EXPECTED] alice delegatee count: 2
// [EXPECTED] undelegated: 200000000
// [EXPECTED] total delegated after undelegate: 2800000000
// [EXPECTED] total xGNS supply after undelegate: 3000000000
//
// [SCENARIO] 4. Snapshot v1 data through the getters
// [EXPECTED] snapshot total delegated: 2800000000
// [EXPECTED] snapshot total xGNS supply: 3000000000
// [EXPECTED] snapshot total locked: 3000000000
// [EXPECTED] snapshot delegation count: 3
// [EXPECTED] snapshot delegation ids: 3
// [EXPECTED] snapshot first delegation amount: 2000000000
// [EXPECTED] snapshot withdraw count: 0
// [EXPECTED] snapshot collectable withdraw amount: 0
//
// [SCENARIO] 5. Upgrade to v2_invalid
// [EXPECTED] implementation: gno.land/r/gnoswap/gov/staker/v2_invalid
//
// [SCENARIO] 6. Mutating calls must be blocked by v2_invalid
// [EXPECTED] Delegate is blocked by v2_invalid
// [EXPECTED] CollectReward is blocked by v2_invalid
//
// [SCENARIO] 7. Upgrade to v3_valid
// [EXPECTED] implementation: gno.land/r/gnoswap/gov/staker/v3_valid
//
// [SCENARIO] 8. Validate the v1 delegation data through v3_valid
// [EXPECTED] total delegated: 2800000000
// [EXPECTED] total xGNS supply: 3000000000
// [EXPECTED] delegation count: 3
// [EXPECTED] first delegation from/to/amount: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh g10n6fcxm0zr3pl9gz0q4nacwvlfkjzya97rlxxz 2000000000
// [EXPECTED] every v1 delegation value survived the upgrade
//
// [SCENARIO] 9. Keep operating on the v1-created delegations
// [EXPECTED] collected undelegated gns: 200000000
// [EXPECTED] total locked amount: 2800000000
// [EXPECTED] bob delegated again: 1000000000
// [EXPECTED] delegation count: 4
// [EXPECTED] total delegated: 3800000000
// [EXPECTED] alice claimable emission reward after collect: 0
// [EXPECTED] alice claimable protocol fee token count: 0
// [EXPECTED] emission distributed amount: 0
// [EXPECTED] delegation snapshots present: true

// collectDelegationIDs pages the read-only delegation view and returns the IDs
// its keys encode.
func collectDelegationIDs(offset, count int) []int64 {
	ids := []int64{}
	govStaker.GetDelegations().IterateByOffset(offset, count, func(key string, _ any) bool {
		id, err := strconv.ParseInt(key, 10, 64)
		if err != nil {
			return false
		}

		ids = append(ids, id)

		return false
	})

	return ids
}

// delegationByID reads one delegation through the read-only view.
func delegationByID(delegationID int64) (*govStaker.Delegation, error) {
	delegation, ok := govStaker.GetDelegations().Get(strconv.FormatInt(delegationID, 10)).(*govStaker.Delegation)
	if !ok {
		return nil, ufmt.Errorf("delegation %d not found", delegationID)
	}

	return delegation, nil
}
