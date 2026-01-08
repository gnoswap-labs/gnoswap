package v1

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/governance"
)

// setupGetterTest creates a mock governance instance with test data
func setupGetterTest(t *testing.T) *governanceV1 {
	t.Helper()

	gv := newMockGovernance()

	// Setup config
	config := governance.Config{
		VotingStartDelay: 100,
		VotingPeriod:     200,
		ExecutionDelay:   100,
		ExecutionWindow:  200,
		Quorum:           50,
	}
	gv.store.SetConfig(1, config)
	gv.store.GetConfigCounter().Next()

	return gv
}

// setupGetterTestWithProposal creates a mock governance instance with a proposal
func setupGetterTestWithProposal(t *testing.T) *governanceV1 {
	t.Helper()

	gv := setupGetterTest(t)

	baseTime := time.Now().Unix()
	config, _ := gv.store.GetConfig(1)

	proposal := governance.NewProposal(
		1,
		NewProposalStatus(config, 1000, governance.Text.IsExecutable(), baseTime),
		governance.NewProposalMetadata("Test Proposal", "Test Description"),
		governance.NewProposalData(governance.Text, nil, nil),
		address("g1proposer"),
		1,
		baseTime,
		baseTime,
		runtime.ChainHeight(),
	)

	gv.store.SetProposal(1, proposal)
	gv.store.GetProposalCounter().Next()
	gv.store.AddUserProposal("g1proposer", 1)

	return gv
}

// ==================================
// Store Data Getter Tests
// ==================================

func TestGetLatestConfigVersion(t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(t *testing.T) *governanceV1
		expected int64
	}{
		{
			name: "returns config version 1",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTest(t)
			},
			expected: 1,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			version := gv.GetLatestConfigVersion()
			uassert.Equal(t, tc.expected, version)
		})
	}
}

func TestGetCurrentProposalID(t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(t *testing.T) *governanceV1
		expected int64
	}{
		{
			name: "returns 0 when no proposals",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTest(t)
			},
			expected: 0,
		},
		{
			name: "returns 1 when one proposal exists",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			expected: 1,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			id := gv.GetCurrentProposalID()
			uassert.Equal(t, tc.expected, id)
		})
	}
}

func TestGetMaxSmoothingPeriod(t *testing.T) {
	gv := setupGetterTest(t)

	t.Run("returns max smoothing period", func(t *testing.T) {
		period := gv.GetMaxSmoothingPeriod()
		uassert.Equal(t, int64(maxSmoothingPeriod), period)
	})
}

// ==================================
// Config Getter Tests
// ==================================

func TestGetLatestConfig(t *testing.T) {
	gv := setupGetterTest(t)

	t.Run("returns latest config", func(t *testing.T) {
		config := gv.GetLatestConfig()
		uassert.Equal(t, int64(100), config.VotingStartDelay)
		uassert.Equal(t, int64(200), config.VotingPeriod)
		uassert.Equal(t, int64(50), config.Quorum)
	})
}

func TestGetConfig(t *testing.T) {
	testCases := []struct {
		name          string
		setup         func(t *testing.T) *governanceV1
		configVersion int64
		expectError   bool
	}{
		{
			name: "returns config for valid version",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTest(t)
			},
			configVersion: 1,
			expectError:   false,
		},
		{
			name: "returns error for invalid version",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTest(t)
			},
			configVersion: 999,
			expectError:   true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			config, err := gv.GetConfig(tc.configVersion)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, int64(100), config.VotingStartDelay)
			}
		})
	}
}

// ==================================
// Proposal Getter Tests
// ==================================

func TestGetProposalCount(t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(t *testing.T) *governanceV1
		expected int
	}{
		{
			name: "returns 0 when no proposals",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTest(t)
			},
			expected: 0,
		},
		{
			name: "returns 1 when one proposal exists",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			expected: 1,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			count := gv.GetProposalCount()
			uassert.Equal(t, tc.expected, count)
		})
	}
}

func TestGetProposalIDs(t *testing.T) {
	testCases := []struct {
		name           string
		setup          func(t *testing.T) *governanceV1
		offset         int
		count          int
		expectedLength int
	}{
		{
			name: "returns empty when no proposals",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTest(t)
			},
			offset:         0,
			count:          10,
			expectedLength: 0,
		},
		{
			name: "returns proposal IDs",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			offset:         0,
			count:          10,
			expectedLength: 1,
		},
		{
			name: "offset beyond range returns empty",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			offset:         100,
			count:          10,
			expectedLength: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			ids := gv.GetProposalIDs(tc.offset, tc.count)
			uassert.Equal(t, tc.expectedLength, len(ids))
		})
	}
}

