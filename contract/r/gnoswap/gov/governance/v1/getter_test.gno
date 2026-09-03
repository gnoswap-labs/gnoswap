package governance

import (
	"chain/runtime"
	"strconv"
	"testing"
	"time"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gov/governance"
)

// setupGetterTest creates a mock governance instance with test data
func setupGetterTest(cur realm, t *testing.T) *governanceV1 {
	t.Helper()

	gv := newMockGovernance()

	// Setup config
	config := governance.NewConfig(100, 200, 0, 50, 0, 100, 200)
	gv.store.SetConfig(0, cur, 1, config)
	gv.store.GetConfigCounter().Next()

	return gv
}

// setupGetterTestWithProposal creates a mock governance instance with a proposal
func setupGetterTestWithProposal(cur realm, t *testing.T) *governanceV1 {
	t.Helper()

	gv := setupGetterTest(cur, t)

	baseTime := time.Now().Unix()
	config, _ := gv.store.GetConfig(1)

	proposal := governance.NewProposal(
		1,
		NewProposalStatus(
			config, 1000, governance.Text.IsExecutable(), baseTime,
			1000,
		),
		governance.NewProposalMetadata("Test Proposal", "Test Description"),
		governance.NewProposalData(governance.Text, nil, nil),
		address("g1proposer"),
		1,
		baseTime,
		runtime.ChainHeight(),
	)

	uassert.True(t, gv.addProposal(0, cur, proposal))
	gv.store.GetProposalCounter().Next()

	return gv
}

// ==================================
// Store Data Getter Tests
// ==================================

func TestGetLatestConfigVersion(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(cur realm, t *testing.T) *governanceV1
		expected int64
	}{
		{
			name: "returns config version 1",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTest(cur, t)
			},
			expected: 1,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			version := gv.GetLatestConfigVersion()
			uassert.Equal(t, tc.expected, version)
		})
	}
}

func TestGetCurrentProposalID(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(cur realm, t *testing.T) *governanceV1
		expected int64
	}{
		{
			name: "returns 0 when no proposals",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTest(cur, t)
			},
			expected: 0,
		},
		{
			name: "returns 1 when one proposal exists",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			expected: 1,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			id := gv.GetCurrentProposalID()
			uassert.Equal(t, tc.expected, id)
		})
	}
}

func TestGetMaxSmoothingPeriod(cur realm, t *testing.T) {
	gv := setupGetterTest(cur, t)

	t.Run("returns max smoothing period", func(cur realm, t *testing.T) {
		period := gv.GetMaxSmoothingPeriod()
		uassert.Equal(t, int64(maxSmoothingPeriod), period)
	})
}

// ==================================
// Config Getter Tests
// ==================================

func TestGetLatestConfig(cur realm, t *testing.T) {
	gv := setupGetterTest(cur, t)

	t.Run("returns latest config", func(cur realm, t *testing.T) {
		config, err := gv.GetLatestConfig()
		uassert.NoError(t, err)
		uassert.Equal(t, int64(100), config.VotingStartDelay)
		uassert.Equal(t, int64(200), config.VotingPeriod)
		uassert.Equal(t, int64(50), config.Quorum)
	})

	t.Run("returns error when no config exists", func(cur realm, t *testing.T) {
		emptyGV := newMockGovernance()
		_, err := emptyGV.GetLatestConfig()
		uassert.ErrorContains(t, err, errDataNotFound)
	})
}

func TestGetConfig(cur realm, t *testing.T) {
	testCases := []struct {
		name          string
		setup         func(cur realm, t *testing.T) *governanceV1
		configVersion int64
		expectError   bool
	}{
		{
			name: "returns config for valid version",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTest(cur, t)
			},
			configVersion: 1,
			expectError:   false,
		},
		{
			name: "returns error for invalid version",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTest(cur, t)
			},
			configVersion: 999,
			expectError:   true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
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

func TestGetProposalsSize(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(cur realm, t *testing.T) *governanceV1
		expected int
	}{
		{
			name: "returns 0 when no proposals",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTest(cur, t)
			},
			expected: 0,
		},
		{
			name: "returns 1 when one proposal exists",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			expected: 1,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			count := gv.GetProposals().Size()
			uassert.Equal(t, tc.expected, count)
		})
	}
}

