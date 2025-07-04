package v2

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

// ProposalVotes represents all votes for a single proposal.
// This structure is optimized for cache efficiency by grouping all votes together.
type ProposalVotes struct {
	TotalYes  uint64       // Total weight of yes votes
	TotalNo   uint64       // Total weight of no votes
	VoteCount uint32       // Total number of votes cast
	Votes     []VoteRecord // Compressed vote records
}

// VoteRecord represents a single vote with compressed fields.
// Total size: 9 bytes (4 + 4 + 1)
type VoteRecord struct {
	UserHash uint32 // Hash of user address (collision-resistant)
	Weight   uint32 // Vote weight (sufficient for most cases)
	IsYes    bool   // Vote choice (1 bit effectively)
}

// Storage for votes grouped by proposal
var proposalVotes = avl.NewTree() // proposalId -> *ProposalVotes

// Error definitions
var (
	errAlreadyVoted     = ufmt.Errorf("user has already voted on this proposal")
	errProposalNotFound = ufmt.Errorf("proposal not found")
	errInvalidWeight    = ufmt.Errorf("invalid vote weight")
)

// hashAddress implements FNV-1a hash for collision-resistant address hashing.
// FNV-1a provides good distribution and is fast for small inputs like addresses.
func hashAddress(addr std.Address) (uint32, error) {
	if !addr.IsValid() {
		return 0, ufmt.Errorf("invalid address: %s", addr)
	}
	// FNV-1a 32-bit offset basis
	hash := uint32(2166136261)

	// Process each byte of the address string
	addrStr := addr.String()
	for i := 0; i < len(addrStr); i++ {
		// XOR with byte
		hash ^= uint32(addrStr[i])
		// Multiply by FNV prime
		hash *= 16777619
	}

	return hash, nil
}

// getOrCreateProposalVotes retrieves or creates a ProposalVotes structure
func getOrCreateProposalVotes(proposalId uint64) *ProposalVotes {
	key := ufmt.Sprintf("%d", proposalId)
	value, exists := proposalVotes.Get(key)
	if exists {
		res, ok := value.(*ProposalVotes)
		if !ok {
			panic(ufmt.Errorf("invalid proposal votes"))
		}
		return res
	}

	// Create new ProposalVotes
	pv := &ProposalVotes{
		Votes: make([]VoteRecord, 0),
	}
	proposalVotes.Set(key, pv)
	return pv
}

// recordVote records a vote for a proposal with duplicate checking
func recordVote(proposalId uint64, voter std.Address, weight uint64, isYes bool) error {
	// Validate weight
	if weight == 0 {
		return errInvalidWeight
	}

	// Check if weight fits in uint32
	if weight > uint64(^uint32(0)) {
		return ufmt.Errorf("vote weight exceeds maximum: %d", weight)
	}

	pv := getOrCreateProposalVotes(proposalId)

	// Check for duplicate vote using hash
	userHash, err := hashAddress(voter)
	if err != nil {
		return err
	}
	for _, v := range pv.Votes {
		if v.UserHash == userHash {
			// TODO: In production, we might want to handle hash collisions
			// by storing full addresses for verification
			return errAlreadyVoted
		}
	}

	// Add vote
	pv.Votes = append(pv.Votes, VoteRecord{
		UserHash: userHash,
		Weight:   uint32(weight),
		IsYes:    isYes,
	})

	// Update totals
	if isYes {
		pv.TotalYes += weight
	} else {
		pv.TotalNo += weight
	}
	pv.VoteCount++

	// Save back to storage
	key := ufmt.Sprintf("%d", proposalId)
	proposalVotes.Set(key, pv)

	return nil
}

