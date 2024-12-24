package governance

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestUpdateProposalsState(t *testing.T) {
	baseTime := uint64(1000)
	configVersions = map[uint64]Config{
		1: {
			VotingStartDelay: 50,
			VotingPeriod:     100,
			ExecutionDelay:   50,
			ExecutionWindow:  100,
		},
	}

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
			proposals = make(map[uint64]ProposalInfo)

			proposal := tc.setupProposal(tc.currentTime)
			proposals[1] = proposal

			updateProposalsState()

			updatedProposal := proposals[1]
			tc.validate(t, updatedProposal)
		})
	}
}
