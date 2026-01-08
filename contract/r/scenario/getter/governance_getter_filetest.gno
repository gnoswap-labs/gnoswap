// governance getter test

package main

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"

	gs "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	gns "gno.land/r/gnoswap/gns"
)

var (
	adminAddr        = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr    = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	governanceAddr   = access.MustGetAddress(prbac.ROLE_GOVERNANCE.String())
	currentBlockTime = int64(2)

	user1Addr = "g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c"
	user2Addr = "g17rgsdnfxzza0sdfsdma37sdwxagsz378833ca4"

	governanceRealm = testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance")
)

var t *testing.T

func main() {
	println("[SCENARIO] 1. Setup test data")
	proposalId := setupTestData()
	println()

	println("[SCENARIO] 2. Test Store Data Getters")
	testStoreDataGetters()
	println()

	println("[SCENARIO] 3. Test Config Getters")
	testConfigGetters()
	println()

	println("[SCENARIO] 4. Test Proposal Getters")
	testProposalGetters(proposalId)
	println()

	println("[SCENARIO] 5. Test Vote Getters")
	testVoteGetters(proposalId)
	println()

	println("[SCENARIO] 6. Test Proposal Data Getters")
	testProposalDataGetters(proposalId)
	println()

	println("[SCENARIO] 7. Test User Proposal Getters")
	testUserProposalGetters()
	println()

	println("[SCENARIO] 8. Test Active Proposal and Voting Weight Getters")
	testActiveProposalAndVotingWeight()
	println()
}

func setupTestData() int64 {
	println("[INFO] Setting up test data")

	// Delegate GNS to admin
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Approve(cross, govStakerAddr, delegatedAmount)
	gs.Delegate(cross, adminAddr, delegatedAmount, "")
	println("[INFO] GNS delegated to admin:", delegatedAmount)

	// Skip smoothing period
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] Skipped smoothing period, current height:", runtime.ChainHeight())

	// Create proposal: Community Pool Spend
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalId := governance.ProposeCommunityPoolSpend(cross, "Community Pool Spend Proposal", "Spend 1000 GNS from community pool", adminAddr, "gno.land/r/gnoswap/gns", 1000)
	println("[EXPECTED] Created proposal (Community Pool Spend) ID:", proposalId)

	// Vote on proposal
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	// Skip voting start delay
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	governance.Vote(cross, proposalId, true)
	println("[EXPECTED] Admin voted YES on proposal")

	return proposalId
}

func testStoreDataGetters() {
	println("[INFO] Testing store data getters")

	// Set realm to governance for getter calls
	testing.SetRealm(governanceRealm)

	// GetLatestConfigVersion
	configVersion := governance.GetLatestConfigVersion()
	println("[EXPECTED] Latest config version:", configVersion)

	// GetCurrentProposalID
	currentProposalId := governance.GetCurrentProposalID()
	println("[EXPECTED] Current proposal ID:", currentProposalId)

	// GetMaxSmoothingPeriod
	maxSmoothingPeriod := governance.GetMaxSmoothingPeriod()
	println("[EXPECTED] Max smoothing period:", maxSmoothingPeriod)
}

