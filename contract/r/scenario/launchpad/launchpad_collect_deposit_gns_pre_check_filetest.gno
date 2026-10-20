// launchpad CollectDepositGns pre-checks run before emission minting and reward settlement

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac/v1"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	_ "gno.land/r/gnoswap/rbac/v1"

	"gno.land/r/gnoswap/access/v1"
	_ "gno.land/r/gnoswap/common/v1"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/gnoswap/scenarioutils"
	"gno.land/r/onbloc/obl"
)

var t *testing.T

const (
	blockTime         = int64(5)
	dayTime           = int64(24 * 60 * 60)
	activationSeconds = int64(7) * dayTime
	tier30Seconds     = int64(30) * dayTime
	rewardAmount      = int64(1_000_000_000)
	depositUnit       = int64(1_000_000)
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	projectAddr      = testutils.TestAddress("pre-check-project")

	aliceAddr = testutils.TestAddress("alice")
)

type snapshot struct {
	gnsTotalSupply  int64
	lastEmissionAt  int64
	tierCollected   int64
	aliceOBL        int64
	aliceGNS        int64
	totalGNSStaked  int64
	depositWithdraw int64
}

func main(cur realm) {
	println("[SCENARIO] 1. Start emission and create project with the whole reward in the 30-day tier")
	startEmission(cur)
	projectID, startTime := createProject(cur)
	tierID := projectID + ":30"
	println()

	println("[SCENARIO] 2. Alice deposits before tier start")
	depositID := depositGns(cur, aliceAddr, tierID, depositUnit)
	println()

	println("[SCENARIO] 3. Withdraw at the tier end aborts before minting emission or settling rewards")
	skipTo(startTime + tier30Seconds)
	before := takeSnapshot(projectID, depositID)
	uassert.AbortsContains(t, cur, "[GNOSWAP-LAUNCHPAD-016] project lock period is not over yet", func() {
		testing.SetRealm(testing.NewUserRealm(aliceAddr))
		launchpad.CollectDepositGns(cross(cur), depositID)
	})
	println("[EXPECTED] withdraw aborted at tier end")
	assertUnchanged(before, takeSnapshot(projectID, depositID))
	println()

	println("[SCENARIO] 4. Withdraw one block after the tier end")
	testing.SkipHeights(1)
	before = takeSnapshot(projectID, depositID)
	testing.SetRealm(testing.NewUserRealm(aliceAddr))
	gnsAmount, _ := launchpad.CollectDepositGns(cross(cur), depositID)
	after := takeSnapshot(projectID, depositID)
	assertEqual("GNS principal returned", depositUnit, gnsAmount)
	assertEqual("Alice reward", rewardAmount-1, after.aliceOBL-before.aliceOBL)
	assertEqual("tier collected amount", rewardAmount-1, after.tierCollected)
	assertTrue("emission minted on successful withdraw", after.lastEmissionAt > before.lastEmissionAt)
	println()

	println("[SCENARIO] 5. Second withdraw aborts as already collected without side effects")
	testing.SkipHeights(1)
	before = takeSnapshot(projectID, depositID)
	uassert.AbortsContains(t, cur, "[GNOSWAP-LAUNCHPAD-013] already collected", func() {
		testing.SetRealm(testing.NewUserRealm(aliceAddr))
		launchpad.CollectDepositGns(cross(cur), depositID)
	})
	println("[EXPECTED] second withdraw aborted")
	assertUnchanged(before, takeSnapshot(projectID, depositID))
}

func startEmission(cur realm) {
	testing.SetRealm(adminRealm)
	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	testing.SkipHeights(1)
	println("[INFO] emission started")
}

func createProject(cur realm) (string, int64) {
	startTime := time.Now().Unix() + activationSeconds

	testing.SetRealm(adminRealm)
	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	projectID := launchpad.CreateProject(
		cross(cur),
		"Pre Check Project",
		"gno.land/r/onbloc/obl.OBL",
		projectAddr,
		rewardAmount,
		"",
		"",
		100,
		0,
		0,
		startTime,
	)
	ufmt.Printf("[INFO] project created: id=%s, startTime=now+%d\n", projectID, activationSeconds)
	return projectID, startTime
}

