package governance

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/access"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"

	"gno.land/r/gnoswap/gov/governance"
)

// Vote casts a vote on a proposal.
//
// Records an on-chain vote with weight based on delegated xGNS.
// Uses the proposal's timestamp anchors and configured smoothing duration to
// prevent manipulation. Votes are final and cannot be changed.
//
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0 while threading the realm context
//   - rlm: current realm context; implementation validates it before reading or writing governance state
//   - proposalID: ID of the proposal to vote on
//   - yes: true for yes vote, false for no vote
//
// Vote Weight Calculation:
//   - Based on the voter's delegated xGNS amount
//   - Averages delegation at the stored smoothing timestamp and proposal creation time
//   - Uses Unix timestamp history, not a block-height snapshot
//   - Includes self-delegation and delegations received by the voter
//
// Requirements:
//   - Proposal must be in voting period
//   - Voter must have xGNS delegated at one of the lookup timestamps
//   - Cannot vote twice on same proposal
//   - Voting period is 7 days by default and is configurable
//
// Returns:
//   - voteWeight: voting weight applied to the caller's vote, formatted as a string
func (gv *governanceV1) Vote(_ int, rlm realm, proposalID int64, yes bool) string {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedGovernance()

	// Get current blockchain state and caller information
	currentHeight := runtime.ChainHeight()
	currentAt := time.Now()

	// Mint and distribute GNS tokens as part of the voting process
	emission.MintAndDistributeGns(cross(rlm))

	// Extract voter address from realm context
	voterRealm := rlm.Previous()
	voter := voterRealm.Address()

	// Process the vote and get updated vote tallies
	userVote, totalYesVoteWeight, totalNoVoteWeight, err := gv.vote(
		0, rlm,
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
	voteWeight := utils.FormatInt(userVote.VotedWeight())
	voterStr := voter.String()

	chain.Emit(
		"Vote",
		"prevAddr", voterStr,
		"prevPkgPath", voterRealm.PkgPath(),
		"proposalId", utils.FormatInt(proposalID),
		"voter", voterStr,
		"yes", userVote.VotingType(),
		"voteWeight", voteWeight,
		"voteYes", utils.FormatInt(totalYesVoteWeight),
		"voteNo", utils.FormatInt(totalNoVoteWeight),
	)

	return voteWeight
}

// vote handles core voting logic.
//
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0 while threading the realm context
//   - rlm: propagated current realm context passed to the voting-info store, which validates it before writing
//   - proposalID: identifier of the proposal whose voting period and tallies are evaluated
//   - voterAddress: address whose historical delegation weight is used and whose vote is recorded
//   - votedYes: true to add the weight to the yes tally, false to add it to the no tally
//   - votedHeight: blockchain height at which the vote was cast
//   - votedAt: Unix timestamp at which the vote was cast and voting-period validity is checked
//
// Returns:
//   - VotingInfo: recorded vote details, or the default unvoted value when validation fails
//   - int64: proposal's updated total yes-vote weight
//   - int64: proposal's updated total no-vote weight
//   - error: nil when the vote is stored and tallies update; otherwise the validation or storage error
func (gv *governanceV1) vote(
	_ int, rlm realm,
	proposalID int64,
	voterAddress address,
	votedYes bool,
	votedHeight,
	votedAt int64,
) (governance.VotingInfo, int64, int64, error) {
	// Retrieve the proposal from storage
	proposal, ok := gv.getProposal(proposalID)
	if !ok {
		return governance.DefaultVotingInfo(), 0, 0, makeErrorWithDetails(errDataNotFound, "not found proposal")
	}

	proposalResolver := NewProposalResolver(proposal)

	// Check if current time is within voting period
	if !proposalResolver.IsVotingPeriod(votedAt) {
		return governance.DefaultVotingInfo(), 0, 0, makeErrorWithDetails(errUnableToVoteOutOfPeriod, "cannot vote out of voting period")
	}

	// Get user's voting weight by averaging timestamp-history values at the
	// proposal's stored smoothing anchor and creation time.
	snapshotTime := proposal.SnapshotTime()
	createdAt := proposal.CreatedAt()

	weightAtSnapshot, ok := gv.stakerAccessor.GetUserDelegationAmountAtSnapshot(voterAddress, snapshotTime)
	if !ok {
		weightAtSnapshot = 0
	}

	weightAtCreated, ok := gv.stakerAccessor.GetUserDelegationAmountAtSnapshot(voterAddress, createdAt)
	if !ok {
		weightAtCreated = 0
	}

	votingWeight := gnsmath.SafeAddInt64(weightAtSnapshot, weightAtCreated) / 2
	if votingWeight <= 0 {
		return governance.DefaultVotingInfo(), 0, 0, makeErrorWithDetails(
			errNotEnoughVotingWeight, "no voting weight at snapshot time")
	}

	userVote, exists := gv.getProposalUserVotingInfo(proposalID, voterAddress)
	if !exists {
		userVote = governance.NewVotingInfo(votingWeight)
	}

	if userVote.IsVoted() {
		return governance.DefaultVotingInfo(), 0, 0, makeErrorWithDetails(errAlreadyVoted, "user has already voted")
	}
	userVote = governance.NewVotedVotingInfo(votingWeight, votedYes, votingWeight, votedHeight, votedAt)

	votingInfosTree, _ := gv.getProposalUserVotingInfos(proposalID)
	if votingInfosTree == nil {
		return governance.DefaultVotingInfo(), 0, 0, makeErrorWithDetails(
			errDataNotFound, "voting infos tree not found for proposal")
	}

	votingInfosTree.Set(voterAddress.String(), userVote)
	err := gv.store.SetProposalVotingInfos(0, rlm, proposalID, votingInfosTree)
	if err != nil {
		return governance.DefaultVotingInfo(), 0, 0, err
	}

	// Update proposal vote tallies
	err = proposalResolver.Vote(votedYes, votingWeight)
	if err != nil {
		return governance.DefaultVotingInfo(), 0, 0, err
	}

	return userVote, proposal.VotingYesWeight(), proposal.VotingNoWeight(), nil
}
