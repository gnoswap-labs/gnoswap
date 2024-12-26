package governance

import (
	"std"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"

	u256 "gno.land/p/gnoswap/uint256"
	gs "gno.land/r/gnoswap/v1/gov/staker"
)

var (
	proposalAddr = testutils.TestAddress("proposal")
	toAddr       = testutils.TestAddress("to")

	voter1 = testutils.TestAddress("voter1")
	voter2 = testutils.TestAddress("voter2")

	insufficientProposer = testutils.TestAddress("insufficient")
)

func resetGlobalStateProposal(t *testing.T) {
	t.Helper()
	proposalId = 0
	proposals = avl.NewTree()
	latestProposalByProposer = avl.NewTree()
}

func mockCheckEnoughXGnsToPropose(proposer std.Address) (bool, uint64, uint64) {
	if proposer == insufficientProposer {
		return false, 500, 1000
	}
	return true, 1000, 1000
}

func mockGetPossibleVotingAddressWithWeight(t *testing.T, timestamp uint64) (uint64, map[std.Address]uint64) {
	t.Helper()
	weights := make(map[std.Address]uint64)
	weights[voter1] = 100
	weights[voter2] = 200
	return 300, weights
}

func TestProposeText(t *testing.T) {
	checkEnoughXGnsToPropose = mockCheckEnoughXGnsToPropose

	resetGlobalStateProposal(t)

	tests := []struct {
		name        string
		proposer    std.Address
		title       string
		description string
		expectError bool
	}{
		{
			name:        "Valid text proposal",
			proposer:    proposalAddr,
			title:       "Test Proposal",
			description: "This is a test proposal",
			expectError: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var pid uint64
			var err error
			func() {
				defer func() {
					if r := recover(); r != nil {
						err = r.(error)
					}
				}()
				pid = ProposeText(tc.title, tc.description)
			}()

			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}

			prop, exists := proposals.Get(strconv.Itoa(int(pid)))
			if !exists {
				t.Error("Proposal was not stored")
				return
			}

			proposal := prop.(ProposalInfo)

			if proposal.Title != tc.title {
				t.Errorf("Title mismatch: got %s, want %s", proposal.Title, tc.title)
			}

			if proposal.Description != tc.description {
				t.Errorf("Description mismatch: got %s, want %s",
					proposal.Description, tc.description)
			}

			if proposal.ProposalType != Text {
				t.Errorf("Incorrect proposal type: got %s, want Text",
					proposal.ProposalType)
			}

			if !proposal.ExecutionState.Created {
				t.Error("Proposal should be marked as created")
			}

			if !proposal.ExecutionState.Upcoming {
				t.Error("Proposal should be marked as upcoming")
			}
		})
	}
}

func TestProposeCommunityPoolSpend(t *testing.T) {
	checkEnoughXGnsToPropose = mockCheckEnoughXGnsToPropose

	resetGlobalStateProposal(t)

	tests := []struct {
		name        string
		proposer    std.Address
		title       string
		description string
		to          std.Address
		tokenPath   string
		amount      uint64
		expectError bool
	}{
		{
			name:        "Valid community pool spend proposal",
			proposer:    proposalAddr,
			title:       "Community Spend",
			description: "Fund community initiative",
			to:          toAddr,
			tokenPath:   "token/path",
			amount:      1000,
			expectError: false,
		},
		{
			name:        "Insufficient balance for proposal",
			proposer:    insufficientProposer,
			title:       "Invalid Spend",
			description: "Should fail",
			to:          toAddr,
			tokenPath:   "token/path",
			amount:      1000,
			expectError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var pid uint64
			var err error
			func() {
				defer func() {
					if r := recover(); r != nil {
						err = r.(error)
					}
				}()
				pid = ProposeCommunityPoolSpend(
					tc.title, tc.description, tc.to, tc.tokenPath, tc.amount)
			}()

			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}

			prop, exists := proposals.Get(strconv.Itoa(int(pid)))
			if !exists {
				t.Error("Proposal was not stored")
				return
			}

			proposal := prop.(ProposalInfo)

			if proposal.ProposalType != CommunityPoolSpend {
				t.Errorf("Incorrect proposal type: got %s, want CommunityPoolSpend",
					proposal.ProposalType)
			}

			if proposal.CommunityPoolSpend.To != tc.to {
				t.Errorf("Recipient mismatch: got %s, want %s",
					proposal.CommunityPoolSpend.To, tc.to)
			}

			if proposal.CommunityPoolSpend.Amount != tc.amount {
				t.Errorf("Amount mismatch: got %d, want %d",
					proposal.CommunityPoolSpend.Amount, tc.amount)
			}
		})
	}
}

