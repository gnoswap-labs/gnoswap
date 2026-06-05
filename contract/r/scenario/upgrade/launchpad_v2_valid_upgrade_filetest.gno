// PKGPATH: gno.land/r/gnoswap/v1/main

// Launchpad contract upgrade to v2_valid scenario test.
//
// v2_valid is a symlinked copy of the v1 launchpad sources published under a
// v2_valid module path. This test targets the interrealm-v2 readonly-taint
// concern: rich launchpad state (projects with per-project tier maps and
// condition maps, the deposits BPTree, and per-tier reward managers with their
// reward-state BPTrees) is created by the v1 implementation realm, the active
// implementation is then switched to v2_valid, and the SAME v1-created data is
// mutated through v2_valid via every state-changing entry point.
//
// The launchpad migration rebuilds these maps as realm-owned
// (SetConditions/SetTiers/SetCondition/SetTier) and allocates trees through a
// domain NewBPTreeN helper precisely so that writes route through domain-owned
// structures. Mutating v1-created data through v2_valid must therefore NOT
// trigger a readonly-taint panic. A PASS proves the migration path is
// taint-safe across the whole mutating surface of the launchpad.
//
// Mutating entry points exercised AFTER the upgrade to v2_valid:
//   - DepositGns                     : second deposit to the v1-created tier
//                                      (RMW project tier map + deposits BPTree +
//                                      tier reward manager reward-state BPTree).
//   - CreateProject                  : a SECOND project created entirely under
//                                      v2_valid (projects BPTree insert + tier
//                                      and condition map build post-upgrade —
//                                      the strongest realm-owned rebuild test).
//   - CollectRewardByDepositId       : collect accrued reward on the v1-created
//                                      deposit (RMW reward-state tree).
//   - CollectDepositGns              : withdraw the v1-created deposit after its
//                                      tier lock ends (RMW deposit + project
//                                      tier + reward-state tree removal).
//   - TransferLeftFromProjectByAdmin : refund the project's leftover reward
//                                      after the project ends (RMW project).
//   - CollectProtocolFee             : collect protocol fee for the project
//                                      recipient wallet (RMW via gov staker).
package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/launchpad"
	"gno.land/r/onbloc/obl"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	_ "gno.land/r/gnoswap/launchpad/v1"
	_ "gno.land/r/gnoswap/launchpad/v2_valid"
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = testing.NewUserRealm(user1Addr)

	user2Addr  = testutils.TestAddress("user2")
	user2Realm = testing.NewUserRealm(user2Addr)

	projectAddr  = testutils.TestAddress("project1")
	projectRealm = testing.NewUserRealm(projectAddr)
)

const (
	launchpadV1Path      = "gno.land/r/gnoswap/launchpad/v1"
	launchpadV2ValidPath = "gno.land/r/gnoswap/launchpad/v2_valid"

	// Block time is 5 seconds in the test harness.
	day30Heights = int64(30 * 24 * 60 * 60 / 5)  // tier30 lock duration
	day7Heights  = int64(7 * 24 * 60 * 60 / 5)   // project start delay used at creation
	day180Heights = int64(180 * 24 * 60 * 60 / 5) // tier180 (project end)
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize launchpad contract with v1")
	initializeV1(cur)
	println()

	println("[SCENARIO] 2. Create project + first deposit with v1")
	projectId := createProjectV1(cur)
	tier30Id := projectId + ":30"
	depositId := depositGnsV1(cur, tier30Id)
	println()

	println("[SCENARIO] 3. Read v1-created data via getters")
	printState(cur, projectId, depositId)
	println()

	println("[SCENARIO] 4. Upgrade launchpad implementation to v2_valid")
	upgradeToV2Valid(cur)
	println()

	println("[SCENARIO] 5. DepositGns through v2_valid (taint-prone RMW)")
	depositId2 := depositGnsV2Valid(cur, tier30Id)
	printState(cur, projectId, depositId2)
	println()

	println("[SCENARIO] 6. CreateProject through v2_valid (projects BPTree insert)")
	projectId2 := createProjectV2Valid(cur)
	printProjectSummary(cur, projectId2)
	println()

	println("[SCENARIO] 7. CollectRewardByDepositId on v1 deposit through v2_valid")
	collectRewardV2Valid(cur, depositId)
	println()

	println("[SCENARIO] 8. CollectProtocolFee for project recipient through v2_valid")
	collectProtocolFeeV2Valid(cur)
	println()

	println("[SCENARIO] 9. CollectDepositGns on v1 deposit after tier lock ends")
	collectDepositV2Valid(cur, projectId, depositId)
	println()

	println("[SCENARIO] 10. TransferLeftFromProjectByAdmin after project ends")
	transferLeftV2Valid(cur, projectId)
	println()
}

func initializeV1(cur realm) {
	testing.SetRealm(adminRealm)
	launchpad.UpgradeImpl(cross(cur), launchpadV1Path)
	ufmt.Printf("[EXPECTED] launchpad implementation: %s\n", launchpad.GetImplementationPackagePath())
}

