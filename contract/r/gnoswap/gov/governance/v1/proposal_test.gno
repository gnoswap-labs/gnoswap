package v1

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/governance"
)

// TestProposal_TypeOperations tests proposal type operations
func TestProposal_TypeOperations(t *testing.T) {
	tests := []struct {
		name           string
		proposalType   governance.ProposalType
		expectedString string
		isExecutable   bool
	}{
		{
			name:           "Text proposal",
			proposalType:   governance.Text,
			expectedString: "Text",
			isExecutable:   false,
		},
		{
			name:           "CommunityPoolSpend proposal",
			proposalType:   governance.CommunityPoolSpend,
			expectedString: "CommunityPoolSpend",
			isExecutable:   true,
		},
		{
			name:           "ParameterChange proposal",
			proposalType:   governance.ParameterChange,
			expectedString: "ParameterChange",
			isExecutable:   true,
		},
		{
			name:           "Unknown proposal type",
			proposalType:   governance.ProposalType("UNKNOWN"),
			expectedString: "Unknown",
			isExecutable:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when & then
			uassert.Equal(t, tc.proposalType.String(), tc.expectedString)
			uassert.Equal(t, tc.proposalType.IsExecutable(), tc.isExecutable)
		})
	}
}

// TestProposal_Validation tests proposal validation
func TestProposal_Validation(t *testing.T) {
	tests := []struct {
		name          string
		metadata      *governance.ProposalMetadata
		data          *governance.ProposalData
		expectedError bool
	}{
		{
			name: "Valid Text proposal",
			metadata: governance.NewProposalMetadata("Valid Title", "Valid Description"),
			data: governance.NewProposalData(governance.Text, nil, nil),
			expectedError: false,
		},
		{
			name: "Invalid metadata",
			metadata: governance.NewProposalMetadata("", "Valid Description"),
			data: governance.NewProposalData(governance.Text, nil, nil),
			expectedError: true,
		},
		{
			name: "Invalid CommunityPoolSpend proposal",
			metadata: governance.NewProposalMetadata("Valid Title", "Valid Description"),
			data: governance.NewProposalData(governance.CommunityPoolSpend, governance.NewCommunityPoolSpendInfo(address(""), "", 0), nil),
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			baseTime := time.Now().Unix()
			config := governance.Config{
				VotingStartDelay: 100,
				VotingPeriod:     200,
				ExecutionDelay:   100,
				ExecutionWindow:  200,
				Quorum:           50,
			}
			proposal := governance.NewProposal(
				1,
				governance.NewProposalStatus(config, 1000, governance.Text.IsExecutable(), baseTime),
				tc.metadata,
				tc.data,
				address("g1proposer"),
				1,
				baseTime,
				runtime.ChainHeight(),
			)

			// when
			err := NewProposalResolver(proposal).Validate()

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}

// TestProposal_StatusOperations tests proposal status operations
func TestProposal_StatusOperations(t *testing.T) {
	baseTime := time.Unix(1000, 0)
	config := governance.Config{
		VotingStartDelay: 100,
		VotingPeriod:     200,
		ExecutionDelay:   100,
		ExecutionWindow:  200,
		Quorum:           50,
	}

	tests := []struct {
		name           string
		proposalType   governance.ProposalType
		currentTime    time.Time
		isExecuted     bool
		isCanceled     bool
		expectedActive bool
	}{
		{
			name:           "Active Text proposal",
			proposalType:   governance.Text,
			currentTime:    baseTime.Add(time.Duration(150) * time.Second),
			expectedActive: true,
		},
		{
			name:           "Executed proposal",
			proposalType:   governance.CommunityPoolSpend,
			currentTime:    baseTime.Add(time.Duration(100+200+100) * time.Second), // voting start + voting period + execution delay
			isExecuted:     true,
			expectedActive: false,
		},
		{
			name:           "Canceled proposal",
			proposalType:   governance.ParameterChange,
			currentTime:    baseTime,
			isCanceled:     true,
			expectedActive: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			proposal := governance.NewProposal(
				1,
				governance.NewProposalStatus(config, 1000, tc.proposalType.IsExecutable(), baseTime.Unix()),
				governance.NewProposalMetadata("Test", "Test"),
				governance.NewProposalData(tc.proposalType, nil, nil),
				address("g1proposer"),
				1,
				baseTime.Unix(),
				runtime.ChainHeight(),
			)

			if tc.isExecuted {
				err := NewProposalResolver(proposal).execute(tc.currentTime.Unix(), 100, address("g1executor"))
				uassert.NoError(t, err)
			}
			if tc.isCanceled {
				err := NewProposalResolver(proposal).cancel(tc.currentTime.Unix(), 100, address("g1canceler"))
				uassert.NoError(t, err)
			}

			// when & then
			uassert.Equal(t, NewProposalResolver(proposal).IsActive(tc.currentTime.Unix()), tc.expectedActive)
		})
	}
}

// // TestNewProposal tests creation of new proposal
func TestNewProposal(t *testing.T) {
	tests := []struct {
		name         string
		proposalType governance.ProposalType
		title        string
		description  string
		proposer     address
	}{
		{
			name:         "Create Text proposal",
			proposalType: governance.Text,
			title:        "Test Title",
			description:  "Test Description",
			proposer:     address("g1proposer"),
		},
		{
			name:         "Create CommunityPoolSpend proposal",
			proposalType: governance.CommunityPoolSpend,
			title:        "Spend Proposal",
			description:  "Community Pool Spend",
			proposer:     address("g1proposer"),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			baseTime := time.Now().Unix()
			config := governance.Config{
				VotingStartDelay: 100,
				VotingPeriod:     200,
				ExecutionDelay:   100,
				ExecutionWindow:  200,
				Quorum:           50,
			}

			// when
			proposal := governance.NewProposal(
				1,
				governance.NewProposalStatus(config, 1000, tc.proposalType.IsExecutable(), baseTime),
				governance.NewProposalMetadata(tc.title, tc.description),
				governance.NewProposalData(tc.proposalType, nil, nil),
				tc.proposer,
				1,
				baseTime,
				runtime.ChainHeight(),
			)

			// then
			resolver := NewProposalResolver(proposal)
			uassert.NotNil(t, proposal)
			uassert.Equal(t, resolver.Type().String(), tc.proposalType.String())
			uassert.Equal(t, resolver.Title(), tc.title)
			uassert.Equal(t, resolver.Description(), tc.description)
			uassert.Equal(t, resolver.Proposer().String(), tc.proposer.String())
			uassert.Equal(t, resolver.CreatedAt(), baseTime)
		})
	}
}