func depositGns(cur realm, userAddr address, projectTierID string, amount int64) string {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), userAddr, amount)

	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross(cur), launchpadAddr, amount)
	depositID := launchpad.DepositGns(cross(cur), projectTierID, amount, "")
	ufmt.Printf("[INFO] deposit created: id=%s, tier=%s, amount=%d\n", depositID, projectTierID, amount)
	return depositID
}

func takeSnapshot(projectID, depositID string) snapshot {
	tierCollected, err := launchpad.GetProjectTierTotalCollectedAmount(projectID, 30)
	if err != nil {
		panic(err.Error())
	}
	withdrawnHeight, err := launchpad.GetDepositWithdrawnHeight(depositID)
	if err != nil {
		panic(err.Error())
	}

	return snapshot{
		gnsTotalSupply:  gns.TotalSupply(),
		lastEmissionAt:  emission.GetLastExecutedTimestamp(),
		tierCollected:   tierCollected,
		aliceOBL:        obl.BalanceOf(aliceAddr),
		aliceGNS:        gns.BalanceOf(aliceAddr),
		totalGNSStaked:  launchpad.GetTotalGNSStakedAmount(),
		depositWithdraw: withdrawnHeight,
	}
}

func assertUnchanged(before, after snapshot) {
	assertEqual("GNS total supply unchanged", before.gnsTotalSupply, after.gnsTotalSupply)
	assertEqual("last emission timestamp unchanged", before.lastEmissionAt, after.lastEmissionAt)
	assertEqual("tier collected amount unchanged", before.tierCollected, after.tierCollected)
	assertEqual("Alice OBL unchanged", before.aliceOBL, after.aliceOBL)
	assertEqual("Alice GNS unchanged", before.aliceGNS, after.aliceGNS)
	assertEqual("total staked GNS unchanged", before.totalGNSStaked, after.totalGNSStaked)
	assertEqual("deposit withdrawn height unchanged", before.depositWithdraw, after.depositWithdraw)
}

func skipTo(targetTime int64) {
	testing.SkipHeights((targetTime - time.Now().Unix()) / blockTime)
}

func assertEqual(label string, expected, actual int64) {
	if expected != actual {
		panic(ufmt.Sprintf("%s: expected %d, got %d", label, expected, actual))
	}
	ufmt.Printf("[EXPECTED] %s: %d\n", label, actual)
}

func assertTrue(label string, ok bool) {
	if !ok {
		panic(label)
	}
	ufmt.Printf("[EXPECTED] %s\n", label)
}

// Output:
// [SCENARIO] 1. Start emission and create project with the whole reward in the 30-day tier
// [INFO] emission started
// [INFO] project created: id=gno.land/r/onbloc/obl.OBL:124, startTime=now+604800
//
// [SCENARIO] 2. Alice deposits before tier start
// [INFO] deposit created: id=1, tier=gno.land/r/onbloc/obl.OBL:124:30, amount=1000000
//
// [SCENARIO] 3. Withdraw at the tier end aborts before minting emission or settling rewards
// [EXPECTED] withdraw aborted at tier end
// [EXPECTED] GNS total supply unchanged: 100000035673515
// [EXPECTED] last emission timestamp unchanged: 1234567895
// [EXPECTED] tier collected amount unchanged: 0
// [EXPECTED] Alice OBL unchanged: 0
// [EXPECTED] Alice GNS unchanged: 0
// [EXPECTED] total staked GNS unchanged: 1000000
// [EXPECTED] deposit withdrawn height unchanged: 0
//
// [SCENARIO] 4. Withdraw one block after the tier end
// [EXPECTED] GNS principal returned: 1000000
// [EXPECTED] Alice reward: 999999999
// [EXPECTED] tier collected amount: 999999999
// [EXPECTED] emission minted on successful withdraw
//
// [SCENARIO] 5. Second withdraw aborts as already collected without side effects
// [EXPECTED] second withdraw aborted
// [EXPECTED] GNS total supply unchanged: 122808289897430
// [EXPECTED] last emission timestamp unchanged: 1237764700
// [EXPECTED] tier collected amount unchanged: 999999999
// [EXPECTED] Alice OBL unchanged: 999999999
// [EXPECTED] Alice GNS unchanged: 1000000
// [EXPECTED] total staked GNS unchanged: 0
// [EXPECTED] deposit withdrawn height unchanged: 639485
