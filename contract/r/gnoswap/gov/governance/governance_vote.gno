package governance

import (
	"std"
	"time"

	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/halt"
)

// Vote allows a user to vote on a given proposal.
// The user's voting weight is determined by their accumulated delegated stake at proposal creation time.
// Each user can only vote once per proposal, and votes cannot be changed after submission.
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - proposalID: unique identifier of the proposal to vote on
//   - yes: true for "yes" vote, false for "no" vote
//
// Returns:
//   - string: the voting weight used for this vote as formatted string
//
// Panics:
//   - if system is halted
//   - if user has already voted on this proposal
//   - if voting period has ended or not started
//   - if user has no voting weight for this proposal
//
// ref: https://docs.gnoswap.io/contracts/governance/vote.gno#vote
func Vote(cur realm, proposalID int64, yes bool) string {
	// Check if system is halted before allowing voting
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}

	// Get current blockchain state and caller information
	currentHeight := std.ChainHeight()
	currentAt := time.Now()
	previousRealm := std.PreviousRealm()

	// Mint and distribute GNS tokens as part of the voting process
	en.MintAndDistributeGns(cross)

	// Extract voter address from realm context
	voter := previousRealm.Address()

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

// vote handles the core voting logic.
// This internal function validates voting conditions, records the vote, and updates proposal tallies.
//
// Parameters:
//   - proposalID: unique identifier of the proposal
//   - voterAddress: address of the voter
//   - votedYes: true for "yes" vote, false for "no" vote
//   - votedHeight: blockchain height when vote is cast
//   - votedAt: timestamp when vote is cast
//
// Returns:
//   - *VotingInfo: voting information for the user
//   - int64: total "yes" vote weight after this vote
//   - int64: total "no" vote weight after this vote
//   - error: voting error if any
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