func createProjectV1(cur realm) string {
	testing.SetRealm(adminRealm)

	rewardAmount := int64(10_000_000)
	startTime := int64(time.Now().Unix() + 604800) // 7 days from now

	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	projectId := launchpad.CreateProject(
		cross(cur),
		"Test OBL Project",
		"gno.land/r/onbloc/obl",
		projectAddr,
		rewardAmount,
		"",
		"",
		int64(30),
		int64(30),
		int64(40),
		startTime,
	)

	// advance time/height past tier start so deposits are accepted
	testing.SkipHeights(day7Heights)

	ufmt.Printf("[EXPECTED] project created: %s\n", projectId)
	return projectId
}

// depositGnsV1 performs the first deposit through the v1 implementation.
// It creates a deposit in the deposits BPTree and RMWs the project's tier map
// and the tier reward manager.
func depositGnsV1(cur realm, tier30Id string) string {
	depositAmount := int64(1_000_000)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), user1Addr, depositAmount*2)

	testing.SetRealm(user1Realm)
	gns.Approve(cross(cur), launchpadAddr, depositAmount*2)
	depositId := launchpad.DepositGns(cross(cur), tier30Id, depositAmount, "")

	ufmt.Printf("[EXPECTED] v1 deposit created: %s\n", depositId)
	return depositId
}

func upgradeToV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	launchpad.UpgradeImpl(cross(cur), launchpadV2ValidPath)
	ufmt.Printf("[EXPECTED] launchpad implementation: %s\n", launchpad.GetImplementationPackagePath())
}

// depositGnsV2Valid performs a second deposit on the SAME v1-created project
// tier, but through the v2_valid implementation. This RMWs v1-created data:
// the project struct in the projects BPTree, the project's tier map (SetTier),
// the deposits BPTree (Set), and the tier reward manager's reward-state BPTree.
// A readonly-taint regression in the migration's SetTier/SetCondition routing
// would panic here.
func depositGnsV2Valid(cur realm, tier30Id string) string {
	depositAmount := int64(2_000_000)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), user2Addr, depositAmount*2)

	testing.SetRealm(user2Realm)
	gns.Approve(cross(cur), launchpadAddr, depositAmount*2)
	depositId := launchpad.DepositGns(cross(cur), tier30Id, depositAmount, "")

	ufmt.Printf("[EXPECTED] v2_valid deposit created: %s\n", depositId)
	return depositId
}

// createProjectV2Valid creates a SECOND project entirely through v2_valid.
// This inserts a new node into the projects BPTree and builds the project's
// tier and condition maps as realm-owned structures under the v2_valid realm.
// It is the strongest test that the realm-owned map/tree rebuild works after
// the implementation switch.
func createProjectV2Valid(cur realm) string {
	testing.SetRealm(adminRealm)

	rewardAmount := int64(20_000_000)
	startTime := int64(time.Now().Unix() + 604800) // 7 days from now

	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	projectId := launchpad.CreateProject(
		cross(cur),
		"Second OBL Project",
		"gno.land/r/onbloc/obl",
		projectAddr,
		rewardAmount,
		"",
		"",
		int64(20),
		int64(30),
		int64(50),
		startTime,
	)

	ufmt.Printf("[EXPECTED] v2_valid project created: %s\n", projectId)
	return projectId
}

// collectRewardV2Valid advances time so reward accrues on the v1-created
// deposit, then collects it through v2_valid. This RMWs the tier reward
// manager and the deposit's reward-state node in the reward-state BPTree.
func collectRewardV2Valid(cur realm, depositId string) {
	// advance ~5 days into the tier30 distribution window so reward accrues
	testing.SkipHeights(day7Heights)

	testing.SetRealm(user1Realm)
	reward := launchpad.CollectRewardByDepositId(cross(cur), depositId)

	ufmt.Printf("[EXPECTED] collected reward (deposit %s): %d\n", depositId, reward)
}

// collectProtocolFeeV2Valid collects protocol fee for the project recipient
// wallet through v2_valid. The recipient was registered as a launchpad project
// wallet in gov staker during DepositGns, so the existence check passes. There
// is no protocol fee accrued to the wallet in this filetest, so this exercises
// the RMW/transfer path and asserts taint-safety without a variable amount.
func collectProtocolFeeV2Valid(cur realm) {
	testing.SetRealm(projectRealm)
	launchpad.CollectProtocolFee(cross(cur))

	ufmt.Printf("[EXPECTED] protocol fee collected for recipient: %s\n", projectAddr.String())
}

// collectDepositV2Valid advances time past the tier30 lock and withdraws the
// v1-created deposit through v2_valid. This RMWs the deposit (marks withdrawn),
// the project tier, and removes the deposit's reward-state node from the tree.
func collectDepositV2Valid(cur realm, projectId, depositId string) {
	// advance past the tier30 lock (30 days from start) so the deposit ends
	testing.SkipHeights(day30Heights)

	testing.SetRealm(user1Realm)
	amount, err := launchpad.CollectDepositGns(cross(cur), depositId)
	if err != nil {
		panic(err)
	}

	tierTotalDeposit, _ := launchpad.GetProjectTierTotalDepositAmount(projectId, 30)
	tierDepositCount := launchpad.GetProjectTierDepositCount(projectId, 30)
	ufmt.Printf("[EXPECTED] withdrawn deposit (deposit %s): %d\n", depositId, amount)
	ufmt.Printf("[EXPECTED] tier30 after withdraw totalDeposit=%d depositCount=%d\n", tierTotalDeposit, tierDepositCount)
}

