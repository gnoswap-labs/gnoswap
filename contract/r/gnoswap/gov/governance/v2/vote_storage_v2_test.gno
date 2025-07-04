package v2

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

// Test FNV-1a hash function distribution
func TestHashAddress_Distribution(t *testing.T) {
	addresses := []std.Address{
		testutils.TestAddress("valid"),
		testutils.TestAddress("valid2"),
		testutils.TestAddress("valid3"),
		testutils.TestAddress("valid4"),
		testutils.TestAddress("valid5"),
	}

	hashes := make(map[uint32]bool)
	for _, addr := range addresses {
		hash, err := hashAddress(addr)
		uassert.NoError(t, err, "Should not return error")
		// Check for collisions
		if hashes[hash] {
			t.Errorf("Hash collision detected for address %s", addr)
		}
		hashes[hash] = true

		// Verify hash is non-zero
		if hash == 0 {
			t.Errorf("Hash returned zero for address %s", addr)
		}
	}

	// All addresses should produce different hashes
	uassert.Equal(t, len(addresses), len(hashes), "Hash collision detected")
}

// Test hash consistency
func TestHashAddress_Consistency(t *testing.T) {
	addr := testutils.TestAddress("test_consistency")

	// Hash should be consistent
	hash1, err := hashAddress(addr)
	uassert.NoError(t, err, "Should not return error")
	hash2, err := hashAddress(addr)
	uassert.NoError(t, err, "Should not return error")
	hash3, err := hashAddress(addr)
	uassert.NoError(t, err, "Should not return error")

	uassert.Equal(t, hash1, hash2, "Hash should be consistent")
	uassert.Equal(t, hash2, hash3, "Hash should be consistent")
}

// Test basic vote recording
func TestRecordVote_Basic(t *testing.T) {
	proposalId := uint64(1)
	voter := testutils.TestAddress("voter1")
	weight := uint64(100)

	// Record a yes vote
	err := recordVote(proposalId, voter, weight, true)
	uassert.NoError(t, err, "Should record vote successfully")

	// Check vote was recorded
	totalYes, totalNo, voteCount, err := GetVoteSummary(proposalId)
	uassert.NoError(t, err, "Should get vote summary")
	uassert.Equal(t, uint64(100), totalYes, "Yes votes should be 100")
	uassert.Equal(t, uint64(0), totalNo, "No votes should be 0")
	uassert.Equal(t, uint32(1), voteCount, "Vote count should be 1")

	// Clean up
	DeleteProposalVotes(proposalId)
}

// Test duplicate vote prevention
func TestRecordVote_DuplicatePrevention(t *testing.T) {
	proposalId := uint64(2)
	voter := testutils.TestAddress("voter2")
	weight := uint64(100)

	// Record first vote
	err := recordVote(proposalId, voter, weight, true)
	uassert.NoError(t, err, "Should record first vote")

	// Try to vote again
	err = recordVote(proposalId, voter, weight, false)
	uassert.Error(t, err, "Should prevent duplicate vote")
	uassert.Equal(t, errAlreadyVoted.Error(), err.Error(), "Should return already voted error")

	// Verify only one vote was recorded
	_, _, voteCount, _ := GetVoteSummary(proposalId)
	uassert.Equal(t, uint32(1), voteCount, "Should have only one vote")

	// Clean up
	DeleteProposalVotes(proposalId)
}

// Test multiple voters
func TestRecordVote_MultipleVoters(t *testing.T) {
	proposalId := uint64(3)

	voters := []struct {
		addr   std.Address
		weight uint64
		isYes  bool
	}{
		{testutils.TestAddress("voter3_1"), 100, true},
		{testutils.TestAddress("voter3_2"), 200, true},
		{testutils.TestAddress("voter3_3"), 150, false},
		{testutils.TestAddress("voter3_4"), 50, false},
		{testutils.TestAddress("voter3_5"), 300, true},
	}

	// Record all votes
	for _, v := range voters {
		err := recordVote(proposalId, v.addr, v.weight, v.isYes)
		uassert.NoError(t, err, "Should record vote for "+string(v.addr))
	}

	// Check totals
	totalYes, totalNo, voteCount, err := GetVoteSummary(proposalId)
	uassert.NoError(t, err, "Should get vote summary")
	uassert.Equal(t, uint64(600), totalYes, "Total yes votes incorrect") // 100+200+300
	uassert.Equal(t, uint64(200), totalNo, "Total no votes incorrect")   // 150+50
	uassert.Equal(t, uint32(5), voteCount, "Vote count incorrect")

	// Clean up
	DeleteProposalVotes(proposalId)
}

