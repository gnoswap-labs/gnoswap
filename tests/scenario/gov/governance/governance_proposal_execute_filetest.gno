//

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/governance"
	"gno.land/r/gnoswap/v1/pool"

	govStaker "gno.land/r/gnoswap/v1/gov/staker"
)

var (
	adminAddr, _     = access.GetAddress(access.ROLE_ADMIN)
	govStakerAddr, _ = access.GetAddress(access.ROLE_GOV_STAKER)
	currentBlockTime = int64(2)
)

func main() {
	config := governance.GetLatestConfig()

	println("[SCENARIO] 1. Delegate gns to admin")
	delegateGnsToAdmin()
	println()

	println("[SCENARIO] 2. Skip voting smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 3. Propose Change Emission Distribution Percentages")
	proposeChangeEmissionDistributionPct()
	println()

	println("[SCENARIO] 4. Propose Change Average Block Time")
	proposeChangeAvgBlockTime()
	println()

	println("[SCENARIO] 5. Propose Reconfigure Governance Parameters")
	proposeReconfigureGovernance()
	println()

	println("[SCENARIO] 6. Propose Set Pool Creation Fee")
	proposeChangePoolCreationFee()
	println()

	println("[SCENARIO] 7. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 8. Vote for the proposals")
	vote(1, true)
	vote(2, true)
	vote(3, true)
	vote(4, true)
	println()

	println("[SCENARIO] 9. Skip voting period for ready to execute")
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 10. Execute the change emission distribution pct proposal")
	executeChangeEmissionDistributionPct(1)
	println()

	println("[SCENARIO] 11. Execute the change average block time proposal")
	executeChangeAvgBlockTime(2)
	println()

	println("[SCENARIO] 12. Execute the reconfigure governance parameters proposal")
	executeReconfigureGovernance(3)
	println()

	println("[SCENARIO] 13. Execute the change pool creation fee proposal")
	executeChangePoolCreationFee(4)
	println()
}

func vote(proposalID uint64, yea bool) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	prevYeaNum := governance.GetYeaByProposalId(proposalID)
	prevNayNum := governance.GetNayByProposalId(proposalID)

	governance.Vote(cross, proposalID, yea)

	afterYeaNum := governance.GetYeaByProposalId(proposalID)
	afterNayNum := governance.GetNayByProposalId(proposalID)
	ufmt.Printf("[EXPECTED] before proposal %d voting - yea: %s, nay: %s\n", proposalID, prevYeaNum, prevNayNum)
	ufmt.Printf("[EXPECTED] after proposal %d voting - yea: %s, nay: %s\n", proposalID, afterYeaNum, afterNayNum)
}

func executeProposal(proposalID uint64) {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	governance.Execute(cross, proposalID)
}

func executeChangeEmissionDistributionPct(proposalID uint64) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	prevEmissionDistributionPct1 := emission.GetDistributionBpsPct(1)
	prevEmissionDistributionPct2 := emission.GetDistributionBpsPct(2)
	prevEmissionDistributionPct3 := emission.GetDistributionBpsPct(3)
	prevEmissionDistributionPct4 := emission.GetDistributionBpsPct(4)

	governance.Execute(cross, proposalID)

	afterEmissionDistributionPct1 := emission.GetDistributionBpsPct(1)
	afterEmissionDistributionPct2 := emission.GetDistributionBpsPct(2)
	afterEmissionDistributionPct3 := emission.GetDistributionBpsPct(3)
	afterEmissionDistributionPct4 := emission.GetDistributionBpsPct(4)

	ufmt.Printf("[INFO] Change Emission Distribution Percentages Proposal ID: %d\n", proposalID)
	ufmt.Printf("[EXPECTED] before proposal %d executing - pct 1: %d, pct 2: %d, pct 3: %d, pct 4: %d\n", proposalID, prevEmissionDistributionPct1, prevEmissionDistributionPct2, prevEmissionDistributionPct3, prevEmissionDistributionPct4)
	ufmt.Printf("[EXPECTED] after proposal %d executing - pct 1: %d, pct 2: %d, pct 3: %d, pct 4: %d\n", proposalID, afterEmissionDistributionPct1, afterEmissionDistributionPct2, afterEmissionDistributionPct3, afterEmissionDistributionPct4)
}

func executeChangeAvgBlockTime(proposalID uint64) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	prevAvgBlockTime := gns.GetAvgBlockTimeInMs()

	governance.Execute(cross, proposalID)

	afterAvgBlockTime := gns.GetAvgBlockTimeInMs()

	ufmt.Printf("[EXPECTED] before proposal %d executing - avg block time: %dms\n", proposalID, prevAvgBlockTime)
	ufmt.Printf("[EXPECTED] after proposal %d executing - avg block time: %dms\n", proposalID, afterAvgBlockTime)
}

