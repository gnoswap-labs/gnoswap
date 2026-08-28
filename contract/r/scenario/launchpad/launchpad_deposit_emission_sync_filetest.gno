// launchpad deposit emission sync

// PKGPATH: gno.land/r/gnoswap/v1/main

// Scenario: a launchpad deposit adds gov/staker stake for the project wallet.
// The gov/staker emission accumulator only advances when MintAndDistributeGns
// is called, so DepositGns must sync it before the new stake is added.
// Otherwise the next mint lands the whole quiet-period delta after the project
// wallet already holds stake, and the delegators split it with the project.

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/scenarioutils"
	"gno.land/r/onbloc/obl"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())

	bobAddr  = testutils.TestAddress("bob")
	bobRealm = testing.NewUserRealm(bobAddr)

	projectAddr = testutils.TestAddress("project-owner")

	delegateAmount = int64(1_000_000)
	depositAmount  = int64(1_000_000)
)

func main(cur realm) {
	println("[SCENARIO] 1. Start emission with a 50% gov staker share")
	startEmission(cur)
	println()

	println("[SCENARIO] 2. Create OBL launchpad project")
	projectID := createOBLProject(cur)
	println()

	println("[SCENARIO] 3. Bob delegates, which syncs the emission accumulator")
	delegate(cur)
	println()

	println("[SCENARIO] 4. Quiet period: 7 days pass without any mint")
	quietPeriod(cur)
	println()

	println("[SCENARIO] 5. Bob deposits GNS to the project tier 30")
	deposit(cur, projectID)
	println()

	println("[SCENARIO] 6. Mint right after the deposit")
	mint(cur)
	println()

	println("[SCENARIO] 7. Quiet period rewards belong to the delegator only")
	checkClaimableRewards(cur)
}

func startEmission(cur realm) {
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross(cur),
		5000, // liquidityStakerPct
		0,    // devOpsPct
		0,    // communityPoolPct
		5000, // govStakerPct
	)
	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	println("[INFO] gov staker distribution share set to 50%")
}

func createOBLProject(cur realm) string {
	rewardAmount := int64(1_000_000_000)

	testing.SetRealm(adminRealm)
	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	projectID := launchpad.CreateProject(
		cross(cur),
		"OBL Launchpad Project",
		"gno.land/r/onbloc/obl.OBL",
		projectAddr,
		rewardAmount,
		"gno.land/r/gnoswap/gov/xgns",
		"1000000",
		10,                       // tier30Ratio
		20,                       // tier90Ratio
		70,                       // tier180Ratio
		time.Now().Unix()+604800, // startTime, 7 days later
	)
	println("[EXPECTED] Project created with ID:", projectID)

	return projectID
}

func delegate(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), bobAddr, delegateAmount+depositAmount)

	testing.SetRealm(bobRealm)
	gns.Approve(cross(cur), govStakerAddr, delegateAmount)
	staker.Delegate(cross(cur), bobAddr, delegateAmount, "")

	println(ufmt.Sprintf("[EXPECTED] Bob delegated amount: %d", delegateAmount))
	println(ufmt.Sprintf("[EXPECTED] Accumulated distribution to gov staker: %d", emission.GetAccuDistributedToGovStaker()))
}

func quietPeriod(cur realm) {
	testing.SkipHeights(120_961)
	println(ufmt.Sprintf("[EXPECTED] Accumulated distribution to gov staker without mint: %d", emission.GetAccuDistributedToGovStaker()))
}

func deposit(cur realm, projectID string) {
	testing.SetRealm(bobRealm)
	gns.Approve(cross(cur), launchpadAddr, depositAmount)
	depositID := launchpad.DepositGns(cross(cur), projectID+":30", depositAmount, "")

	println("[EXPECTED] Deposit created with ID:", depositID)
	println(ufmt.Sprintf("[EXPECTED] Accumulated distribution to gov staker after deposit: %d", emission.GetAccuDistributedToGovStaker()))
}

func mint(cur realm) {
	testing.SetRealm(adminRealm)
	emission.MintAndDistributeGns(cross(cur))

	println(ufmt.Sprintf("[EXPECTED] Accumulated distribution to gov staker after mint: %d", emission.GetAccuDistributedToGovStaker()))
}

func checkClaimableRewards(cur realm) {
	projectEmission, _, _ := staker.GetClaimableRewardByLaunchpad(projectAddr)
	bobEmission, _, _ := staker.GetClaimableRewardByAddress(bobAddr)

	println(ufmt.Sprintf("[EXPECTED] Project wallet claimable emission: %d", projectEmission))
	println(ufmt.Sprintf("[EXPECTED] Bob claimable emission: %d", bobEmission))
}

// Output:
// [SCENARIO] 1. Start emission with a 50% gov staker share
// [INFO] gov staker distribution share set to 50%
//
// [SCENARIO] 2. Create OBL launchpad project
// [EXPECTED] Project created with ID: gno.land/r/onbloc/obl.OBL:123
//
// [SCENARIO] 3. Bob delegates, which syncs the emission accumulator
// [EXPECTED] Bob delegated amount: 1000000
// [EXPECTED] Accumulated distribution to gov staker: 0
//
// [SCENARIO] 4. Quiet period: 7 days pass without any mint
// [EXPECTED] Accumulated distribution to gov staker without mint: 0
//
// [SCENARIO] 5. Bob deposits GNS to the project tier 30
// [EXPECTED] Deposit created with ID: 1
// [EXPECTED] Accumulated distribution to gov staker after deposit: 2157552023957
//
// [SCENARIO] 6. Mint right after the deposit
// [EXPECTED] Accumulated distribution to gov staker after mint: 2157552023957
//
// [SCENARIO] 7. Quiet period rewards belong to the delegator only
// [EXPECTED] Project wallet claimable emission: 0
// [EXPECTED] Bob claimable emission: 2157552023956
