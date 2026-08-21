// PKGPATH: gno.land/r/gnoswap/v1/main

// Launchpad contract upgrade scenario test with data validation.
//
// Projects, tiers, deposits and reward managers all live in the shared KV
// store, so an upgrade must leave them untouched. This test creates a project
// and a deposit with v1, snapshots everything the public getters expose,
// upgrades v1 -> v2_invalid (proving the calls are blocked) -> v2_valid,
// asserts the snapshot is unchanged, and keeps operating on the v1-created data
// through the new implementation (second deposit, reward collection, principal
// withdrawal and the admin leftover sweep).
//
// v2_valid is a copy of the v1 sources under a v2_valid module path, so it must
// behave identically. (launchpad/v3_valid is deliberately NOT used here: it is a
// divergent implementation whose CollectDepositGns skips the tier and
// total-staked bookkeeping, so it is not a behaviour-preservation fixture.)
package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	govStaker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/launchpad"
	"gno.land/r/onbloc/obl"

	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/launchpad/v1"
	_ "gno.land/r/gnoswap/launchpad/v2_invalid"
	_ "gno.land/r/gnoswap/launchpad/v2_valid"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"
)

var t *testing.T

const (
	launchpadV1Path        = "gno.land/r/gnoswap/launchpad/v1"
	launchpadV2InvalidPath = "gno.land/r/gnoswap/launchpad/v2_invalid"
	launchpadV2ValidPath   = "gno.land/r/gnoswap/launchpad/v2_valid"

	oblPath = "gno.land/r/onbloc/obl.OBL"

	blockTimeSeconds = int64(5)
	secondsPerDay    = int64(86400)

	rewardAmount   = int64(1_000_000_000)
	depositAmount  = int64(1_000_000)
	tier30Duration = int64(30)
)

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	launchpadAddr = access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())

	adminRealm = testing.NewUserRealm(adminAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	bobAddr  = testutils.TestAddress("bob")
	bobRealm = testing.NewUserRealm(bobAddr)

	projectAddr  = testutils.TestAddress("project-owner")
	projectRealm = testing.NewUserRealm(projectAddr)

	projectId  string
	tier30Id   string
	depositId  string
	depositId2 string

	// snapshot of the v1-written state
	v1ProjectCount      int
	v1ProjectName       string
	v1ProjectTokenPath  string
	v1ProjectRecipient  address
	v1ProjectDeposit    int64
	v1Tier30Total       int64
	v1Tier90Total       int64
	v1Tier180Total      int64
	v1Tier30Start       int64
	v1Tier30End         int64
	v1DepositCount      int
	v1DepositAmount     int64
	v1DepositTier       int64
	v1DepositProjectID  string
	v1TotalGNSStaked    int64
	v1RewardManagers    int
	v1RewardTotalAmount int64
	v1ProjectActive     bool
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize launchpad contract with v1")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Create a project with v1")
	createProject(cur)
	println()

	println("[SCENARIO] 3. Deposit GNS into tier 30 with v1")
	depositWithV1(cur)
	println()

	println("[SCENARIO] 4. Collect the tier 30 reward with v1")
	collectRewardWithV1(cur)
	println()

	println("[SCENARIO] 5. Snapshot v1 data through the getters")
	captureV1Snapshot()
	println()

	println("[SCENARIO] 6. Upgrade to v2_invalid and prove the calls are blocked")
	upgradeTo(cur, launchpadV2InvalidPath)
	assertAborts(cur, func() {
		testing.SetRealm(aliceRealm)
		launchpad.DepositGns(cross(cur), tier30Id, depositAmount, "")
	}, "[EXPECTED] DepositGns is blocked by v2_invalid")
	assertAborts(cur, func() {
		testing.SetRealm(aliceRealm)
		launchpad.CollectRewardByDepositId(cross(cur), depositId)
	}, "[EXPECTED] CollectRewardByDepositId is blocked by v2_invalid")
	assertAborts(cur, func() {
		launchpad.GetTotalGNSStakedAmount()
	}, "[EXPECTED] the getters are blocked by v2_invalid too")
	println()

	println("[SCENARIO] 6-1. Upgrade to v2_valid and validate the v1 data")
	upgradeTo(cur, launchpadV2ValidPath)
	validateSnapshot()
	println()

	println("[SCENARIO] 7. Second deposit through v2_valid on the v1-created tier")
	depositWithV2Valid(cur)
	println()

	println("[SCENARIO] 8. Re-validate the v1 data after the v2_valid write")
	validateSnapshot()
	println()

	println("[SCENARIO] 9. Collect the deposit principal after the tier ends")
	collectDepositAfterUpgrade(cur)
	println()

	println("[SCENARIO] 10. Project recipient collects the launchpad-side rewards")
	collectProjectRewards(cur)
	println()

	println("[SCENARIO] 11. Admin sweeps the leftovers after the project ends")
	transferLeftAfterUpgrade(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	launchpad.UpgradeImpl(cross(cur), launchpadV1Path)
	println("[EXPECTED] implementation:", launchpad.GetImplementationPackagePath())
}