func TestGetProposals(cur realm, t *testing.T) {
	testCases := []struct {
		name           string
		setup          func(cur realm, t *testing.T) *governanceV1
		offset         int
		count          int
		expectedLength int
	}{
		{
			name: "returns empty when no proposals",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTest(cur, t)
			},
			offset:         0,
			count:          10,
			expectedLength: 0,
		},
		{
			name: "returns proposal IDs",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			offset:         0,
			count:          10,
			expectedLength: 1,
		},
		{
			name: "offset beyond range returns empty",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			offset:         100,
			count:          10,
			expectedLength: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)

			ids := make([]string, 0)
			gv.GetProposals().IterateByOffset(tc.offset, tc.count, func(key string, value any) bool {
				_, ok := value.(*governance.Proposal)
				uassert.True(t, ok)
				ids = append(ids, key)
				return false
			})
			uassert.Equal(t, tc.expectedLength, len(ids))
		})
	}
}

func TestGetProposals_EntriesAreCloned(cur realm, t *testing.T) {
	gv := setupGetterTestWithProposal(cur, t)
	proposals := gv.GetProposals()

	first, ok := proposals.Get("1").(*governance.Proposal)
	uassert.True(t, ok)
	second, ok := proposals.Get("1").(*governance.Proposal)
	uassert.True(t, ok)

	// Each read hands out a distinct clone, so a reader cannot reach the stored
	// proposal nor any other reader's copy.
	uassert.False(t, first == second)
}

func TestExistsProposal(cur realm, t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(cur realm, t *testing.T) *governanceV1
		proposalID int64
		expected   bool
	}{
		{
			name: "returns true for existing proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID: 1,
			expected:   true,
		},
		{
			name: "returns false for non-existent proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID: 999,
			expected:   false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			exists := gv.ExistsProposal(tc.proposalID)
			uassert.Equal(t, tc.expected, exists)
		})
	}
}

func TestGetProposal(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T) *governanceV1
		proposalID  int64
		expectError bool
	}{
		{
			name: "returns proposal for valid ID",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  1,
			expectError: false,
		},
		{
			name: "returns error for invalid ID",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  999,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			proposal, ok := gv.GetProposals().Get(formatProposalKey(tc.proposalID)).(*governance.Proposal)
			if tc.expectError {
				uassert.False(t, ok)
			} else {
				uassert.True(t, ok)
				uassert.True(t, proposal != nil)
			}
		})
	}
}