// GetVoteSummary returns the vote totals for a proposal
func GetVoteSummary(proposalId uint64) (totalYes, totalNo uint64, voteCount uint32, err error) {
	key := ufmt.Sprintf("%d", proposalId)
	value, exists := proposalVotes.Get(key)
	if !exists {
		return 0, 0, 0, errProposalNotFound
	}

	pv, ok := value.(*ProposalVotes)
	if !ok {
		return 0, 0, 0, ufmt.Errorf("invalid proposal votes")
	}

	return pv.TotalYes, pv.TotalNo, pv.VoteCount, nil
}

// HasVoted checks if a user has already voted on a proposal
func HasVoted(proposalId uint64, voter std.Address) bool {
	if !voter.IsValid() {
		panic(ufmt.Sprintf("invalid voter address: %s", voter))
	}
	key := ufmt.Sprintf("%d", proposalId)
	value, exists := proposalVotes.Get(key)
	if !exists {
		return false
	}

	pv, ok := value.(*ProposalVotes)
	if !ok {
		panic("invalid proposal votes")
	}

	userHash, err := hashAddress(voter)
	if err != nil {
		return false
	}

	for _, v := range pv.Votes {
		if v.UserHash == userHash {
			return true
		}
	}

	return false
}

// GetUserVote retrieves a specific user's vote on a proposal
func GetUserVote(proposalId uint64, voter std.Address) (weight uint32, isYes bool, found bool) {
	if !voter.IsValid() {
		panic(ufmt.Sprintf("invalid voter address: %s", voter))
	}
	key := ufmt.Sprintf("%d", proposalId)
	value, exists := proposalVotes.Get(key)
	if !exists {
		return 0, false, false
	}

	pv, ok := value.(*ProposalVotes)
	if !ok {
		panic("invalid proposal votes")
	}

	userHash, err := hashAddress(voter)
	if err != nil {
		return 0, false, false
	}

	for _, v := range pv.Votes {
		if v.UserHash == userHash {
			return v.Weight, v.IsYes, true
		}
	}

	return 0, false, false
}

// DeleteProposalVotes removes all votes for a proposal (used for cleanup)
func DeleteProposalVotes(proposalId uint64) {
	key := ufmt.Sprintf("%d", proposalId)
	proposalVotes.Remove(key)
}

// GetAllVotes returns all vote records for a proposal (for debugging/analysis)
func GetAllVotes(proposalId uint64) ([]VoteRecord, error) {
	key := ufmt.Sprintf("%d", proposalId)
	value, exists := proposalVotes.Get(key)
	if !exists {
		return nil, errProposalNotFound
	}

	pv, ok := value.(*ProposalVotes)
	if !ok {
		return nil, ufmt.Errorf("invalid proposal votes")
	}
	// Return a copy to prevent external modification
	votes := make([]VoteRecord, len(pv.Votes))
	copy(votes, pv.Votes)
	return votes, nil
}

// GetVoteStats returns detailed statistics about votes for a proposal
type VoteStats struct {
	TotalYes    uint64
	TotalNo     uint64
	VoteCount   uint32
	YesPercent  uint64 // Percentage * 100 (e.g., 6550 = 65.50%)
	NoPercent   uint64 // Percentage * 100
	HasQuorum   bool
	QuorumValue uint64
}

// CalculateVoteStats computes detailed vote statistics for a proposal
func CalculateVoteStats(proposalId uint64, quorumThreshold uint64) (*VoteStats, error) {
	totalYes, totalNo, voteCount, err := GetVoteSummary(proposalId)
	if err != nil {
		return nil, err
	}

	totalVotes := totalYes + totalNo
	stats := &VoteStats{
		TotalYes:    totalYes,
		TotalNo:     totalNo,
		VoteCount:   voteCount,
		HasQuorum:   totalVotes >= quorumThreshold,
		QuorumValue: quorumThreshold,
	}

	// Calculate percentages (multiply by 10000 for 2 decimal precision)
	if totalVotes > 0 {
		stats.YesPercent = (totalYes * 10000) / totalVotes
		stats.NoPercent = (totalNo * 10000) / totalVotes
	}

	return stats, nil
}