func TestUpdateProposalsState(t *testing.T) {
	baseTime := uint64(1000)
	newConfig := Config{
		VotingStartDelay: 50,
		VotingPeriod:     100,
		ExecutionDelay:   50,
		ExecutionWindow:  100,
	}
	setConfigVersion(1, newConfig)

	testCases := []struct {
		name          string
		currentTime   uint64
		setupProposal func(uint64) ProposalInfo
		validate      func(*testing.T, ProposalInfo)
	}{
		{
			name:        "Should reject proposal when voting ends with insufficient votes",
			currentTime: baseTime + 200,
			setupProposal: func(now uint64) ProposalInfo {
				return ProposalInfo{
					ConfigVersion: 1,
					Yea:           u256.NewUint(100),
					Nay:           u256.NewUint(200),
					QuorumAmount:  300,
					ExecutionState: ExecutionState{
						Created:   true,
						CreatedAt: baseTime,
						Active:    true,
					},
				}
			},
			validate: func(t *testing.T, proposal ProposalInfo) {
				if !proposal.ExecutionState.Rejected {
					t.Error("Proposal should be rejected")
				}
				if proposal.ExecutionState.Active {
					t.Error("Proposal should not be active anymore")
				}
				if proposal.ExecutionState.Upcoming {
					t.Error("Proposal should not be upcoming")
				}
				if proposal.ExecutionState.RejectedAt == 0 {
					t.Error("RejectedAt timestamp should be set")
				}
			},
		},
		{
			name:        "Should pass proposal when voting ends with sufficient votes",
			currentTime: baseTime + 200,
			setupProposal: func(now uint64) ProposalInfo {
				return ProposalInfo{
					ConfigVersion: 1,
					Yea:           u256.NewUint(400),
					Nay:           u256.NewUint(200),
					QuorumAmount:  300,
					ExecutionState: ExecutionState{
						Created:   true,
						CreatedAt: baseTime,
						Active:    true,
					},
				}
			},
			validate: func(t *testing.T, proposal ProposalInfo) {
				if !proposal.ExecutionState.Passed {
					t.Error("Proposal should be passed")
				}
				if proposal.ExecutionState.Active {
					t.Error("Proposal should not be active anymore")
				}
				if proposal.ExecutionState.PassedAt == 0 {
					t.Error("PassedAt timestamp should be set")
				}
			},
		},
		{
			name:        "Should expire non-text proposal when execution window ends",
			currentTime: baseTime + 400,
			setupProposal: func(now uint64) ProposalInfo {
				return ProposalInfo{
					ConfigVersion: 1,
					ProposalType:  ParameterChange,
					ExecutionState: ExecutionState{
						Created:   true,
						CreatedAt: baseTime,
						Passed:    true,
						PassedAt:  baseTime + 200,
					},
				}
			},
			validate: func(t *testing.T, proposal ProposalInfo) {
				if !proposal.ExecutionState.Expired {
					t.Error("Proposal should be expired")
				}
				if proposal.ExecutionState.ExpiredAt == 0 {
					t.Error("ExpiredAt timestamp should be set")
				}
			},
		},
		{
			name:        "Should not update canceled proposal",
			currentTime: baseTime + 60,
			setupProposal: func(now uint64) ProposalInfo {
				return ProposalInfo{
					ConfigVersion: 1,
					ExecutionState: ExecutionState{
						Created:   true,
						CreatedAt: baseTime,
						Canceled:  true,
						Upcoming:  true,
					},
				}
			},
			validate: func(t *testing.T, proposal ProposalInfo) {
				if !proposal.ExecutionState.Canceled {
					t.Error("Proposal should remain canceled")
				}
				if !proposal.ExecutionState.Upcoming {
					t.Error("Proposal state should not change when canceled")
				}
			},
		},
		{
			name:        "Should not expire text proposal",
			currentTime: baseTime + 400,
			setupProposal: func(now uint64) ProposalInfo {
				return ProposalInfo{
					ConfigVersion: 1,
					ProposalType:  Text,
					ExecutionState: ExecutionState{
						Created:   true,
						CreatedAt: baseTime,
						Passed:    true,
						PassedAt:  baseTime + 200,
					},
				}
			},
			validate: func(t *testing.T, proposal ProposalInfo) {
				if proposal.ExecutionState.Expired {
					t.Error("Text proposal should not expire")
				}
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			proposals = avl.NewTree()

			proposal := tc.setupProposal(tc.currentTime)
			proposals.Set(strconv.Itoa(int(1)), proposal)

			updateProposalsState()

			updatedProposal, exists := proposals.Get(strconv.Itoa(int(1)))
			if !exists {
				t.Error("Proposal was not stored")
				return
			}
			tc.validate(t, updatedProposal.(ProposalInfo))
		})
	}
}