func TestGetProposerByProposalId(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T) *governanceV1
		proposalID  int64
		expected    address
		expectError bool
	}{
		{
			name: "returns proposer for valid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  1,
			expected:    address("g1proposer"),
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  999,
			expected:    address(""),
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
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

func TestGetProposalTypeByProposalId(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T) *governanceV1
		proposalID  int64
		expected    governance.ProposalType
		expectError bool
	}{
		{
			name: "returns proposal type for valid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  1,
			expected:    governance.Text,
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  999,
			expected:    governance.ProposalType(0),
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
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

func TestGetYeaByProposalId(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T) *governanceV1
		proposalID  int64
		expected    int64
		expectError bool
	}{
		{
			name: "returns 0 yes votes for new proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  1,
			expected:    0,
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  999,
			expected:    0,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
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

func TestGetNayByProposalId(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T) *governanceV1
		proposalID  int64
		expected    int64
		expectError bool
	}{
		{
			name: "returns 0 no votes for new proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  1,
			expected:    0,
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  999,
			expected:    0,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
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

func TestGetTitleByProposalId(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T) *governanceV1
		proposalID  int64
		expected    string
		expectError bool
	}{
		{
			name: "returns title for valid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  1,
			expected:    "Test Proposal",
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  999,
			expected:    "",
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
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

func TestGetDescriptionByProposalId(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T) *governanceV1
		proposalID  int64
		expected    string
		expectError bool
	}{
		{
			name: "returns description for valid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  1,
			expected:    "Test Description",
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  999,
			expected:    "",
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
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

func TestGetVoteStatus(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T) *governanceV1
		proposalID  int64
		expectError bool
	}{
		{
			name: "returns vote status for valid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  1,
			expectError: false,
		},
		{
			name: "returns error for invalid proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  999,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
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

func TestGetVotingInfoCount(cur realm, t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(cur realm, t *testing.T) *governanceV1
		proposalID int64
		expected   int
	}{
		{
			name: "returns 0 when no votes",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID: 1,
			expected:   0,
		},
		{
			name: "returns 0 for non-existent proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID: 999,
			expected:   0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			count := votingInfoCount(gv, tc.proposalID)
			uassert.Equal(t, tc.expected, count)
		})
	}
}

func TestGetVotingInfos(cur realm, t *testing.T) {
	testCases := []struct {
		name           string
		setup          func(cur realm, t *testing.T) *governanceV1
		proposalID     int64
		offset         int
		count          int
		expectedLength int
	}{
		{
			name: "returns empty when no votes",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:     1,
			offset:         0,
			count:          10,
			expectedLength: 0,
		},
		{
			name: "returns empty for non-existent proposal",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:     999,
			offset:         0,
			count:          10,
			expectedLength: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)

			votingInfos := gv.GetVotingInfos(tc.proposalID)
			if votingInfos == nil {
				uassert.Equal(t, tc.expectedLength, 0)
				return
			}

			addrs := make([]string, 0)
			votingInfos.IterateByOffset(tc.offset, tc.count, func(key string, _ any) bool {
				addrs = append(addrs, key)
				return false
			})
			uassert.Equal(t, tc.expectedLength, len(addrs))
		})
	}
}

func TestExistsVotingInfo(cur realm, t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(cur realm, t *testing.T) *governanceV1
		proposalID int64
		addr       address
		expected   bool
	}{
		{
			name: "returns false when no votes",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID: 1,
			addr:       address("g1voter"),
			expected:   false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			exists := gv.ExistsVotingInfo(tc.proposalID, tc.addr)
			uassert.Equal(t, tc.expected, exists)
		})
	}
}

func TestGetVotingInfo(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T) *governanceV1
		proposalID  int64
		addr        address
		expectError bool
	}{
		{
			name: "returns error when vote does not exist",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			proposalID:  1,
			addr:        address("g1voter"),
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			_, ok := votingInfoOf(gv, tc.proposalID, tc.addr)
			uassert.Equal(t, !tc.expectError, ok)
		})
	}
}

// ==================================
// User Proposal Getter Tests
// ==================================

func TestGetUserProposalCount(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(cur realm, t *testing.T) *governanceV1
		user     address
		expected int
	}{
		{
			name: "returns count for user with proposals",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			user:     address("g1proposer"),
			expected: 1,
		},
		{
			name: "returns 0 for user without proposals",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			user:     address("g1unknown"),
			expected: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			count := userProposalCount(gv, tc.user)
			uassert.Equal(t, tc.expected, count)
		})
	}
}

func TestGetUserProposals(cur realm, t *testing.T) {
	testCases := []struct {
		name           string
		setup          func(cur realm, t *testing.T) *governanceV1
		user           address
		expectedLength int
	}{
		{
			name: "returns proposal IDs for user",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			user:           address("g1proposer"),
			expectedLength: 1,
		},
		{
			name: "returns nothing for user without proposals",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			user:           address("g1unknown"),
			expectedLength: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)

			value := gv.GetUserProposals().Get(tc.user.String())
			if value == nil {
				uassert.Equal(t, tc.expectedLength, 0)
				return
			}

			ids, ok := value.([]int64)
			uassert.True(t, ok)
			uassert.Equal(t, tc.expectedLength, len(ids))
		})
	}
}

func TestGetUserProposals_EntriesAreCopied(cur realm, t *testing.T) {
	gv := setupGetterTestWithProposal(cur, t)
	userProposals := gv.GetUserProposals()

	first, ok := userProposals.Get("g1proposer").([]int64)
	uassert.True(t, ok)
	first[0] = 9999

	// The stored slice is copied on read, so the write above is not visible.
	second, ok := userProposals.Get("g1proposer").([]int64)
	uassert.True(t, ok)
	uassert.NotEqual(t, int64(9999), second[0])
}

// ==================================
// Active Proposal Query Tests
// ==================================