func executeReconfigureGovernance(proposalID uint64) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	prevGovConfig := governance.GetConfigVersion(0)

	governance.Execute(cross, proposalID)

	afterGovConfig := governance.GetConfigVersion(0)

	ufmt.Printf("[EXPECTED] before proposal %d executing - voting start delay: %d, voting period: %d, quorum: %d\n", proposalID, prevGovConfig.VotingStartDelay, prevGovConfig.VotingPeriod, prevGovConfig.Quorum)
	ufmt.Printf("[EXPECTED] after proposal %d executing - voting start delay: %d, voting period: %d, quorum: %d\n", proposalID, afterGovConfig.VotingStartDelay, afterGovConfig.VotingPeriod, afterGovConfig.Quorum)
}

func executeChangePoolCreationFee(proposalID uint64) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	prevPoolCreationFee := pool.GetPoolCreationFee()

	governance.Execute(cross, proposalID)

	afterPoolCreationFee := pool.GetPoolCreationFee()

	ufmt.Printf("[EXPECTED] before proposal %d executing - pool creation fee: %d\n", proposalID, prevPoolCreationFee)
	ufmt.Printf("[EXPECTED] after proposal %d executing - pool creation fee: %d\n", proposalID, afterPoolCreationFee)
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(std.NewUserRealm(adminAddr))

	gns.Approve(cross, consts.GOV_STAKER_ADDR, delegatedAmount)
	govStaker.Delegate(cross, adminAddr, uint64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func proposeChangeEmissionDistributionPct() {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(cross, "emission", "change", 1, "gno.land/r/gnoswap/v1/emission*EXE*ChangeDistributionPct*EXE*1,7000,2,1500,3,1000,4,500")

	ufmt.Printf("[INFO] Change Emission Distribution Percentages Proposal ID: %d\n", proposalID)
}

func proposeChangeAvgBlockTime() {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(cross, "blocktime", "set", 1, "gno.land/r/gnoswap/v1/gns*EXE*SetAvgBlockTimeInMs*EXE*5000")

	ufmt.Printf("[INFO] Change Emission Distribution Percentages Proposal ID: %d\n", proposalID)
}

func proposeReconfigureGovernance() {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(cross, "gov", "reconfigure", 1, "gno.land/r/gnoswap/v1/gov/governance*EXE*Reconfigure*EXE*123,456,789,1234,5678,12345,67890")

	ufmt.Printf("[INFO] Reconfigure Governance Parameters Proposal ID: %d\n", proposalID)
}

func proposeChangePoolCreationFee() {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(cross, "createfee", "change", 1, "gno.land/r/gnoswap/v1/pool*EXE*SetPoolCreationFee*EXE*500")

	ufmt.Printf("[INFO] Change Pool Creation Fee Proposal ID: %d\n", proposalID)
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d (amount: 1000000000)
//
// [SCENARIO] 2. Skip voting smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Propose Change Emission Distribution Percentages
// [INFO] Change Emission Distribution Percentages Proposal ID: 1
//
// [SCENARIO] 4. Propose Change Average Block Time
// [INFO] Change Emission Distribution Percentages Proposal ID: 2
//
// [SCENARIO] 5. Propose Reconfigure Governance Parameters
// [INFO] Reconfigure Governance Parameters Proposal ID: 3
//
// [SCENARIO] 6. Propose Set Pool Creation Fee
// [INFO] Change Pool Creation Fee Proposal ID: 4
//
// [SCENARIO] 7. Skip voting start delay for ready to vote
// [INFO] current height: 86523
//
// [SCENARIO] 8. Vote for the proposals
// [EXPECTED] before proposal 1 voting - yea: 0, nay: 0
// [EXPECTED] after proposal 1 voting - yea: 1000000000, nay: 0
// [EXPECTED] before proposal 2 voting - yea: 0, nay: 0
// [EXPECTED] after proposal 2 voting - yea: 1000000000, nay: 0
// [EXPECTED] before proposal 3 voting - yea: 0, nay: 0
// [EXPECTED] after proposal 3 voting - yea: 1000000000, nay: 0
// [EXPECTED] before proposal 4 voting - yea: 0, nay: 0
// [EXPECTED] after proposal 4 voting - yea: 1000000000, nay: 0
//
// [SCENARIO] 9. Skip voting period for ready to execute
// [INFO] current height: 388923
//
// [SCENARIO] 10. Execute the change emission distribution pct proposal
// [INFO] Change Emission Distribution Percentages Proposal ID: 1
// [EXPECTED] before proposal 1 executing - pct 1: 7500, pct 2: 2000, pct 3: 500, pct 4: 0
// [EXPECTED] after proposal 1 executing - pct 1: 7000, pct 2: 1500, pct 3: 1000, pct 4: 500
//
// [SCENARIO] 11. Execute the change average block time proposal
// [EXPECTED] before proposal 2 executing - avg block time: 2000ms
// [EXPECTED] after proposal 2 executing - avg block time: 5000ms
//
// [SCENARIO] 12. Execute the reconfigure governance parameters proposal
// [EXPECTED] before proposal 3 executing - voting start delay: 86400, voting period: 604800, quorum: 50
// [EXPECTED] after proposal 3 executing - voting start delay: 123, voting period: 456, quorum: 1234
//
// [SCENARIO] 13. Execute the change pool creation fee proposal
// [EXPECTED] before proposal 4 executing - pool creation fee: 100000000
// [EXPECTED] after proposal 4 executing - pool creation fee: 500
