// PKGPATH: gno.land/r/gnoswap/v1/main

// check delegate voting power without launchpad
//
// Scenario:
// 1. Delegate GNS from alice to alice
// 2. Check xGNS balance of alice and admin
// 3. Propose text check quorum amount and voting power
// 4. Create Launchpad project and deposit GNS to launchpad
// 5. Propose text check quorum amount and voting power (without launchpad)

package main

import (
	"fmt"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/gov/governance"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/launchpad"

	_ "gno.land/r/gnoswap/gov/governance/v1"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/launchpad/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"
	_ "gno.land/r/gnoswap/router/v1"
	"gno.land/r/onbloc/bar"

	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gov/staker"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	poolAddr      = access.MustGetAddress(prbac.ROLE_POOL.String())
	stakerAddr    = access.MustGetAddress(prbac.ROLE_STAKER.String())
	gnoStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	launchpadAddr = access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())
	routerAddr    = access.MustGetAddress(prbac.ROLE_ROUTER.String())

	aliceAddr = testutils.TestAddress("alice")

	gnsPath = "gno.land/r/gnoswap/gns"
	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	blockTime = int64(5)
)

func main(cur realm) {
	println("[SCENARIO] 1. Delegate GNS from alice to alice")
	initGNSBalance(cur)
	delegateWithMint(cur, aliceAddr, aliceAddr, 1_000_000_000)
	testing.SkipHeights(60 * 60 * 24 / blockTime) // 1 days later, voting weight smoothing duration
	println()

	println("[SCENARIO] 2. Check xGNS balance of alice and admin")
	checkXgnsBalance(cur, "alice", aliceAddr)
	checkXgnsBalance(cur, "admin", adminAddr)
	checkXgnsBalance(cur, "launchpad", launchpadAddr)
	println()

	println("[SCENARIO] 3. Propose text check quorum amount and voting power")
	println("[SCENARIO] 3.1. Propose text")
	proposalId := proposeText(cur, "Proposal 1")
	println()

	println("[SCENARIO] 3.2. Skip heights to activate proposal")
	testing.SkipHeights(60 * 60 * 24 / blockTime) // 1 days later, voting start delay
	println()

	println("[SCENARIO] 3.3. Vote proposal with alice")
	voteProposal(cur, proposalId, aliceAddr)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3.4. Check quorum amount and voting power")
	checkQuorumAmountAndVotingPower(cur, proposalId)
	println()

	println("[SCENARIO] 4. Create Launchpad project and deposit GNS to launchpad")
	println("[SCENARIO] 4.1. Create Launchpad project")
	projectId := createLaunchpadProjectByAdmin(cur)
	println()

	println("[SCENARIO] 4.2. Skip heights to activate project")
	testing.SkipHeights(60 * 60 * 24 * 7 / blockTime) // 7 days later, project start time
	println()

	println("[SCENARIO] 4.3. Deposit GNS to launchpad")
	depositGnsToLaunchpad(cur, projectId, 30, 1_000_000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4.4. Check xGNS balance of alice and admin")
	checkXgnsBalance(cur, "alice", aliceAddr)
	checkXgnsBalance(cur, "admin", adminAddr)
	checkXgnsBalance(cur, "launchpad", launchpadAddr)
	println()

	println("[SCENARIO] 5. Propose text check quorum amount and voting power (without launchpad)")
	println("[SCENARIO] 5.1. Propose text")
	proposalId = proposeText(cur, "Proposal 2")
	println()

	println("[SCENARIO] 5.2. Skip heights to activate proposal")
	testing.SkipHeights(60 * 60 * 24 / blockTime) // 1 days later, voting start delay
	println()

	println("[SCENARIO] 5.3. Vote proposal with alice")
	voteProposal(cur, proposalId, aliceAddr)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 5.4. Check quorum amount and voting power (without launchpad)")
	checkQuorumAmountAndVotingPower(cur, proposalId)
	println()

	println("[SCENARIO] 6. Check xGNS balance of alice and admin")
	checkXgnsBalance(cur, "alice", aliceAddr)
	checkXgnsBalance(cur, "admin", adminAddr)
	checkXgnsBalance(cur, "launchpad", launchpadAddr)
	println()
}

func initGNSBalance(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), aliceAddr, 1_000_000_000)
}

func delegateWithMint(cur realm, from, to address, amount int64) {
	// if from is not admin, transfer GNS from admin to from
	if from != adminAddr {
		testing.SetRealm(adminRealm)
		gns.Transfer(cross(cur), from, amount)
	}

	testing.SetRealm(testing.NewUserRealm(from))
	gns.Approve(cross(cur), gnoStakerAddr, amount)
	staker.Delegate(cross(cur), to, int64(amount), "")

	ufmt.Printf("[INFO] delegated %d GNS from %s to %s\n", amount, from, to)
}

func proposeText(cur realm, title string) int64 {
	testing.SetRealm(testing.NewUserRealm(aliceAddr))

	proposalId := governance.ProposeText(cross(cur), title, "description")
	ufmt.Printf("[INFO] created proposal ID: %d\n", proposalId)
	return proposalId
}

func voteProposal(cur realm, proposalId int64, addr address) {
	testing.SetRealm(testing.NewUserRealm(addr))
	governance.Vote(cross(cur), proposalId, true)
	ufmt.Printf("[INFO] voted for proposal ID: %d\n", proposalId)
}