func testConfigGetters() {
	println("[INFO] Testing config getters")

	// Set realm to governance for getter calls
	testing.SetRealm(governanceRealm)

	// GetLatestConfig
	latestConfig := governance.GetLatestConfig()
	println("[EXPECTED] Latest config:")
	println("[EXPECTED] - Proposal creation threshold:", latestConfig.ProposalCreationThreshold)
	println("[EXPECTED] - Voting period:", latestConfig.VotingPeriod)
	println("[EXPECTED] - Voting weight smoothing duration:", latestConfig.VotingWeightSmoothingDuration)
	println("[EXPECTED] - Quorum:", latestConfig.Quorum)
	println("[EXPECTED] - Execution delay:", latestConfig.ExecutionDelay)
	println("[EXPECTED] - Execution window:", latestConfig.ExecutionWindow)

	// GetConfig
	config, err := governance.GetConfig(1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Config version 1:")
	println("[EXPECTED] - Proposal creation threshold:", config.ProposalCreationThreshold)
	println("[EXPECTED] - Voting period:", config.VotingPeriod)
}

func testProposalGetters(proposalId int64) {
	println("[INFO] Testing proposal getters")

	// Set realm to governance for getter calls
	testing.SetRealm(governanceRealm)

	// GetProposalCount
	proposalCount := governance.GetProposalCount()
	println("[EXPECTED] Proposal count:", proposalCount)

	// GetProposalIDs
	proposalIDs := governance.GetProposalIDs(0, 10)
	println("[EXPECTED] Proposal IDs (offset=0, limit=10):", len(proposalIDs), "proposals")
	for i, id := range proposalIDs {
		ufmt.Printf("[EXPECTED] - Proposal %d: %d\n", i+1, id)
	}

	// ExistsProposal
	exists1 := governance.ExistsProposal(proposalId)
	println("[EXPECTED] Proposal exists:", exists1)

	exists999 := governance.ExistsProposal(999)
	println("[EXPECTED] Proposal 999 exists:", exists999)

	// GetProposal
	proposal, err := governance.GetProposal(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal details:")
	println("[EXPECTED] - ID:", proposal.ID())
	println("[EXPECTED] - Proposer:", proposal.Proposer())
	println("[EXPECTED] - Type:", proposal.Type())
	println("[EXPECTED] - Yes weight:", proposal.VotingYesWeight())
	println("[EXPECTED] - No weight:", proposal.VotingNoWeight())

	// GetProposerByProposalId
	proposer, err := governance.GetProposerByProposalId(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 proposer:", proposer)

	// GetProposalTypeByProposalId
	proposalType, err := governance.GetProposalTypeByProposalId(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 type:", proposalType)

	// GetYeaByProposalId
	yea, err := governance.GetYeaByProposalId(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 yea:", yea)

	// GetNayByProposalId
	nay, err := governance.GetNayByProposalId(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 nay:", nay)

	// GetConfigVersionByProposalId
	configVersion, err := governance.GetConfigVersionByProposalId(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 config version:", configVersion)

	// GetQuorumAmountByProposalId
	quorum, err := governance.GetQuorumAmountByProposalId(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 quorum:", quorum)

	// GetTitleByProposalId
	title, err := governance.GetTitleByProposalId(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 title:", title)

	// GetDescriptionByProposalId
	description, err := governance.GetDescriptionByProposalId(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 description:", description)

	// GetProposalStatusByProposalId
	status, err := governance.GetProposalStatusByProposalId(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 status:", status)

	// GetProposalCreatedAt
	createdAt, err := governance.GetProposalCreatedAt(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 created at:", createdAt)

	// GetProposalCreatedHeight
	createdHeight, err := governance.GetProposalCreatedHeight(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Proposal 1 created height:", createdHeight)
}

func testVoteGetters(proposalId int64) {
	println("[INFO] Testing vote getters")

	// Set realm to governance for getter calls
	testing.SetRealm(governanceRealm)

	// GetVoteStatus
	quorum, maxVotingWeight, yesWeight, noWeight, err := governance.GetVoteStatus(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Vote status for proposal 1:")
	println("[EXPECTED] - Quorum:", quorum)
	println("[EXPECTED] - Max voting weight:", maxVotingWeight)
	println("[EXPECTED] - Yes weight:", yesWeight)
	println("[EXPECTED] - No weight:", noWeight)

	// GetVotingInfoCount
	votingInfoCount := governance.GetVotingInfoCount(proposalId)
	println("[EXPECTED] Voting info count:", votingInfoCount)

	// GetVotingInfoAddresses
	votingInfoAddresses := governance.GetVotingInfoAddresses(proposalId, 0, 10)
	println("[EXPECTED] Voting info addresses (offset=0, limit=10):", len(votingInfoAddresses), "voters")
	for i, addr := range votingInfoAddresses {
		ufmt.Printf("[EXPECTED] - Voter %d: %s\n", i+1, addr)
	}

	// ExistsVotingInfo
	existsVoting := governance.ExistsVotingInfo(proposalId, adminAddr)
	println("[EXPECTED] Admin voting info exists:", existsVoting)

	// GetVotingInfo
	votingInfo, err := governance.GetVotingInfo(proposalId, adminAddr)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Admin voting info:")
	println("[EXPECTED] - Vote type:", votingInfo.VotingType())
	println("[EXPECTED] - Voted weight:", votingInfo.VotedWeight())
	println("[EXPECTED] - Available vote weight:", votingInfo.AvailableVoteWeight())

	// GetVoteWeight
	voteWeight, err := governance.GetVoteWeight(proposalId, adminAddr)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Admin vote weight:", voteWeight)

	// GetVotedHeight
	votedHeight, err := governance.GetVotedHeight(proposalId, adminAddr)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Admin voted height:", votedHeight)

	// GetVotedAt
	votedAt, err := governance.GetVotedAt(proposalId, adminAddr)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Admin voted at:", votedAt)
}

func testProposalDataGetters(proposalId int64) {
	println("[INFO] Testing proposal data getters")

	// Set realm to governance for getter calls
	testing.SetRealm(governanceRealm)

	// GetProposalCommunityPoolSpendInfo
	println("[INFO] Testing community pool spend info")
	communityPoolSpendInfo, err := governance.GetProposalCommunityPoolSpendInfo(proposalId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Community pool spend info:")
	println("[EXPECTED] - To:", communityPoolSpendInfo.To())
	println("[EXPECTED] - Token path:", communityPoolSpendInfo.TokenPath())
	println("[EXPECTED] - Amount:", communityPoolSpendInfo.Amount())

	// GetProposalExecutionInfo (should fail for community pool spend proposal)
	println("[INFO] Testing execution info (should fail for community pool spend)")
	_, err = governance.GetProposalExecutionInfo(proposalId)
	if err != nil {
		println("[EXPECTED] Error getting execution info for community pool spend proposal:", err.Error())
	}
}

func testUserProposalGetters() {
	println("[INFO] Testing user proposal getters")

	// Set realm to governance for getter calls
	testing.SetRealm(governanceRealm)

	// GetUserProposalCount
	userProposalCount := governance.GetUserProposalCount(adminAddr)
	println("[EXPECTED] Admin proposal count:", userProposalCount)

	// GetUserProposalIDs
	userProposalIDs := governance.GetUserProposalIDs(adminAddr, 0, 10)
	println("[EXPECTED] Admin proposal IDs (offset=0, limit=10):", len(userProposalIDs), "proposals")
	for i, id := range userProposalIDs {
		ufmt.Printf("[EXPECTED] - Proposal %d: %d\n", i+1, id)
	}
}

func testActiveProposalAndVotingWeight() {
	println("[INFO] Testing active proposal and voting weight getters")

	// Set realm to governance for getter calls
	testing.SetRealm(governanceRealm)

	// GetOldestActiveProposalSnapshotTime
	snapshotTime, exists := governance.GetOldestActiveProposalSnapshotTime()
	println("[EXPECTED] Oldest active proposal snapshot time exists:", exists)
	if exists {
		println("[EXPECTED] Oldest active proposal snapshot time:", snapshotTime)
	}

	// GetCurrentVotingWeightSnapshot
	height, timestamp, err := governance.GetCurrentVotingWeightSnapshot()
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Current voting weight snapshot:")
	println("[EXPECTED] - Height:", height)
	println("[EXPECTED] - Timestamp:", timestamp)
}

// Output:
// [SCENARIO] 1. Setup test data
// [INFO] Setting up test data
// [INFO] GNS delegated to admin: 1000000000
// [INFO] Skipped smoothing period, current height: 43323
// [EXPECTED] Created proposal (Community Pool Spend) ID: 1
// [EXPECTED] Admin voted YES on proposal
//
// [SCENARIO] 2. Test Store Data Getters
// [INFO] Testing store data getters
// [EXPECTED] Latest config version: 1
// [EXPECTED] Current proposal ID: 1
// [EXPECTED] Max smoothing period: 2592000
//
// [SCENARIO] 3. Test Config Getters
// [INFO] Testing config getters
// [EXPECTED] Latest config:
// [EXPECTED] - Proposal creation threshold: 1000000000
// [EXPECTED] - Voting period: 604800
// [EXPECTED] - Voting weight smoothing duration: 86400
// [EXPECTED] - Quorum: 50
// [EXPECTED] - Execution delay: 86400
// [EXPECTED] - Execution window: 2592000
// [EXPECTED] Config version 1:
// [EXPECTED] - Proposal creation threshold: 1000000000
// [EXPECTED] - Voting period: 604800
//
// [SCENARIO] 4. Test Proposal Getters
// [INFO] Testing proposal getters
// [EXPECTED] Proposal count: 1
// [EXPECTED] Proposal IDs (offset=0, limit=10): 1 proposals
// [EXPECTED] - Proposal 1: 1
// [EXPECTED] Proposal exists: true
// [EXPECTED] Proposal 999 exists: false
// [EXPECTED] Proposal details:
// [EXPECTED] - ID: 1
// [EXPECTED] - Proposer: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [EXPECTED] - Type: CommunityPoolSpend
// [EXPECTED] - Yes weight: 1000000000
// [EXPECTED] - No weight: 0
// [EXPECTED] Proposal 1 proposer: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [EXPECTED] Proposal 1 type: CommunityPoolSpend
// [EXPECTED] Proposal 1 yea: 1000000000
// [EXPECTED] Proposal 1 nay: 0
// [EXPECTED] Proposal 1 config version: 1
// [EXPECTED] Proposal 1 quorum: 500000000
// [EXPECTED] Proposal 1 title: Community Pool Spend Proposal
// [EXPECTED] Proposal 1 description: Spend 1000 GNS from community pool
// [EXPECTED] Proposal 1 status: active
// [EXPECTED] Proposal 1 created at: 1234783890
// [EXPECTED] Proposal 1 created height: 43323
//
// [SCENARIO] 5. Test Vote Getters
// [INFO] Testing vote getters
// [EXPECTED] Vote status for proposal 1:
// [EXPECTED] - Quorum: 500000000
// [EXPECTED] - Max voting weight: 1000000000
// [EXPECTED] - Yes weight: 1000000000
// [EXPECTED] - No weight: 0
// [EXPECTED] Voting info count: 1
// [EXPECTED] Voting info addresses (offset=0, limit=10): 1 voters
// [EXPECTED] - Voter 1: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [EXPECTED] Admin voting info exists: true
// [EXPECTED] Admin voting info:
// [EXPECTED] - Vote type: yes
// [EXPECTED] - Voted weight: 1000000000
// [EXPECTED] - Available vote weight: 1000000000
// [EXPECTED] Admin vote weight: 1000000000
// [EXPECTED] Admin voted height: 86523
// [EXPECTED] Admin voted at: 1234999890
//
// [SCENARIO] 6. Test Proposal Data Getters
// [INFO] Testing proposal data getters
// [INFO] Testing community pool spend info
// [EXPECTED] Community pool spend info:
// [EXPECTED] - To: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [EXPECTED] - Token path: gno.land/r/gnoswap/gns
// [EXPECTED] - Amount: 1000
// [INFO] Testing execution info (should fail for community pool spend)
//
// [SCENARIO] 7. Test User Proposal Getters
// [INFO] Testing user proposal getters
// [EXPECTED] Admin proposal count: 1
// [EXPECTED] Admin proposal IDs (offset=0, limit=10): 1 proposals
// [EXPECTED] - Proposal 1: 1
//
// [SCENARIO] 8. Test Active Proposal and Voting Weight Getters
// [INFO] Testing active proposal and voting weight getters
// [EXPECTED] Oldest active proposal snapshot time exists: true
// [EXPECTED] Oldest active proposal snapshot time: 1234697490
// [EXPECTED] Current voting weight snapshot:
// [EXPECTED] - Height: 1000000000
// [EXPECTED] - Timestamp: 1234913490
