package governance

import (
	"std"
	"time"

	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
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
func Vote(cur realm, proposalID int64, yes bool) string {
	halt.AssertIsNotHaltedGovernance()

	// Get current blockchain state and caller information
	currentHeight := std.ChainHeight()
	currentAt := time.Now()

	// Mint and distribute GNS tokens as part of the voting process
	en.MintAndDistributeGns(cross)

	// Extract voter address from realm context
	voter := std.PreviousRealm().Address()

	// Process the vote and get updated vote tallies
	userVote, totalYesVoteWeight, totalNoVoteWeight, err := vote(
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
	previousRealm := std.PreviousRealm()
	std.Emit(
		"Vote",
		"prevAddr", previousRealm.Address().String(),
		"prevPkgPath", previousRealm.PkgPath(),
		"proposalId", formatInt(proposalID),
		"voter", voter.String(),
		"yes", userVote.VotingType(),
		"voteWeight", formatInt(userVote.VotedWeight()),
		"voteYes", formatInt(totalYesVoteWeight),
		"voteNo", formatInt(totalNoVoteWeight),
	)

	return formatInt(userVote.VotedWeight())
}

// vote handles core voting logic.
func vote(
	proposalID int64,
	voterAddress std.Address,
	votedYes bool,
	votedHeight,
	votedAt int64,
) (*VotingInfo, int64, int64, error) {
	// Retrieve the proposal from storage
	proposal, ok := getProposal(proposalID)
	if !ok {
		return nil, 0, 0, makeErrorWithDetails(errDataNotFound, "not found proposal")
	}

	// Check if current time is within voting period
	if !proposal.IsVotingPeriod(votedAt) {
		return nil, 0, 0, makeErrorWithDetails(errUnableToVoteOutOfPeriod, "can not vote out of voting period")
	}

	// Get user's voting information for this proposal
	userVote, ok := getProposalUserVotingInfo(proposalID, voterAddress)
	if !ok {
		return nil, 0, 0, makeErrorWithDetails(errDataNotFound, "not found user's voting info")
	}

	// Check if user has voting weight available
	votingWeight := userVote.AvailableVoteWeight()
	if votingWeight <= 0 {
		return nil, 0, 0, makeErrorWithDetails(errNotEnoughVotingWeight, "no voting weight")
	}

	// Record the vote in user's voting info (this also prevents double voting)
	err := userVote.vote(votedYes, votingWeight, votedHeight, votedAt)
	if err != nil {
		return nil, 0, 0, err
	}

	// Update proposal vote tallies
	err = proposal.vote(votedYes, votingWeight)
	if err != nil {
		return nil, 0, 0, err
	}

	// Return updated vote information and current tallies
	return userVote, proposal.VotingYesWeight(), proposal.VotingNoWeight(), nil
}