func checkQuorumAmountAndVotingPower(cur realm, proposalId int64) {
	testing.SetRealm(testing.NewUserRealm(aliceAddr))
	quorumAmount, _ := governance.GetQuorumAmountByProposalId(proposalId)
	votingPower, _ := governance.GetVoteWeight(proposalId, aliceAddr)
	yeaWeight, _ := governance.GetYeaByProposalId(proposalId)
	nayWeight, _ := governance.GetNayByProposalId(proposalId)
	ufmt.Printf("[EXPECTED] Proposal %d's quorum amount: %d\n", proposalId, quorumAmount)
	ufmt.Printf("[EXPECTED] Proposal %d's alice voting power: %d\n", proposalId, votingPower)
	ufmt.Printf("[EXPECTED] Proposal %d's yea weight: %d, nay weight: %d\n", proposalId, yeaWeight, nayWeight)
}

func createLaunchpadProjectByAdmin(cur realm) string {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), launchpadAddr, 10000000)
	currentTime := time.Now().Unix()

	projectID := launchpad.CreateProject(
		cross(cur),
		"Test Project",
		"gno.land/r/onbloc/bar",
		aliceAddr,
		10000000,
		"",
		"",
		20,
		30,
		50,
		currentTime+60*60*24*7, // 7 days later
	)

	ufmt.Printf("[EXPECTED] Project created: %s\n", projectID)
	return projectID
}

func depositGnsToLaunchpad(cur realm, projectID string, tier int64, amount int64) {
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), launchpadAddr, amount)
	targetProjectTierID := fmt.Sprintf("%s:%d", projectID, tier)
	launchpad.DepositGns(cross(cur), targetProjectTierID, amount, "")
	ufmt.Printf("[EXPECTED] deposited GNS to launchpad by admin(tier: %d, amount: %d)\n", tier, amount)
}

func checkXgnsBalance(cur realm, userName string, addr address) {
	balance := xgns.BalanceOf(addr)
	ufmt.Printf("[EXPECTED] %s's xGNS balance: %d\n", userName, balance)
}

func checkBalanceFn(cur realm, tokenPath string, addr address, fn func()) {
	testing.SetRealm(testing.NewUserRealm(addr))

	balanceBefore := common.BalanceOf(tokenPath, addr)
	fn()
	balanceAfter := common.BalanceOf(tokenPath, addr)

	ufmt.Printf("[EXPECTED] %s's balance of %s: %d\n", addr, tokenPath, balanceAfter-balanceBefore)
}

// Output:
// [SCENARIO] 1. Delegate GNS from alice to alice
// [INFO] delegated 1000000000 GNS from g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh to g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
//
// [SCENARIO] 2. Check xGNS balance of alice and admin
// [EXPECTED] alice's xGNS balance: 1000000000
// [EXPECTED] admin's xGNS balance: 0
// [EXPECTED] launchpad's xGNS balance: 0
//
// [SCENARIO] 3. Propose text check quorum amount and voting power
// [SCENARIO] 3.1. Propose text
// [INFO] created proposal ID: 1
//
// [SCENARIO] 3.2. Skip heights to activate proposal
//
// [SCENARIO] 3.3. Vote proposal with alice
// [INFO] voted for proposal ID: 1
//
// [SCENARIO] 3.4. Check quorum amount and voting power
// [EXPECTED] Proposal 1's quorum amount: 500000000
// [EXPECTED] Proposal 1's alice voting power: 1000000000
// [EXPECTED] Proposal 1's yea weight: 1000000000, nay weight: 0
//
// [SCENARIO] 4. Create Launchpad project and deposit GNS to launchpad
// [SCENARIO] 4.1. Create Launchpad project
// [EXPECTED] Project created: gno.land/r/onbloc/bar:34684
//
// [SCENARIO] 4.2. Skip heights to activate project
//
// [SCENARIO] 4.3. Deposit GNS to launchpad
// [EXPECTED] deposited GNS to launchpad by admin(tier: 30, amount: 1000000)
//
// [SCENARIO] 4.4. Check xGNS balance of alice and admin
// [EXPECTED] alice's xGNS balance: 1000000000
// [EXPECTED] admin's xGNS balance: 0
// [EXPECTED] launchpad's xGNS balance: 1000000
//
// [SCENARIO] 5. Propose text check quorum amount and voting power (without launchpad)
// [SCENARIO] 5.1. Propose text
// [INFO] created proposal ID: 2
//
// [SCENARIO] 5.2. Skip heights to activate proposal
//
// [SCENARIO] 5.3. Vote proposal with alice
// [INFO] voted for proposal ID: 2
//
// [SCENARIO] 5.4. Check quorum amount and voting power (without launchpad)
// [EXPECTED] Proposal 2's quorum amount: 500000000
// [EXPECTED] Proposal 2's alice voting power: 1000000000
// [EXPECTED] Proposal 2's yea weight: 1000000000, nay weight: 0
//
// [SCENARIO] 6. Check xGNS balance of alice and admin
// [EXPECTED] alice's xGNS balance: 1000000000
// [EXPECTED] admin's xGNS balance: 0
// [EXPECTED] launchpad's xGNS balance: 1000000
