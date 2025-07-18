package governance

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/uassert"
)

// TestProposal_TypeOperations tests proposal type operations
func TestProposal_TypeOperations(t *testing.T) {
	tests := []struct {
		name           string
		proposalType   ProposalType
		expectedString string
		isExecutable   bool
	}{
		{
			name:           "Text proposal",
			proposalType:   Text,
			expectedString: "Text",
			isExecutable:   false,
		},
		{
			name:           "CommunityPoolSpend proposal",
			proposalType:   CommunityPoolSpend,
			expectedString: "CommunityPoolSpend",
			isExecutable:   true,
		},
		{
			name:           "ParameterChange proposal",
			proposalType:   ParameterChange,
			expectedString: "ParameterChange",
			isExecutable:   true,
		},
		{
			name:           "Unknown proposal type",
			proposalType:   "UNKNOWN",
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
		name           string
		metadata       *ProposalMetadata
		data          *ProposalData
		expectedError bool
	}{
		{
			name: "Valid Text proposal",
			metadata: &ProposalMetadata{
				title:       "Valid Title",
				description: "Valid Description",
			},
			data: &ProposalData{
				proposalType: Text,
			},
			expectedError: false,
		},
		{
			name: "Invalid metadata",
			metadata: &ProposalMetadata{
				title:       "",
				description: "Valid Description",
			},
			data: &ProposalData{
				proposalType: Text,
			},
			expectedError: true,
		},
		{
			name: "Invalid CommunityPoolSpend proposal",
			metadata: &ProposalMetadata{
				title:       "Valid Title",
				description: "Valid Description",
			},
			data: &ProposalData{
				proposalType: CommunityPoolSpend,
				communityPoolSpend: CommunityPoolSpendInfo{
					to:        std.Address(""),
					tokenPath: "",
					amount:    0,
				},
			},
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			proposal := &Proposal{
				metadata: tc.metadata,
				data:     tc.data,
			}

			// when
			err := proposal.Validate()

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
	config := Config{
		VotingStartDelay: 100,
		VotingPeriod:    200,
		ExecutionDelay:  100,
		ExecutionWindow: 200,
		Quorum:         50,
	}

	tests := []struct {
		name           string
		proposalType   ProposalType
		currentTime    time.Time
		isExecuted     bool
		isCanceled     bool
		expectedActive bool
	}{
		{
			name:           "Active Text proposal",
			proposalType:   Text,
			currentTime:    baseTime.Add(time.Duration(150) * time.Second),
			expectedActive: true,
		},
		{
			name:           "Executed proposal",
			proposalType:   CommunityPoolSpend,
			currentTime:    baseTime.Add(time.Duration(100 + 200 + 100) * time.Second), // voting start + voting period + execution delay
			isExecuted:     true,
			expectedActive: false,
		},
		{
			name:           "Canceled proposal",
			proposalType:   ParameterChange,
			currentTime:    baseTime.Add(time.Duration(100 + 200 + 100) * time.Second), // voting start + voting period + execution delay
			isCanceled:     true,
			expectedActive: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			proposal := NewProposal(
				1,
				NewProposalStatus(config, 1000, tc.proposalType.IsExecutable(), baseTime.Unix()),
				&ProposalMetadata{title: "Test", description: "Test"},
				&ProposalData{proposalType: tc.proposalType},
				std.Address("g1proposer"),
				1,
				baseTime.Unix(),
				std.ChainHeight(),
			)

			if tc.isExecuted {
				err := proposal.execute(tc.currentTime.Unix(), 100, std.Address("g1executor"))
				uassert.NoError(t, err)
			}
			if tc.isCanceled {
				err := proposal.cancel(tc.currentTime.Unix(), 100, std.Address("g1canceler"))
				uassert.NoError(t, err)
			}

			// when & then
			uassert.Equal(t, proposal.IsActive(tc.currentTime.Unix()), tc.expectedActive)
		})
	}
}

// TestNewProposal tests creation of new proposal
func TestNewProposal(t *testing.T) {
	tests := []struct {
		name          string
		proposalType  ProposalType
		title        string
		description  string
		proposer     std.Address
	}{
		{
			name:         "Create Text proposal",
			proposalType: Text,
			title:       "Test Title",
			description: "Test Description",
			proposer:    std.Address("g1proposer"),
		},
		{
			name:         "Create CommunityPoolSpend proposal",
			proposalType: CommunityPoolSpend,
			title:       "Spend Proposal",
			description: "Community Pool Spend",
			proposer:    std.Address("g1proposer"),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			baseTime := time.Now().Unix()
			config := Config{
				VotingStartDelay: 100,
				VotingPeriod:    200,
				ExecutionDelay:  100,
				ExecutionWindow: 200,
				Quorum:         50,
			}

			// when
			proposal := NewProposal(
				1,
				NewProposalStatus(config, 1000, tc.proposalType.IsExecutable(), baseTime),
				NewProposalMetadata(tc.title, tc.description),
				&ProposalData{proposalType: tc.proposalType},
				tc.proposer,
				1,
				baseTime,
				std.ChainHeight(),
			)

			// then
			uassert.NotNil(t, proposal)
			uassert.Equal(t, proposal.Type().String(), tc.proposalType.String())
			uassert.Equal(t, proposal.Title(), tc.title)
			uassert.Equal(t, proposal.Description(), tc.description)
			uassert.Equal(t, proposal.Proposer().String(), tc.proposer.String())
			uassert.Equal(t, proposal.CreatedAt(), baseTime)
		})
	}
} 