func createProject(cur realm) {
	testing.SetRealm(adminRealm)

	startTime := time.Now().Unix() + 7*secondsPerDay
	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	projectId = launchpad.CreateProject(
		cross(cur),
		"OBL launchpad project",
		oblPath,
		projectAddr,
		rewardAmount,
		"",
		"",
		10, // tier30 ratio
		20, // tier90 ratio
		70, // tier180 ratio
		startTime,
	)
	testing.SkipHeights(1)
	tier30Id = ufmt.Sprintf("%s:%d", projectId, tier30Duration)

	name, _ := launchpad.GetProjectName(projectId)
	tokenPath, _ := launchpad.GetProjectTokenPath(projectId)
	recipient, _ := launchpad.GetProjectRecipient(projectId)
	deposit, _ := launchpad.GetProjectDepositAmount(projectId)
	tier30Total, _ := launchpad.GetProjectTierTotalDistributeAmount(projectId, 30)
	tier90Total, _ := launchpad.GetProjectTierTotalDistributeAmount(projectId, 90)
	tier180Total, _ := launchpad.GetProjectTierTotalDistributeAmount(projectId, 180)

	println("[EXPECTED] project id:", projectId)
	println("[EXPECTED] project name:", name)
	println("[EXPECTED] project token path:", tokenPath)
	println("[EXPECTED] project recipient is the project owner:", recipient == projectAddr)
	println("[EXPECTED] project deposit amount:", deposit)
	println("[EXPECTED] tier distribute amounts (30/90/180):", tier30Total, tier90Total, tier180Total)

	// the ratios are 10 / 20 / 70 of the funded reward amount
	uassert.Equal(t, rewardAmount/10, tier30Total)
	uassert.Equal(t, rewardAmount/5, tier90Total)
	uassert.Equal(t, rewardAmount*7/10, tier180Total)
	uassert.Equal(t, rewardAmount, deposit)
}

func depositWithV1(cur realm) {
	// the tier only accepts deposits once it has started
	testing.SkipHeights(7 * secondsPerDay / blockTimeSeconds)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), aliceAddr, depositAmount)

	testing.SetRealm(aliceRealm)
	gns.Approve(cross(cur), launchpadAddr, depositAmount)
	depositId = launchpad.DepositGns(cross(cur), tier30Id, depositAmount, "")
	testing.SkipHeights(1)

	amount, _ := launchpad.GetDepositAmount(depositId)
	tier, _ := launchpad.GetDepositTier(depositId)
	depositProject, _ := launchpad.GetDepositProjectID(depositId)
	projectWallet, projectWalletFound := govStaker.GetLaunchpadProjectDeposit(projectAddr.String())

	println("[EXPECTED] deposit id:", depositId)
	println("[EXPECTED] deposit amount:", amount)
	println("[EXPECTED] deposit tier:", tier)
	println("[EXPECTED] deposit project id matches:", depositProject == projectId)
	println("[EXPECTED] deposit count:", launchpad.GetDepositCount())
	println("[EXPECTED] total GNS staked:", launchpad.GetTotalGNSStakedAmount())
	// DepositGns forwards the xGNS accounting to gov/staker
	println("[EXPECTED] gov staker project wallet:", projectWallet, "found:", projectWalletFound)

	uassert.Equal(t, depositAmount, amount)
	uassert.Equal(t, tier30Duration, tier)
	uassert.Equal(t, depositAmount, launchpad.GetTotalGNSStakedAmount())
	uassert.True(t, projectWalletFound)
	uassert.Equal(t, depositAmount, projectWallet)
}

func collectRewardWithV1(cur realm) {
	// tier 30 rewards become collectable after a 3 day wait; collect on day 4
	testing.SkipHeights(4 * secondsPerDay / blockTimeSeconds)

	testing.SetRealm(aliceRealm)
	collected := launchpad.CollectRewardByDepositId(cross(cur), depositId)
	testing.SkipHeights(1)

	tier30Total, _ := launchpad.GetProjectTierTotalDistributeAmount(projectId, 30)
	tier30Collected, _ := launchpad.GetProjectTierTotalCollectedAmount(projectId, 30)

	println("[EXPECTED] collected reward:", collected)
	println("[EXPECTED] tier 30 total collected:", tier30Collected)

	// alice is the only depositor, so after ~4 of the 30 tier days she owns
	// roughly 4/30 of the tier distribution
	uassert.True(t, collected > tier30Total*3/30)
	uassert.True(t, collected < tier30Total*5/30)
	uassert.Equal(t, collected, tier30Collected)
}