// Test weight validation
func TestRecordVote_WeightValidation(t *testing.T) {
	proposalId := uint64(4)
	voter := testutils.TestAddress("voter4")

	// Test zero weight
	err := recordVote(proposalId, voter, 0, true)
	uassert.Error(t, err, "Should reject zero weight")
	uassert.Equal(t, errInvalidWeight.Error(), err.Error(), "Should return invalid weight error")

	// Test weight overflow
	overflowWeight := uint64(^uint32(0)) + 1 // Max uint32 + 1
	err = recordVote(proposalId, voter, overflowWeight, true)
	uassert.Error(t, err, "Should reject overflow weight")

	// Clean up
	DeleteProposalVotes(proposalId)
}

// Test HasVoted function
func TestHasVoted(t *testing.T) {
	proposalId := uint64(5)
	voter1 := testutils.TestAddress("voter5_1")
	voter2 := testutils.TestAddress("voter5_2")

	// Initially no votes
	uassert.False(t, HasVoted(proposalId, voter1), "Should not have voted yet")
	uassert.False(t, HasVoted(proposalId, voter2), "Should not have voted yet")

	// Record vote for voter1
	err := recordVote(proposalId, voter1, 100, true)
	uassert.NoError(t, err, "Should record vote")

	// Check HasVoted
	uassert.True(t, HasVoted(proposalId, voter1), "Voter1 should have voted")
	uassert.False(t, HasVoted(proposalId, voter2), "Voter2 should not have voted")

	// Clean up
	DeleteProposalVotes(proposalId)
}

// Test GetUserVote function
func TestGetUserVote(t *testing.T) {
	proposalId := uint64(6)
	voter := testutils.TestAddress("voter6")
	expectedWeight := uint32(250)

	// Record a vote
	err := recordVote(proposalId, voter, uint64(expectedWeight), true)
	uassert.NoError(t, err, "Should record vote")

	// Get the vote
	weight, isYes, found := GetUserVote(proposalId, voter)
	uassert.True(t, found, "Should find vote")
	uassert.Equal(t, expectedWeight, weight, "Weight should match")
	uassert.True(t, isYes, "Should be a yes vote")

	// Try non-existent voter
	_, _, found = GetUserVote(proposalId, testutils.TestAddress("non_existent"))
	uassert.False(t, found, "Should not find vote for non-voter")

	// Clean up
	DeleteProposalVotes(proposalId)
}

// Test GetAllVotes function
func TestGetAllVotes(t *testing.T) {
	proposalId := uint64(7)

	// Record some votes
	voters := []std.Address{
		testutils.TestAddress("voter7_1"),
		testutils.TestAddress("voter7_2"),
		testutils.TestAddress("voter7_3"),
	}

	for i, voter := range voters {
		weight := uint64((i + 1) * 100)
		isYes := i%2 == 0
		err := recordVote(proposalId, voter, weight, isYes)
		uassert.NoError(t, err, "Should record vote")
	}

	// Get all votes
	votes, err := GetAllVotes(proposalId)
	uassert.NoError(t, err, "Should get all votes")
	uassert.Equal(t, len(voters), len(votes), "Should have correct number of votes")

	// Verify votes are correct
	for i, vote := range votes {
		expectedWeight := uint32((i + 1) * 100)
		expectedIsYes := i%2 == 0
		uassert.Equal(t, expectedWeight, vote.Weight, "Weight should match")
		uassert.Equal(t, expectedIsYes, vote.IsYes, "Vote choice should match")
	}

	// Test non-existent proposal
	_, err = GetAllVotes(9999)
	uassert.Error(t, err, "Should error for non-existent proposal")

	// Clean up
	DeleteProposalVotes(proposalId)
}

