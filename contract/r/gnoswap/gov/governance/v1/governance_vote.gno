package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"

	"gno.land/r/gnoswap/gov/governance"
)

// Vote casts a vote on a proposal.
//
// Records on-chain vote with weight based on delegated xGNS.
// Uses 24-hour average voting power to prevent manipulation.
// Votes are final and cannot be changed.
//
// Parameters:
//   - proposalID: ID of the proposal to vote on
//   - yes: true for yes vote, false for no vote
//
// Vote Weight Calculation:
//   - Based on delegated xGNS amount
//   - 24-hour average before proposal creation
//   - Prevents flash loan attacks
//   - Includes both self-stake and delegations received
//
// Requirements:
//   - Proposal must be in voting period
//   - Voter must have xGNS delegated
//   - Cannot vote twice on same proposal
//   - Voting period typically 7 days
//
// Returns voting weight used as string.
func (gv *governanceV1) Vote(proposalID int64, yes bool) string {
	halt.AssertIsNotHaltedGovernance()

	// Get current blockchain state and caller information
	currentHeight := runtime.ChainHeight()
	currentAt := time.Now()

	// Mint and distribute GNS tokens as part of the voting process
	emission.MintAndDistributeGns(cross)

	// Extract voter address from realm context
	voterRealm := runtime.PreviousRealm()
	voter := voterRealm.Address()

	// Process the vote and get updated vote tallies
	userVote, totalYesVoteWeight, totalNoVoteWeight, err := gv.vote(
		proposalID,
		voter,
		yes,
		currentHeight,
		currentAt.Unix(),
	)
	if err != nil {
		panic(err)
	}

	// Emit voting event for tracking and transparency
	// previousRealm := runtime.PreviousRealm()
	userVoteWeight := formatInt(userVote.VotedWeight())
	voterStr := voter.String()

	chain.Emit(
		"Vote",
		"prevAddr", voterStr,
		"prevPkgPath", voterRealm.PkgPath(),
		"proposalId", formatInt(proposalID),
		"voter", voterStr,
		"yes", userVote.VotingType(),
		"voteWeight", userVoteWeight,
		"voteYes", formatInt(totalYesVoteWeight),
		"voteNo", formatInt(totalNoVoteWeight),
	)

	return userVoteWeight
}

// vote handles core voting logic.
func (gv *governanceV1) vote(
	proposalID int64,
	voterAddress address,
	votedYes bool,
	votedHeight,
	votedAt int64,
) (*governance.VotingInfo, int64, int64, error) {
	// Retrieve the proposal from storage
	proposal, ok := gv.getProposal(proposalID)
	if !ok {
		return nil, 0, 0, makeErrorWithDetails(errDataNotFound, "not found proposal")
	}

	proposalResolver := NewProposalResolver(proposal)

	// Check if current time is within voting period
	if !proposalResolver.IsVotingPeriod(votedAt) {
		return nil, 0, 0, makeErrorWithDetails(errUnableToVoteOutOfPeriod, "cannot vote out of voting period")
	}

	// Check if user has already voted on this proposal
	userVote, hasVoted := gv.getProposalUserVotingInfo(proposalID, voterAddress)
	if hasVoted && userVote.IsVoted() {
		return nil, 0, 0, makeErrorWithDetails(errAlreadyVoted, "user has already voted")
	}

	// Get user's voting weight at the proposal's snapshot time (lazy lookup)
	snapshotTime := proposal.SnapshotTime()

	votingWeight, ok := gv.stakerAccessor.GetUserDelegationAmountAtSnapshot(voterAddress, snapshotTime)
	if !ok || votingWeight <= 0 {
		return nil, 0, 0, makeErrorWithDetails(errNotEnoughVotingWeight, "no voting weight at snapshot time")
	}

	// Create or update voting info for this user
	if userVote == nil {
		userVote = governance.NewVotingInfo(votingWeight)
	}

	userVoteResolver := NewVotingInfoResolver(userVote)
	// Record the vote in user's voting info (this also prevents double voting)
	err := userVoteResolver.vote(votedYes, votingWeight, votedHeight, votedAt)
	if err != nil {
		return nil, 0, 0, err
	}

	// Store the user's vote in the proposal voting infos
	err = gv.store.SetProposalVotingInfo(proposalID, voterAddress.String(), userVote)
	if err != nil {
		return nil, 0, 0, err
	}

	// Update proposal vote tallies
	err = proposalResolver.Vote(votedYes, votingWeight)
	if err != nil {
		return nil, 0, 0, err
	}

	// Return updated vote information and current tallies
	return userVote, proposal.VotingYesWeight(), proposal.VotingNoWeight(), nil
}
