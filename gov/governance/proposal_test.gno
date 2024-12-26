package governance

import (
	"errors"
	"std"
	"strconv"
	"strings"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

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

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var pid uint64
			var err error
			func() {
				defer func() {
					if r := recover(); r != nil {
						err = r.(error)
					}
				}()
				pid = ProposeText(tt.title, tt.description)
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

			uassert.Equal(t, proposal.Title, tt.title)
			uassert.Equal(t, proposal.Description, tt.description)
			uassert.Equal(t, proposal.ProposalType.String(), Text.String())
			uassert.True(t, proposal.ExecutionState.Created)
			uassert.True(t, proposal.ExecutionState.Upcoming)
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

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var pid uint64
			var err error
			func() {
				defer func() {
					if r := recover(); r != nil {
						err = r.(error)
					}
				}()
				pid = ProposeCommunityPoolSpend(
					tt.title, tt.description, tt.to, tt.tokenPath, tt.amount)
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

			uassert.Equal(t, proposal.ProposalType.String(), CommunityPoolSpend.String())
			uassert.Equal(t, proposal.CommunityPoolSpend.To, tt.to)
			uassert.Equal(t, proposal.CommunityPoolSpend.Amount, tt.amount)
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

	for _, tt := range testCases {
		t.Run(tt.name, func(t *testing.T) {
			proposals = avl.NewTree()

			proposal := tt.setupProposal(tt.currentTime)
			proposals.Set(strconv.Itoa(int(1)), proposal)

			updateProposalsState()

			updatedProposal, exists := proposals.Get(strconv.Itoa(int(1)))
			if !exists {
				t.Error("Proposal was not stored")
				return
			}
			tt.validate(t, updatedProposal.(ProposalInfo))
		})
	}
}

func TestProposeParameterChange(t *testing.T) {
	resetGlobalStateProposal(t)

	tests := []struct {
		name          string
		proposer      std.Address
		title         string
		description   string
		numToExecute  uint64
		executions    string
		expectError   bool
		errorContains string
	}{
		{
			name:         "Valid parameter change proposal",
			proposer:     proposalAddr,
			title:        "Change Voting Period",
			description:  "Update voting period to 14 days",
			numToExecute: 2,
			executions:   "gno.land/r/gnoswap/v1/gns*EXE*SetAvgBlockTimeInMs*EXE*123*GOV*gno.land/r/gnoswap/v1/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/v1/gns,g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d,905",
			expectError:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetGlobalStateProposal(t)

			var pid uint64
			var err error
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("Unexpected error: %v", r)
				}
			}()
			pid = ProposeParameterChange(
				tt.title,
				tt.description,
				tt.numToExecute,
				tt.executions,
			)

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

			uassert.Equal(t, proposal.Title, tt.title)
			uassert.Equal(t, proposal.Description, tt.description)
			uassert.Equal(t, proposal.ProposalType.String(), ParameterChange.String())

			uassert.Equal(t, proposal.Execution.Num, tt.numToExecute)
			uassert.Equal(t, len(proposal.Execution.Msgs), int(tt.numToExecute))

			uassert.True(t, proposal.ExecutionState.Created)
			uassert.True(t, proposal.ExecutionState.Upcoming)
			uassert.False(t, proposal.ExecutionState.Active)
			uassert.True(t, proposal.Yea.IsZero())
			uassert.True(t, proposal.Nay.IsZero())
		})
	}
}