// transferLeftV2Valid advances time past the project end (tier180) and refunds
// the project's leftover reward through v2_valid. This RMWs the project struct
// stored in the projects BPTree.
func transferLeftV2Valid(cur realm, projectId string) {
	// advance past tier180 end so the project is considered ended
	testing.SkipHeights(day180Heights)

	testing.SetRealm(adminRealm)
	left := launchpad.TransferLeftFromProjectByAdmin(cross(cur), projectId, projectAddr)

	ufmt.Printf("[EXPECTED] transferred left reward (project %s): %d\n", projectId, left)
}

func printState(cur realm, projectId, depositId string) {
	project, _ := launchpad.GetProject(projectId)
	tierTotalDeposit, _ := launchpad.GetProjectTierTotalDepositAmount(projectId, 30)
	tierDepositCount := launchpad.GetProjectTierDepositCount(projectId, 30)
	depositAmount, _ := launchpad.GetDepositAmount(depositId)
	depositTier, _ := launchpad.GetDepositTier(depositId)

	ufmt.Printf("[EXPECTED] project=%s name=%s deposit=%d\n", project.ID(), project.Name(), project.DepositAmount())
	ufmt.Printf("[EXPECTED] tier30 totalDeposit=%d depositCount=%d\n", tierTotalDeposit, tierDepositCount)
	ufmt.Printf("[EXPECTED] deposit id=%s amount=%d tier=%d\n", depositId, depositAmount, depositTier)
}

func printProjectSummary(cur realm, projectId string) {
	project, _ := launchpad.GetProject(projectId)
	tier30Total, _ := launchpad.GetProjectTierTotalDistributeAmount(projectId, 30)
	tier90Total, _ := launchpad.GetProjectTierTotalDistributeAmount(projectId, 90)
	tier180Total, _ := launchpad.GetProjectTierTotalDistributeAmount(projectId, 180)

	ufmt.Printf("[EXPECTED] project=%s name=%s deposit=%d\n", project.ID(), project.Name(), project.DepositAmount())
	ufmt.Printf("[EXPECTED] tier distribute 30=%d 90=%d 180=%d\n", tier30Total, tier90Total, tier180Total)
}

// Output:
// [SCENARIO] 1. Initialize launchpad contract with v1
// [EXPECTED] launchpad implementation: gno.land/r/gnoswap/launchpad/v1
//
// [SCENARIO] 2. Create project + first deposit with v1
// [EXPECTED] project created: gno.land/r/onbloc/obl:123
// [EXPECTED] v1 deposit created: 1
//
// [SCENARIO] 3. Read v1-created data via getters
// [EXPECTED] project=gno.land/r/onbloc/obl:123 name=Test OBL Project deposit=10000000
// [EXPECTED] tier30 totalDeposit=1000000 depositCount=1
// [EXPECTED] deposit id=1 amount=1000000 tier=30
//
// [SCENARIO] 4. Upgrade launchpad implementation to v2_valid
// [EXPECTED] launchpad implementation: gno.land/r/gnoswap/launchpad/v2_valid
//
// [SCENARIO] 5. DepositGns through v2_valid (taint-prone RMW)
// [EXPECTED] v2_valid deposit created: 2
// [EXPECTED] project=gno.land/r/onbloc/obl:123 name=Test OBL Project deposit=10000000
// [EXPECTED] tier30 totalDeposit=3000000 depositCount=2
// [EXPECTED] deposit id=2 amount=2000000 tier=30
//
// [SCENARIO] 6. CreateProject through v2_valid (projects BPTree insert)
// [EXPECTED] v2_valid project created: gno.land/r/onbloc/obl:121083
// [EXPECTED] project=gno.land/r/onbloc/obl:121083 name=Second OBL Project deposit=20000000
// [EXPECTED] tier distribute 30=4000000 90=6000000 180=10000000
//
// [SCENARIO] 7. CollectRewardByDepositId on v1 deposit through v2_valid
// [EXPECTED] collected reward (deposit 1): 233333
//
// [SCENARIO] 8. CollectProtocolFee for project recipient through v2_valid
// [EXPECTED] protocol fee collected for recipient: g1wpex76n9vd6rzh6lta047h6lta047h6lztprp7
//
// [SCENARIO] 9. CollectDepositGns on v1 deposit after tier lock ends
// [EXPECTED] withdrawn deposit (deposit 1): 1000000
// [EXPECTED] tier30 after withdraw totalDeposit=3000000 depositCount=1
//
// [SCENARIO] 10. TransferLeftFromProjectByAdmin after project ends
// [EXPECTED] transferred left reward (project gno.land/r/onbloc/obl:123): 7000002
//
