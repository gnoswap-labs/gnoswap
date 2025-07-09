package governance

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/staker"
)

var (
	govStaker = consts.GOV_STAKER_ADDR
	emission  = consts.EMISSION_ADDR
)

// Helper function to create test governance state
func createTestGovernanceState() *GovernanceState {
	config := Config{
		VotingStartDelay:              3600,   // 1 hour
		VotingPeriod:                  604800, // 7 days
		VotingWeightSmoothingDuration: 259200, // 3 days
		Quorum:                        40,     // 40%
		ProposalCreationThreshold:     100,    // 100 xGNS
		ExecutionDelay:                86400,  // 1 day
		ExecutionWindow:               259200, // 3 days
	}

	return &GovernanceState{
		proposalCounter:      0,
		proposals:            avl.NewTree(),
		archievedProposals:   avl.NewTree(),
		votes:                avl.NewTree(),
		userVotes:            avl.NewTree(),
		proposalIdByProposer: avl.NewTree(),
		currentConfig:        config,
		configVersions:       avl.NewTree(),
		configCounter:        1,
	}
}

// Helper function to set up staker with admin permissions
func setupStakerAdminPermission(t *testing.T) {
	t.Helper()

	adminAddr := testutils.TestAddress("admin")

	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(std.NewUserRealm(adminAddr))
}

// Helper function to mint GNS to a user
func mintGNSToUser(t *testing.T, user std.Address) {
	t.Helper()

	// Mint GNS from emission realm
	func() {
		testing.SetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
		testing.SkipHeights(100)
		gns.MintGns(cross, user) // Mints 2M GNS
	}()
}

// Helper function to delegate GNS and get xGNS
func delegateGNSForXGNS(t *testing.T, user std.Address, toValidator std.Address, amount uint64) {
	t.Helper()

	// User approves gov/staker to spend GNS
	testing.SetOriginCaller(user)
	testing.SetRealm(std.NewUserRealm(user))
	gns.Approve(cross, govStaker, int64(amount))

	// Call Delegate from user realm (it will handle the cross-realm call)
	staker.Delegate(cross, toValidator, amount, "")
}

// TestCreateProposalTransition_Success tests successful proposal creation
func TestCreateProposalTransition_Success(t *testing.T) {
	setupStakerAdminPermission(t)

	proposer := testutils.TestAddress("prop1")
	validator1 := testutils.TestAddress("val1")

	// Setup state
	state := createTestGovernanceState()

	// Mint GNS to proposer and delegate to get xGNS
	mintGNSToUser(t, proposer)                             // Mints 2M GNS
	delegateGNSForXGNS(t, proposer, validator1, 1_000_000) // Delegate 1M GNS

	// Set up additional voters for voting weight
	voter2 := testutils.TestAddress("vot2_1")
	voter3 := testutils.TestAddress("vot3_1")
	validator2 := testutils.TestAddress("val2_1")
	validator3 := testutils.TestAddress("val3_1")

	mintGNSToUser(t, voter2)
	delegateGNSForXGNS(t, voter2, validator2, 1_000_000)

	mintGNSToUser(t, voter3)
	delegateGNSForXGNS(t, voter3, validator3, 1_000_000)

	// Switch to governance realm to create proposal
	testing.SetRealm(std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH))

	// Create transition
	transition := CreateProposalTransition(
		proposer,
		Text,
		"Test Proposal",
		"This is a test proposal description",
	)

	// Execute transition
	newState, err := transition(state)
	// Assertions
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	if newState.proposalCounter != 1 {
		t.Errorf("Expected proposal counter to be 1, got %d", newState.proposalCounter)
	}

	// Check proposal was added
	proposalIdRaw, exists := newState.proposalIdByProposer.Get(proposer.String())
	if !exists {
		t.Fatal("Expected proposal ID to exist for proposer")
	}

	proposalId := proposalIdRaw.(uint64)
	proposalRaw, exists := newState.proposals.Get(ufmt.Sprintf("%d", proposalId))
	if !exists {
		t.Fatal("Expected proposal to exist")
	}

	proposal := proposalRaw.(ProposalInfo)

	// Verify proposal fields
	if proposal.Proposer != proposer {
		t.Errorf("Expected proposer %s, got %s", proposer, proposal.Proposer)
	}

	if proposal.ConfigVersion != state.configCounter {
		t.Errorf("Expected config version %d, got %d", state.configCounter, proposal.ConfigVersion)
	}

	if proposal.Metadata.Title != "Test Proposal" {
		t.Errorf("Expected title 'Test Proposal', got '%s'", proposal.Metadata.Title)
	}

	if proposal.Metadata.Description != "This is a test proposal description" {
		t.Errorf("Expected description 'This is a test proposal description', got '%s'", proposal.Metadata.Description)
	}

	if proposal.Data.ProposalType != Text {
		t.Errorf("Expected proposal type Text, got %v", proposal.Data.ProposalType)
	}

	// Check that quorum is correctly calculated
	maxWeight := proposal.Voting.MaxVotingWeight.Uint64()
	expectedQuorum := maxWeight * 40 / 100 // 40% quorum
	if proposal.Voting.QuorumAmount != expectedQuorum {
		t.Errorf("Expected quorum amount %d, got %d", expectedQuorum, proposal.Voting.QuorumAmount)
	}

	// Verify schedule
	now := uint64(time.Now().Unix())
	schedule := proposal.Status.Schedule

	if schedule.CreateTime < now-1 || schedule.CreateTime > now+1 {
		t.Errorf("Expected create time around %d, got %d", now, schedule.CreateTime)
	}

	if schedule.ActiveTime != schedule.CreateTime+state.currentConfig.VotingStartDelay {
		t.Errorf("Expected active time %d, got %d",
			schedule.CreateTime+state.currentConfig.VotingStartDelay,
			schedule.ActiveTime)
	}
}