func captureV1Snapshot() {
	v1ProjectCount = launchpad.GetProjects().Size()
	v1ProjectName, _ = launchpad.GetProjectName(projectId)
	v1ProjectTokenPath, _ = launchpad.GetProjectTokenPath(projectId)
	v1ProjectRecipient, _ = launchpad.GetProjectRecipient(projectId)
	v1ProjectDeposit, _ = launchpad.GetProjectDepositAmount(projectId)
	v1Tier30Total, _ = launchpad.GetProjectTierTotalDistributeAmount(projectId, 30)
	v1Tier90Total, _ = launchpad.GetProjectTierTotalDistributeAmount(projectId, 90)
	v1Tier180Total, _ = launchpad.GetProjectTierTotalDistributeAmount(projectId, 180)
	v1Tier30Start, _ = launchpad.GetProjectTierStartTime(projectId, 30)
	v1Tier30End, _ = launchpad.GetProjectTierEndTime(projectId, 30)
	v1DepositCount = launchpad.GetDepositCount()
	v1DepositAmount, _ = launchpad.GetDepositAmount(depositId)
	v1DepositTier, _ = launchpad.GetDepositTier(depositId)
	v1DepositProjectID, _ = launchpad.GetDepositProjectID(depositId)
	v1TotalGNSStaked = launchpad.GetTotalGNSStakedAmount()
	v1RewardManagers = launchpad.GetProjectTierRewardManagerCount()
	v1RewardTotalAmount, _ = launchpad.GetProjectTierRewardTotalDistributeAmount(tier30Id)
	v1ProjectActive, _ = launchpad.GetProjectActiveStatus(projectId)

	println("[EXPECTED] snapshot project count:", v1ProjectCount)
	println("[EXPECTED] snapshot project deposit amount:", v1ProjectDeposit)
	println("[EXPECTED] snapshot tier totals:", v1Tier30Total, v1Tier90Total, v1Tier180Total)
	println("[EXPECTED] snapshot deposit count / amount:", v1DepositCount, v1DepositAmount)
	println("[EXPECTED] snapshot total GNS staked:", v1TotalGNSStaked)
	println("[EXPECTED] snapshot reward manager count:", v1RewardManagers)
	println("[EXPECTED] snapshot tier 30 reward total:", v1RewardTotalAmount)
	println("[EXPECTED] snapshot project active:", v1ProjectActive)
}

func upgradeTo(cur realm, packagePath string) {
	testing.SetRealm(adminRealm)
	launchpad.UpgradeImpl(cross(cur), packagePath)
	println("[EXPECTED] implementation:", launchpad.GetImplementationPackagePath())
	uassert.Equal(t, packagePath, launchpad.GetImplementationPackagePath())
}

func validateSnapshot() {
	projectName, _ := launchpad.GetProjectName(projectId)
	tokenPath, _ := launchpad.GetProjectTokenPath(projectId)
	recipient, _ := launchpad.GetProjectRecipient(projectId)
	deposit, _ := launchpad.GetProjectDepositAmount(projectId)
	tier30Total, _ := launchpad.GetProjectTierTotalDistributeAmount(projectId, 30)
	tier90Total, _ := launchpad.GetProjectTierTotalDistributeAmount(projectId, 90)
	tier180Total, _ := launchpad.GetProjectTierTotalDistributeAmount(projectId, 180)
	tier30Start, _ := launchpad.GetProjectTierStartTime(projectId, 30)
	tier30End, _ := launchpad.GetProjectTierEndTime(projectId, 30)
	depositValue, _ := launchpad.GetDepositAmount(depositId)
	depositTier, _ := launchpad.GetDepositTier(depositId)
	depositProject, _ := launchpad.GetDepositProjectID(depositId)
	rewardTotal, err := launchpad.GetProjectTierRewardTotalDistributeAmount(tier30Id)
	uassert.NoError(t, err)
	projectActive, err := launchpad.GetProjectActiveStatus(projectId)
	uassert.NoError(t, err)

	uassert.Equal(t, v1ProjectCount, launchpad.GetProjects().Size())
	uassert.Equal(t, v1ProjectName, projectName)
	uassert.Equal(t, v1ProjectTokenPath, tokenPath)
	uassert.Equal(t, v1ProjectRecipient, recipient)
	uassert.Equal(t, v1ProjectDeposit, deposit)
	uassert.Equal(t, v1Tier30Total, tier30Total)
	uassert.Equal(t, v1Tier90Total, tier90Total)
	uassert.Equal(t, v1Tier180Total, tier180Total)
	uassert.Equal(t, v1Tier30Start, tier30Start)
	uassert.Equal(t, v1Tier30End, tier30End)
	uassert.Equal(t, v1DepositAmount, depositValue)
	uassert.Equal(t, v1DepositTier, depositTier)
	uassert.Equal(t, v1DepositProjectID, depositProject)
	uassert.Equal(t, v1RewardManagers, launchpad.GetProjectTierRewardManagerCount())
	uassert.Equal(t, v1RewardTotalAmount, rewardTotal)
	uassert.Equal(t, v1ProjectActive, projectActive)

	println("[EXPECTED] project / tier / deposit / reward-manager data is unchanged")
	println("[EXPECTED] project deposit amount:", deposit)
	println("[EXPECTED] deposit amount:", depositValue)
	println("[EXPECTED] tier 30 reward total:", rewardTotal)
}

