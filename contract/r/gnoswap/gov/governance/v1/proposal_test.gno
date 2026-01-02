package v1

import (
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
			name:          "Valid Text proposal",
			metadata:      governance.NewProposalMetadata("Valid Title", "Valid Description"),
			data:          governance.NewProposalData(governance.Text, nil, nil),
			expectedError: false,
		},
		{
			name:          "Invalid metadata",
			metadata:      governance.NewProposalMetadata("", "Valid Description"),
			data:          governance.NewProposalData(governance.Text, nil, nil),
			expectedError: true,
		},
		{
			name:          "Invalid CommunityPoolSpend proposal",
			metadata:      governance.NewProposalMetadata("Valid Title", "Valid Description"),
			data:          governance.NewProposalData(governance.CommunityPoolSpend, governance.NewCommunityPoolSpendInfo(address(""), "", 0), nil),
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
			proposal := newTestProposal(
				1,
				NewProposalStatus(config, 1000, governance.Text.IsExecutable(), baseTime),
				tc.metadata,
				tc.data,
				address("g1proposer"),
				1, // configVersion
				baseTime,
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
			proposal := newTestProposal(
				1,
				NewProposalStatus(config, 1000, tc.proposalType.IsExecutable(), baseTime.Unix()),
				governance.NewProposalMetadata("Test", "Test"),
				governance.NewProposalData(tc.proposalType, nil, nil),
				address("g1proposer"),
				1, // configVersion
				baseTime.Unix(),
			)

			if tc.isExecuted {
				resolver := NewProposalResolver(proposal)
				err := resolver.Vote(true, 600)
				uassert.NoError(t, err)

				err = NewProposalResolver(proposal).execute(tc.currentTime.Unix(), 100, address("g1executor"))
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

// TestProposal_IsActive_StatusTypeCaching tests the IsActive method with StatusType caching
// This test verifies that IsActive correctly determines proposal activity based on status
func TestProposal_IsActive_StatusTypeCaching(t *testing.T) {
	baseTime := int64(1000)

	tests := []struct {
		name               string
		description        string
		proposalType       governance.ProposalType
		votingStartDelay   int64
		votingPeriod       int64
		executionDelay     int64
		executionWindow    int64
		quorum             int64
		maxVotingWeight    int64
		currentTimeOffset  int64 // offset from baseTime
		setupFunc          func(proposal *governance.Proposal, current int64)
		expectedActive     bool
		expectedStatusType governance.ProposalStatusType
	}{
		// Upcoming status tests
		{
			name:               "StatusUpcoming: before voting starts",
			description:        "Proposal is in upcoming status before voting period",
			proposalType:       governance.Text,
			votingStartDelay:   100,
			votingPeriod:       200,
			executionDelay:     100,
			executionWindow:    200,
			quorum:             50,
			maxVotingWeight:    1000,
			currentTimeOffset:  50, // before voting starts
			setupFunc:          nil,
			expectedActive:     true,
			expectedStatusType: governance.StatusUpcoming,
		},
		{
			name:               "StatusUpcoming: at creation time",
			description:        "Proposal is in upcoming status at creation",
			proposalType:       governance.CommunityPoolSpend,
			votingStartDelay:   100,
			votingPeriod:       200,
			executionDelay:     100,
			executionWindow:    200,
			quorum:             50,
			maxVotingWeight:    1000,
			currentTimeOffset:  0, // at creation
			setupFunc:          nil,
			expectedActive:     true,
			expectedStatusType: governance.StatusUpcoming,
		},
		// Active status tests
		{
			name:               "StatusActive: during voting period",
			description:        "Proposal is active during voting period",
			proposalType:       governance.Text,
			votingStartDelay:   100,
			votingPeriod:       200,
			executionDelay:     100,
			executionWindow:    200,
			quorum:             50,
			maxVotingWeight:    1000,
			currentTimeOffset:  150, // during voting
			setupFunc:          nil,
			expectedActive:     true,
			expectedStatusType: governance.StatusActive,
		},
		{
			name:               "StatusActive: at voting start",
			description:        "Proposal is active exactly at voting start",
			proposalType:       governance.ParameterChange,
			votingStartDelay:   100,
			votingPeriod:       200,
			executionDelay:     100,
			executionWindow:    200,
			quorum:             50,
			maxVotingWeight:    1000,
			currentTimeOffset:  100, // exactly at voting start
			setupFunc:          nil,
			expectedActive:     true,
			expectedStatusType: governance.StatusActive,
		},
		// Passed status tests (Text vs non-Text)
		{
			name:              "StatusPassed: Text proposal becomes inactive",
			description:       "Text proposal becomes inactive after passing (no execution needed)",
			proposalType:      governance.Text,
			votingStartDelay:  100,
			votingPeriod:      200,
			executionDelay:    100,
			executionWindow:   200,
			quorum:            50,
			maxVotingWeight:   1000,
			currentTimeOffset: 350, // after voting ends
			setupFunc: func(proposal *governance.Proposal, current int64) {
				// Add enough yes votes to pass
				resolver := NewProposalResolver(proposal)
				resolver.Vote(true, 600) // 60% yes
			},
			expectedActive:     false,
			expectedStatusType: governance.StatusPassed,
		},
		{
			name:              "StatusPassed: CommunityPoolSpend stays active",
			description:       "CommunityPoolSpend proposal stays active after passing (awaiting execution)",
			proposalType:      governance.CommunityPoolSpend,
			votingStartDelay:  100,
			votingPeriod:      200,
			executionDelay:    100,
			executionWindow:   200,
			quorum:            50,
			maxVotingWeight:   1000,
			currentTimeOffset: 350, // after voting ends, before executable
			setupFunc: func(proposal *governance.Proposal, current int64) {
				resolver := NewProposalResolver(proposal)
				resolver.Vote(true, 600) // 60% yes
			},
			expectedActive:     true,
			expectedStatusType: governance.StatusPassed,
		},
		{
			name:              "StatusPassed: ParameterChange stays active",
			description:       "ParameterChange proposal stays active after passing",
			proposalType:      governance.ParameterChange,
			votingStartDelay:  100,
			votingPeriod:      200,
			executionDelay:    100,
			executionWindow:   200,
			quorum:            50,
			maxVotingWeight:   1000,
			currentTimeOffset: 350,
			setupFunc: func(proposal *governance.Proposal, current int64) {
				resolver := NewProposalResolver(proposal)
				resolver.Vote(true, 600)
			},
			expectedActive:     true,
			expectedStatusType: governance.StatusPassed,
		},
		// Executable status tests
		{
			name:              "StatusExecutable: proposal can be executed",
			description:       "Proposal is in executable window",
			proposalType:      governance.CommunityPoolSpend,
			votingStartDelay:  100,
			votingPeriod:      200,
			executionDelay:    100,
			executionWindow:   200,
			quorum:            50,
			maxVotingWeight:   1000,
			currentTimeOffset: 450, // after execution delay
			setupFunc: func(proposal *governance.Proposal, current int64) {
				resolver := NewProposalResolver(proposal)
				resolver.Vote(true, 600)
			},
			expectedActive:     true,
			expectedStatusType: governance.StatusExecutable,
		},
		// Rejected status tests
		{
			name:              "StatusRejected: majority no votes",
			description:       "Proposal rejected by majority no votes",
			proposalType:      governance.Text,
			votingStartDelay:  100,
			votingPeriod:      200,
			executionDelay:    100,
			executionWindow:   200,
			quorum:            50,
			maxVotingWeight:   1000,
			currentTimeOffset: 350,
			setupFunc: func(proposal *governance.Proposal, current int64) {
				resolver := NewProposalResolver(proposal)
				resolver.Vote(false, 600) // 60% no
			},
			expectedActive:     false,
			expectedStatusType: governance.StatusRejected,
		},
		{
			name:              "StatusRejected: insufficient yes votes for quorum",
			description:       "Proposal rejected due to not reaching quorum of yes votes",
			proposalType:      governance.CommunityPoolSpend,
			votingStartDelay:  100,
			votingPeriod:      200,
			executionDelay:    100,
			executionWindow:   200,
			quorum:            50,
			maxVotingWeight:   1000,
			currentTimeOffset: 350,
			setupFunc: func(proposal *governance.Proposal, current int64) {
				resolver := NewProposalResolver(proposal)
				resolver.Vote(true, 400)  // 40% yes - not enough
				resolver.Vote(false, 500) // 50% no
			},
			expectedActive:     false,
			expectedStatusType: governance.StatusRejected,
		},
		// Executed status tests
		{
			name:              "StatusExecuted: proposal has been executed",
			description:       "Proposal is inactive after execution",
			proposalType:      governance.CommunityPoolSpend,
			votingStartDelay:  100,
			votingPeriod:      200,
			executionDelay:    100,
			executionWindow:   200,
			quorum:            50,
			maxVotingWeight:   1000,
			currentTimeOffset: 450,
			setupFunc: func(proposal *governance.Proposal, current int64) {
				resolver := NewProposalResolver(proposal)
				resolver.Vote(true, 600)
				resolver.execute(current, 100, address("g1executor"))
			},
			expectedActive:     false,
			expectedStatusType: governance.StatusExecuted,
		},
		// Canceled status tests
		{
			name:              "StatusCanceled: proposal canceled before voting",
			description:       "Proposal is inactive after cancellation",
			proposalType:      governance.ParameterChange,
			votingStartDelay:  100,
			votingPeriod:      200,
			executionDelay:    100,
			executionWindow:   200,
			quorum:            50,
			maxVotingWeight:   1000,
			currentTimeOffset: 50,
			setupFunc: func(proposal *governance.Proposal, current int64) {
				resolver := NewProposalResolver(proposal)
				resolver.cancel(current, 100, address("g1proposer"))
			},
			expectedActive:     false,
			expectedStatusType: governance.StatusCanceled,
		},
		// Expired status tests
		{
			name:              "StatusExpired: execution window passed",
			description:       "Proposal is inactive after execution window expires",
			proposalType:      governance.CommunityPoolSpend,
			votingStartDelay:  100,
			votingPeriod:      200,
			executionDelay:    100,
			executionWindow:   200,
			quorum:            50,
			maxVotingWeight:   1000,
			currentTimeOffset: 700, // after execution window
			setupFunc: func(proposal *governance.Proposal, current int64) {
				resolver := NewProposalResolver(proposal)
				resolver.Vote(true, 600)
			},
			expectedActive:     false,
			expectedStatusType: governance.StatusExpired,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			config := governance.Config{
				VotingStartDelay: tc.votingStartDelay,
				VotingPeriod:     tc.votingPeriod,
				ExecutionDelay:   tc.executionDelay,
				ExecutionWindow:  tc.executionWindow,
				Quorum:           tc.quorum,
			}

			proposal := newTestProposal(
				1,
				NewProposalStatus(config, tc.maxVotingWeight, tc.proposalType.IsExecutable(), baseTime),
				governance.NewProposalMetadata("Test Title", "Test Description"),
				governance.NewProposalData(tc.proposalType, nil, nil),
				address("g1proposer"),
				1,
				baseTime,
			)

			currentTime := baseTime + tc.currentTimeOffset

			// Apply setup function if provided
			if tc.setupFunc != nil {
				tc.setupFunc(proposal, currentTime)
			}

			// when
			resolver := NewProposalResolver(proposal)
			isActive := resolver.IsActive(currentTime)
			statusType := resolver.StatusType(currentTime)

			// then
			uassert.Equal(t, tc.expectedActive, isActive)
			uassert.Equal(t, tc.expectedStatusType.String(), statusType.String())
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
			proposal := newTestProposal(
				1,
				NewProposalStatus(config, 1000, tc.proposalType.IsExecutable(), baseTime),
				governance.NewProposalMetadata(tc.title, tc.description),
				governance.NewProposalData(tc.proposalType, nil, nil),
				tc.proposer,
				1, // configVersion
				baseTime,
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