func TestCreateProposalTransition_InsufficientBalance(t *testing.T) {
	// Setup admin permissions
	setupStakerAdminPermission(t)

	// Setup proposer with unique address
	proposer := testutils.TestAddress("prop2")
	state := createTestGovernanceState()

	// Don't mint or delegate any GNS, so proposer has 0 xGNS

	// Switch to governance realm
	testing.SetRealm(std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH))

	// Create transition
	transition := CreateProposalTransition(
		proposer,
		Text,
		"Test Proposal",
		"This is a test proposal description",
	)

	// Execute transition
	_, err := transition(state)

	// Assertions
	if err == nil {
		t.Fatal("Expected error for insufficient balance, got nil")
	}

	expectedErr := ufmt.Sprintf("insufficient xGNS balance: %d < %d", 0, 100)
	if err.Error() != expectedErr {
		t.Errorf("Expected error '%s', got '%s'", expectedErr, err.Error())
	}
}

func TestCreateProposalTransition_AlreadyActiveProposal(t *testing.T) {
	// Setup admin permissions
	setupStakerAdminPermission(t)

	// Setup proposer with unique addresses
	proposer := testutils.TestAddress("prop3")
	validator := testutils.TestAddress("val3")
	state := createTestGovernanceState()

	// Add existing proposal for proposer
	state.proposalIdByProposer.Set(proposer.String(), uint64(1))
	state.proposalCounter = 1

	// Mint GNS and delegate to get xGNS
	mintGNSToUser(t, proposer)
	delegateGNSForXGNS(t, proposer, validator, 1_000_000)

	// Switch to governance realm
	testing.SetRealm(std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH))

	// Create transition
	transition := CreateProposalTransition(
		proposer,
		Text,
		"Test Proposal",
		"This is a test proposal description",
	)

	// Execute transition
	_, err := transition(state)

	// Assertions
	if err != errAlreadyActiveProposal {
		t.Errorf("Expected errAlreadyActiveProposal, got %v", err)
	}
}

func TestCreateProposalTransition_DifferentProposalTypes(t *testing.T) {
	proposalTypes := []struct {
		name         string
		proposalType ProposalType
	}{
		{"Text", Text},
		{"CommunityPoolSpend", CommunityPoolSpend},
		{"ParameterChange", ParameterChange},
		{"RoleChange", RoleChange},
	}

	// Setup admin permissions once
	setupStakerAdminPermission(t)

	for i, tc := range proposalTypes {
		t.Run(tc.name, func(t *testing.T) {
			// Setup unique proposer for each test
			proposer := testutils.TestAddress(ufmt.Sprintf("p%d", i+4))
			validator := testutils.TestAddress(ufmt.Sprintf("v%d", i+4))
			state := createTestGovernanceState()

			// Mint GNS and delegate
			mintGNSToUser(t, proposer)
			delegateGNSForXGNS(t, proposer, validator, 1_000_000)

			// Set up one voter for voting weight
			voter := testutils.TestAddress(ufmt.Sprintf("vt%d", i+4))
			voterValidator := testutils.TestAddress(ufmt.Sprintf("vv%d", i+4))
			mintGNSToUser(t, voter)
			delegateGNSForXGNS(t, voter, voterValidator, 1_000_000)

			// Switch to governance realm
			testing.SetRealm(std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH))

			// Create transition
			transition := CreateProposalTransition(
				proposer,
				tc.proposalType,
				"Test "+tc.name+" Proposal",
				"Description for "+tc.name,
			)

			// Execute transition
			newState, err := transition(state)
			// Assertions
			if err != nil {
				t.Fatalf("Expected no error, got: %v", err)
			}

			// Get created proposal
			proposalIdRaw, _ := newState.proposalIdByProposer.Get(proposer.String())
			proposalId := proposalIdRaw.(uint64)
			proposalRaw, _ := newState.proposals.Get(ufmt.Sprintf("%d", proposalId))
			proposal := proposalRaw.(ProposalInfo)

			if proposal.Data.ProposalType != tc.proposalType {
				t.Errorf("Expected proposal type %v, got %v", tc.proposalType, proposal.Data.ProposalType)
			}
		})
	}
}