func TestExistsProposal(t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(t *testing.T) *governanceV1
		proposalID int64
		expected   bool
	}{
		{
			name: "returns true for existing proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID: 1,
			expected:   true,
		},
		{
			name: "returns false for non-existent proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID: 999,
			expected:   false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			exists := gv.ExistsProposal(tc.proposalID)
			uassert.Equal(t, tc.expected, exists)
		})
	}
}

func TestGetProposal(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T) *governanceV1
		proposalID  int64
		expectError bool
	}{
		{
			name: "returns proposal for valid ID",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  1,
			expectError: false,
		},
		{
			name: "returns error for invalid ID",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  999,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			proposal, err := gv.GetProposal(tc.proposalID)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.True(t, proposal != nil)
			}
		})
	}
}

func TestGetProposerByProposalId(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T) *governanceV1
		proposalID  int64
		expected    address
		expectError bool
	}{
		{
			name: "returns proposer for valid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  1,
			expected:    address("g1proposer"),
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  999,
			expected:    address(""),
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			proposer, err := gv.GetProposerByProposalId(tc.proposalID)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expected, proposer)
			}
		})
	}
}

func TestGetProposalTypeByProposalId(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T) *governanceV1
		proposalID  int64
		expected    governance.ProposalType
		expectError bool
	}{
		{
			name: "returns proposal type for valid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  1,
			expected:    governance.Text,
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  999,
			expected:    governance.ProposalType(0),
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			proposalType, err := gv.GetProposalTypeByProposalId(tc.proposalID)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expected.String(), proposalType.String())
			}
		})
	}
}

func TestGetYeaByProposalId(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T) *governanceV1
		proposalID  int64
		expected    int64
		expectError bool
	}{
		{
			name: "returns 0 yes votes for new proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  1,
			expected:    0,
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  999,
			expected:    0,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			yea, err := gv.GetYeaByProposalId(tc.proposalID)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expected, yea)
			}
		})
	}
}

func TestGetNayByProposalId(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T) *governanceV1
		proposalID  int64
		expected    int64
		expectError bool
	}{
		{
			name: "returns 0 no votes for new proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  1,
			expected:    0,
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  999,
			expected:    0,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			nay, err := gv.GetNayByProposalId(tc.proposalID)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expected, nay)
			}
		})
	}
}

func TestGetTitleByProposalId(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T) *governanceV1
		proposalID  int64
		expected    string
		expectError bool
	}{
		{
			name: "returns title for valid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  1,
			expected:    "Test Proposal",
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  999,
			expected:    "",
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			title, err := gv.GetTitleByProposalId(tc.proposalID)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expected, title)
			}
		})
	}
}

func TestGetDescriptionByProposalId(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T) *governanceV1
		proposalID  int64
		expected    string
		expectError bool
	}{
		{
			name: "returns description for valid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  1,
			expected:    "Test Description",
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  999,
			expected:    "",
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			description, err := gv.GetDescriptionByProposalId(tc.proposalID)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expected, description)
			}
		})
	}
}

// ==================================
// Vote Getter Tests
// ==================================

func TestGetVoteStatus(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T) *governanceV1
		proposalID  int64
		expectError bool
	}{
		{
			name: "returns vote status for valid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  1,
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  999,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			quorum, maxVotingWeight, yesWeight, noWeight, err := gv.GetVoteStatus(tc.proposalID)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.True(t, quorum >= 0)
				uassert.True(t, maxVotingWeight >= 0)
				uassert.Equal(t, int64(0), yesWeight)
				uassert.Equal(t, int64(0), noWeight)
			}
		})
	}
}

func TestGetVotingInfoCount(t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(t *testing.T) *governanceV1
		proposalID int64
		expected   int
	}{
		{
			name: "returns 0 when no votes",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID: 1,
			expected:   0,
		},
		{
			name: "returns 0 for non-existent proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID: 999,
			expected:   0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			count := gv.GetVotingInfoCount(tc.proposalID)
			uassert.Equal(t, tc.expected, count)
		})
	}
}