func depositWithV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), bobAddr, depositAmount)

	testing.SetRealm(bobRealm)
	gns.Approve(cross(cur), launchpadAddr, depositAmount)
	depositId2 = launchpad.DepositGns(cross(cur), tier30Id, depositAmount, "")
	testing.SkipHeights(1)

	println("[EXPECTED] second deposit id:", depositId2)
	println("[EXPECTED] deposit count:", launchpad.GetDepositCount())
	println("[EXPECTED] total GNS staked:", launchpad.GetTotalGNSStakedAmount())
	println("[EXPECTED] tier 30 deposit count:", launchpad.GetProjectTierRewards(projectId, 30).Size())

	uassert.Equal(t, v1DepositCount+1, launchpad.GetDepositCount())
	uassert.Equal(t, v1TotalGNSStaked+depositAmount, launchpad.GetTotalGNSStakedAmount())
}

func collectDepositAfterUpgrade(cur realm) {
	// the principal is only withdrawable once the tier has ended
	tier30End, err := launchpad.GetProjectTierEndTime(projectId, 30)
	if err != nil {
		panic(err)
	}
	if remaining := tier30End - time.Now().Unix(); remaining > 0 {
		testing.SkipHeights(remaining/blockTimeSeconds + 1)
	}

	testing.SetRealm(aliceRealm)
	principal, err := launchpad.CollectDepositGns(cross(cur), depositId)
	if err != nil {
		panic(err)
	}
	testing.SkipHeights(1)

	withdrawnAt, _ := launchpad.GetDepositWithdrawnTime(depositId)
	tierWithdrawn, _ := launchpad.GetProjectTierTotalWithdrawAmount(projectId, 30)

	println("[EXPECTED] collected principal:", principal)
	println("[EXPECTED] deposit is marked withdrawn:", withdrawnAt > 0)
	println("[EXPECTED] tier 30 total withdrawn:", tierWithdrawn)
	println("[EXPECTED] total GNS staked after withdrawal:", launchpad.GetTotalGNSStakedAmount())

	uassert.Equal(t, depositAmount, principal)
	uassert.True(t, withdrawnAt > 0)
	uassert.Equal(t, depositAmount, tierWithdrawn)
	// only bob's deposit is left staked
	uassert.Equal(t, depositAmount, launchpad.GetTotalGNSStakedAmount())
}

func collectProjectRewards(cur realm) {
	// these route into gov/staker's launchpad-only entry points
	testing.SetRealm(projectRealm)
	launchpad.CollectEmissionReward(cross(cur))
	launchpad.CollectProtocolFee(cross(cur))
	testing.SkipHeights(1)
	println("[EXPECTED] project recipient collected the gov-staker side rewards")
}

func transferLeftAfterUpgrade(cur realm) {
	tier180End, err := launchpad.GetProjectTierEndTime(projectId, 180)
	if err != nil {
		panic(err)
	}
	if remaining := tier180End - time.Now().Unix(); remaining > 0 {
		testing.SkipHeights(remaining/blockTimeSeconds + 1)
	}

	testing.SetRealm(adminRealm)
	left := launchpad.TransferLeftFromProjectByAdmin(cross(cur), projectId, projectAddr)
	testing.SkipHeights(1)

	tier30Collected, _ := launchpad.GetProjectTierTotalCollectedAmount(projectId, 30)
	println("[EXPECTED] leftover transferred:", left)
	println("[EXPECTED] tier 30 total collected:", tier30Collected)
	println("[EXPECTED] implementation:", launchpad.GetImplementationPackagePath())

	// nothing may be handed out twice: what is swept plus what was collected
	// can never exceed the funded reward amount
	uassert.True(t, left+tier30Collected <= rewardAmount)
}