func TestGetOldestActiveProposalSnapshotTime(cur realm, t *testing.T) {
	testCases := []struct {
		name            string
		setup           func(cur realm, t *testing.T) *governanceV1
		expectHasActive bool
	}{
		{
			name: "returns false when no proposals",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTest(cur, t)
			},
			expectHasActive: false,
		},
		{
			name: "returns true when active proposal exists",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				return setupGetterTestWithProposal(cur, t)
			},
			expectHasActive: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			snapshotTime, hasActive := gv.GetOldestActiveProposalSnapshotTime()
			uassert.Equal(t, tc.expectHasActive, hasActive)
			if hasActive {
				uassert.True(t, snapshotTime > 0)
			}
		})
	}
}

func TestPruneInactiveProposals_RemovesTerminalIndexEntries(cur realm, t *testing.T) {
	gv := setupGetterTest(cur, t)
	store := gv.store.(*mockGovernanceStore)
	config, _ := store.GetConfig(1)
	now := time.Now().Unix()

	expired := governance.NewProposal(
		1,
		NewProposalStatus(config, 1000, governance.Text.IsExecutable(), now-1000, 1000),
		governance.NewProposalMetadata("expired", "expired"),
		governance.NewProposalData(governance.Text, nil, nil),
		address("g1expired"),
		1,
		now-1000,
		runtime.ChainHeight(),
	)
	active := governance.NewProposal(
		2,
		NewProposalStatus(config, 1000, governance.Text.IsExecutable(), now, 1000),
		governance.NewProposalMetadata("active", "active"),
		governance.NewProposalData(governance.Text, nil, nil),
		address("g1active"),
		1,
		now,
		runtime.ChainHeight(),
	)
	uassert.True(t, gv.addProposal(0, cur, expired))
	uassert.True(t, gv.addProposal(0, cur, active))

	uassert.True(t, gv.pruneInactiveProposals(0, cur, now) == nil)

	uassert.Equal(t, 1, store.GetActiveProposalsBySnapshot().Size())
	snapshotTime, hasActive := gv.GetOldestActiveProposalSnapshotTime()
	uassert.True(t, hasActive)
	uassert.Equal(t, active.SnapshotTime(), snapshotTime)
}

// ==================================
// Voting Weight Snapshot Getter Tests
// ==================================

func TestGetCurrentVotingWeightSnapshot(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T) *governanceV1
		expectError bool
	}{
		{
			name: "returns snapshot when config and voting weight exist",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				gv := setupGetterTest(cur, t)
				// Set total delegation for voting weight to exist
				accessor := gv.stakerAccessor.(*mockGovStakerAccessor)
				accessor.totalDelegation = 1000
				return gv
			},
			expectError: false,
		},
		{
			name: "returns error when config does not exist",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				gv := newMockGovernance()
				return gv
			},
			expectError: true,
		},
		{
			name: "returns error when voting weight does not exist",
			setup: func(cur realm, t *testing.T) *governanceV1 {
				// Config exists but no voting weight
				return setupGetterTest(cur, t)
			},
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			gv := tc.setup(cur, t)
			_, _, err := gv.GetCurrentVotingWeightSnapshot()
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
			}
		})
	}
}

// formatProposalKey mirrors the storage key encoding for proposal IDs.
func formatProposalKey(proposalID int64) string {
	return strconv.FormatInt(proposalID, 10)
}

// votingInfoCount reports how many voters a proposal has through the read-only view.
func votingInfoCount(gv *governanceV1, proposalID int64) int {
	votingInfos := gv.GetVotingInfos(proposalID)
	if votingInfos == nil {
		return 0
	}

	return votingInfos.Size()
}

// votingInfoOf reads one voter's info through the read-only view.
func votingInfoOf(gv *governanceV1, proposalID int64, addr address) (*governance.VotingInfo, bool) {
	votingInfos := gv.GetVotingInfos(proposalID)
	if votingInfos == nil {
		return nil, false
	}

	votingInfo, ok := votingInfos.Get(addr.String()).(*governance.VotingInfo)

	return votingInfo, ok
}

// userProposalCount reports how many proposals a user created through the read-only view.
func userProposalCount(gv *governanceV1, user address) int {
	proposalIDs, ok := gv.GetUserProposals().Get(user.String()).([]int64)
	if !ok {
		return 0
	}

	return len(proposalIDs)
}
