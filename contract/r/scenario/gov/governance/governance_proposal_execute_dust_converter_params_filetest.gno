// governance proposal execute - dust converter parameter changes

package main

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	dc "gno.land/r/gnoswap/dust_converter"

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"

	govStaker "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr        = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr    = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	currentBlockTime = int64(2)
)

func main() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config := governance.GetLatestConfig()

	println("[SCENARIO] 1. Delegate gns to admin")
	delegateGnsToAdmin()
	println()

	println("[SCENARIO] 2. Skip voting smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 3. Check dust converter params before proposal")
	checkDustConverterParams()
	println()

	println("[SCENARIO] 4. Check dust converter target assets before proposal")
	checkDustConverterTargets()
	println()

	println("[SCENARIO] 5. Propose dust converter parameter changes")
	proposalID := proposeDustConverterParams()
	println()

	println("[SCENARIO] 6. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 7. Vote for the proposal")
	vote(proposalID, true)
	println()

	println("[SCENARIO] 8. Skip voting period for ready to execute")
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 9. Execute the dust converter parameter changes")
	executeDustConverterParams(proposalID)
	println()

	println("[SCENARIO] 10. Check dust converter params after execution")
	checkDustConverterParams()
	println()

	println("[SCENARIO] 11. Check dust converter target assets after execution")
	checkDustConverterTargets()
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gns.Approve(cross, govStakerAddr, delegatedAmount)
	govStaker.Delegate(cross, adminAddr, int64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func checkDustConverterParams() {
	minAmount := dc.GetDustMinAmount()
	maxAmount := dc.GetDustMaxAmount()
	cooldown := dc.GetCooldownSeconds()

	ufmt.Printf("[INFO] DustMinAmount: %d, DustMaxAmount: %d, CooldownSeconds: %d\n", minAmount, maxAmount, cooldown)
}

func checkDustConverterTargets() {
	testTarget := "gno.land/r/demo/token"
	gnsTarget := "gno.land/r/gnoswap/gns"

	ufmt.Printf(
		"[INFO] Target assets - gns: %t, demo: %t\n",
		dc.IsTargetAsset(gnsTarget),
		dc.IsTargetAsset(testTarget),
	)
}

func proposeDustConverterParams() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	executions := "gno.land/r/gnoswap/dust_converter*EXE*SetDustMaxAmount*EXE*100*GOV*" +
		"gno.land/r/gnoswap/dust_converter*EXE*SetDustMinAmount*EXE*20*GOV*" +
		"gno.land/r/gnoswap/dust_converter*EXE*SetCooldownSeconds*EXE*3600*GOV*" +
		"gno.land/r/gnoswap/dust_converter*EXE*AddTargetAsset*EXE*gno.land/r/demo/token*GOV*" +
		"gno.land/r/gnoswap/dust_converter*EXE*RemoveTargetAsset*EXE*gno.land/r/gnoswap/gns"

	proposalID := governance.ProposeParameterChange(
		cross,
		"dust_converter",
		"update dust converter params",
		5,
		executions,
	)

	ufmt.Printf("[INFO] Dust converter params proposal ID: %d\n", proposalID)
	return proposalID
}

func vote(proposalID int64, yea bool) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	prevYeaNum, _ := governance.GetYeaByProposalId(proposalID)
	prevNayNum, _ := governance.GetNayByProposalId(proposalID)

	governance.Vote(cross, proposalID, yea)

	afterYeaNum, _ := governance.GetYeaByProposalId(proposalID)
	afterNayNum, _ := governance.GetNayByProposalId(proposalID)
	ufmt.Printf("[INFO] before proposal %d voting - yea: %d, nay: %d\n", proposalID, prevYeaNum, prevNayNum)
	ufmt.Printf("[INFO] after proposal %d voting - yea: %d, nay: %d\n", proposalID, afterYeaNum, afterNayNum)
}

func executeDustConverterParams(proposalID int64) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	governance.Execute(cross, proposalID)

	ufmt.Printf("[INFO] Proposal %d executed successfully\n", proposalID)
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 (amount: 1000000000)
//
// [SCENARIO] 2. Skip voting smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Check dust converter params before proposal
// [INFO] DustMinAmount: 10, DustMaxAmount: 10, CooldownSeconds: 0
//
// [SCENARIO] 4. Check dust converter target assets before proposal
// [INFO] Target assets - gns: true, demo: false
//
// [SCENARIO] 5. Propose dust converter parameter changes
// [INFO] Dust converter params proposal ID: 1
//
// [SCENARIO] 6. Skip voting start delay for ready to vote
// [INFO] current height: 86523
//
// [SCENARIO] 7. Vote for the proposal
// [INFO] before proposal 1 voting - yea: 0, nay: 0
// [INFO] after proposal 1 voting - yea: 1000000000, nay: 0
//
// [SCENARIO] 8. Skip voting period for ready to execute
// [INFO] current height: 388923
//
// [SCENARIO] 9. Execute the dust converter parameter changes
// [INFO] Proposal 1 executed successfully
//
// [SCENARIO] 10. Check dust converter params after execution
// [INFO] DustMinAmount: 20, DustMaxAmount: 100, CooldownSeconds: 3600
//
// [SCENARIO] 11. Check dust converter target assets after execution
// [INFO] Target assets - gns: false, demo: true