func TestGetVotingInfoAddresses(t *testing.T) {
	testCases := []struct {
		name           string
		setup          func(t *testing.T) *governanceV1
		proposalID     int64
		offset         int
		count          int
		expectedLength int
	}{
		{
			name: "returns empty when no votes",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:     1,
			offset:         0,
			count:          10,
			expectedLength: 0,
		},
		{
			name: "returns empty for non-existent proposal",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:     999,
			offset:         0,
			count:          10,
			expectedLength: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			addrs := gv.GetVotingInfoAddresses(tc.proposalID, tc.offset, tc.count)
			uassert.Equal(t, tc.expectedLength, len(addrs))
		})
	}
}

func TestExistsVotingInfo(t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(t *testing.T) *governanceV1
		proposalID int64
		addr       address
		expected   bool
	}{
		{
			name: "returns false when no votes",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID: 1,
			addr:       address("g1voter"),
			expected:   false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			exists := gv.ExistsVotingInfo(tc.proposalID, tc.addr)
			uassert.Equal(t, tc.expected, exists)
		})
	}
}

func TestGetVotingInfo(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T) *governanceV1
		proposalID  int64
		addr        address
		expectError bool
	}{
		{
			name: "returns error when vote does not exist",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			proposalID:  1,
			addr:        address("g1voter"),
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			_, err := gv.GetVotingInfo(tc.proposalID, tc.addr)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
			}
		})
	}
}

// ==================================
// User Proposal Getter Tests
// ==================================

func TestGetUserProposalCount(t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(t *testing.T) *governanceV1
		user     address
		expected int
	}{
		{
			name: "returns count for user with proposals",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			user:     address("g1proposer"),
			expected: 1,
		},
		{
			name: "returns 0 for user without proposals",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			user:     address("g1unknown"),
			expected: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			count := gv.GetUserProposalCount(tc.user)
			uassert.Equal(t, tc.expected, count)
		})
	}
}

func TestGetUserProposalIDs(t *testing.T) {
	testCases := []struct {
		name           string
		setup          func(t *testing.T) *governanceV1
		user           address
		offset         int
		count          int
		expectedLength int
	}{
		{
			name: "returns proposal IDs for user",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			user:           address("g1proposer"),
			offset:         0,
			count:          10,
			expectedLength: 1,
		},
		{
			name: "returns empty for user without proposals",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			user:           address("g1unknown"),
			offset:         0,
			count:          10,
			expectedLength: 0,
		},
		{
			name: "offset beyond range returns empty",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			user:           address("g1proposer"),
			offset:         100,
			count:          10,
			expectedLength: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			ids := gv.GetUserProposalIDs(tc.user, tc.offset, tc.count)
			uassert.Equal(t, tc.expectedLength, len(ids))
		})
	}
}

// ==================================
// Active Proposal Query Tests
// ==================================

func TestGetOldestActiveProposalSnapshotTime(t *testing.T) {
	testCases := []struct {
		name            string
		setup           func(t *testing.T) *governanceV1
		expectHasActive bool
	}{
		{
			name: "returns false when no proposals",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTest(t)
			},
			expectHasActive: false,
		},
		{
			name: "returns true when active proposal exists",
			setup: func(t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(t)
			},
			expectHasActive: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			snapshotTime, hasActive := gv.GetOldestActiveProposalSnapshotTime()
			uassert.Equal(t, tc.expectHasActive, hasActive)
			if hasActive {
				uassert.True(t, snapshotTime > 0)
			}
		})
	}
}

// ==================================
// Voting Weight Snapshot Getter Tests
// ==================================

func TestGetCurrentVotingWeightSnapshot(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T) *governanceV1
		expectError bool
	}{
		{
			name: "returns snapshot when config and voting weight exist",
			setup: func(t *testing.T) *governanceV1 {
				gv := setupGetterTest(t)
				// Set total delegation for voting weight to exist
				accessor := gv.stakerAccessor.(*mockGovStakerAccessor)
				accessor.totalDelegation = 1000
				return gv
			},
			expectError: false,
		},
		{
			name: "returns error when config does not exist",
			setup: func(t *testing.T) *governanceV1 {
				gv := newMockGovernance()
				return gv
			},
			expectError: true,
		},
		{
			name: "returns error when voting weight does not exist",
			setup: func(t *testing.T) *governanceV1 {
				// Config exists but no voting weight
				return setupGetterTest(t)
			},
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gv := tc.setup(t)
			_, _, err := gv.GetCurrentVotingWeightSnapshot()
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
			}
		})
	}
}