func assertAborts(cur realm, callback func(), logMessage string) {
	uassert.AbortsContains(t, cur, "implementation", callback)
	println(logMessage)
}

// Output:
// [SCENARIO] 1. Initialize launchpad contract with v1
// [EXPECTED] implementation: gno.land/r/gnoswap/launchpad/v1
//
// [SCENARIO] 2. Create a project with v1
// [EXPECTED] project id: gno.land/r/onbloc/obl.OBL:123
// [EXPECTED] project name: OBL launchpad project
// [EXPECTED] project token path: gno.land/r/onbloc/obl.OBL
// [EXPECTED] project recipient is the project owner: true
// [EXPECTED] project deposit amount: 1000000000
// [EXPECTED] tier distribute amounts (30/90/180): 100000000 200000000 700000000
//
// [SCENARIO] 3. Deposit GNS into tier 30 with v1
// [EXPECTED] deposit id: 1
// [EXPECTED] deposit amount: 1000000
// [EXPECTED] deposit tier: 30
// [EXPECTED] deposit project id matches: true
// [EXPECTED] deposit count: 1
// [EXPECTED] total GNS staked: 1000000
// [EXPECTED] gov staker project wallet: 1000000 found: true
//
// [SCENARIO] 4. Collect the tier 30 reward with v1
// [EXPECTED] collected reward: 13333719
// [EXPECTED] tier 30 total collected: 13333719
//
// [SCENARIO] 5. Snapshot v1 data through the getters
// [EXPECTED] snapshot project count: 1
// [EXPECTED] snapshot project deposit amount: 1000000000
// [EXPECTED] snapshot tier totals: 100000000 200000000 700000000
// [EXPECTED] snapshot deposit count / amount: 1 1000000
// [EXPECTED] snapshot total GNS staked: 1000000
// [EXPECTED] snapshot reward manager count: 3
// [EXPECTED] snapshot tier 30 reward total: 100000000
// [EXPECTED] snapshot project active: true
//
// [SCENARIO] 6. Upgrade to v2_invalid and prove the calls are blocked
// [EXPECTED] implementation: gno.land/r/gnoswap/launchpad/v2_invalid
// [EXPECTED] DepositGns is blocked by v2_invalid
// [EXPECTED] CollectRewardByDepositId is blocked by v2_invalid
// [EXPECTED] the getters are blocked by v2_invalid too
//
// [SCENARIO] 6-1. Upgrade to v2_valid and validate the v1 data
// [EXPECTED] implementation: gno.land/r/gnoswap/launchpad/v2_valid
// [EXPECTED] project / tier / deposit / reward-manager data is unchanged
// [EXPECTED] project deposit amount: 1000000000
// [EXPECTED] deposit amount: 1000000
// [EXPECTED] tier 30 reward total: 100000000
//
// [SCENARIO] 7. Second deposit through v2_valid on the v1-created tier
// [EXPECTED] second deposit id: 2
// [EXPECTED] deposit count: 2
// [EXPECTED] total GNS staked: 2000000
// [EXPECTED] tier 30 deposit count: 2
//
// [SCENARIO] 8. Re-validate the v1 data after the v2_valid write
// [EXPECTED] project / tier / deposit / reward-manager data is unchanged
// [EXPECTED] project deposit amount: 1000000000
// [EXPECTED] deposit amount: 1000000
// [EXPECTED] tier 30 reward total: 100000000
//
// [SCENARIO] 9. Collect the deposit principal after the tier ends
// [EXPECTED] collected principal: 1000000
// [EXPECTED] deposit is marked withdrawn: true
// [EXPECTED] tier 30 total withdrawn: 1000000
// [EXPECTED] total GNS staked after withdrawal: 1000000
//
// [SCENARIO] 10. Project recipient collects the launchpad-side rewards
// [EXPECTED] project recipient collected the gov-staker side rewards
//
// [SCENARIO] 11. Admin sweeps the leftovers after the project ends
// [EXPECTED] leftover transferred: 900000001
// [EXPECTED] tier 30 total collected: 56666957
// [EXPECTED] implementation: gno.land/r/gnoswap/launchpad/v2_valid