// Test CalculateVoteStats function
func TestCalculateVoteStats(t *testing.T) {
	proposalId := uint64(8)
	quorumThreshold := uint64(500)

	// Record votes: 600 yes, 400 no
	votes := []struct {
		voter  std.Address
		weight uint64
		isYes  bool
	}{
		{testutils.TestAddress("voter8_1"), 300, true},
		{testutils.TestAddress("voter8_2"), 200, false},
		{testutils.TestAddress("voter8_3"), 300, true},
		{testutils.TestAddress("voter8_4"), 200, false},
	}

	for _, v := range votes {
		err := recordVote(proposalId, v.voter, v.weight, v.isYes)
		uassert.NoError(t, err, "Should record vote")
	}

	// Calculate stats
	stats, err := CalculateVoteStats(proposalId, quorumThreshold)
	uassert.NoError(t, err, "Should calculate stats")

	// Verify stats
	uassert.Equal(t, uint64(600), stats.TotalYes, "Total yes incorrect")
	uassert.Equal(t, uint64(400), stats.TotalNo, "Total no incorrect")
	uassert.Equal(t, uint32(4), stats.VoteCount, "Vote count incorrect")
	uassert.Equal(t, uint64(6000), stats.YesPercent, "Yes percent incorrect") // 60.00%
	uassert.Equal(t, uint64(4000), stats.NoPercent, "No percent incorrect")   // 40.00%
	uassert.True(t, stats.HasQuorum, "Should have quorum")
	uassert.Equal(t, quorumThreshold, stats.QuorumValue, "Quorum value incorrect")

	// Test without quorum
	lowQuorumProposal := uint64(9)
	err = recordVote(lowQuorumProposal, testutils.TestAddress("voter9"), 100, true)
	uassert.NoError(t, err, "Should record vote")

	stats, err = CalculateVoteStats(lowQuorumProposal, uint64(500))
	uassert.NoError(t, err, "Should calculate stats")
	uassert.False(t, stats.HasQuorum, "Should not have quorum")

	// Clean up
	DeleteProposalVotes(proposalId)
	DeleteProposalVotes(lowQuorumProposal)
}

func TestHashAddress_EdgeCases(t *testing.T) {
	tests := []struct {
		name      string
		addr      std.Address
		hash      uint32
		shouldErr bool
	}{
		{"empty", std.Address(""), 0, true},
		{"long", std.Address("g" + "1234567890abcdef" + "1234567890abcdef" + "1234567890abcdef"), 0, true},
		{"valid", testutils.TestAddress("valid"), 2760214899, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldErr {
				_, err := hashAddress(tt.addr)
				uassert.Error(t, err, "Should return error")
			} else {
				hash, err := hashAddress(tt.addr)
				uassert.NoError(t, err, "Should not return error")
				uassert.Equal(t, tt.hash, hash, "Hash should match")
			}
		})
	}
}

// Test proposal not found scenarios
func TestProposalNotFound(t *testing.T) {
	nonExistentId := uint64(99999)

	// Test GetVoteSummary
	_, _, _, err := GetVoteSummary(nonExistentId)
	uassert.Error(t, err, "Should error for non-existent proposal")
	uassert.Equal(t, errProposalNotFound.Error(), err.Error(), "Should return proposal not found error")

	// Test HasVoted
	hasVoted := HasVoted(nonExistentId, testutils.TestAddress("test_voter"))
	uassert.False(t, hasVoted, "Should return false for non-existent proposal")

	// Test GetUserVote
	_, _, found := GetUserVote(nonExistentId, testutils.TestAddress("test_voter"))
	uassert.False(t, found, "Should not find vote for non-existent proposal")
}
