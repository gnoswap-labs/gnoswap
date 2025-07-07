package governance

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/halt"
)

type voteWithWeight struct {
	Yes         bool
	Weight      uint64
	VotedHeight uint64
	VotedAt     uint64
}

var (
	votes         = avl.NewTree()           // voteKey(proposalId:user) -> yes/no
	userVotes     = avl.NewTree()           // user -> proposalId -> voteWithWeight
	accumYesVotes = make(map[uint64]uint64) // proposalId -> yes
	accumNoVotes  = make(map[uint64]uint64) // proposalId -> no
)

// Vote allows a user to vote on a given proposal.
// The user's voting weight is determined by their accumulated delegated stake until proposal creation time.
// ref: https://docs.gnoswap.io/contracts/governance/vote.gno#vote
func Vote(cur realm, pid uint64, yes bool) string {
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}

	en.MintAndDistributeGns(cross)

	voter := std.PreviousRealm().Address()

	// Use VoteWithUpdate to ensure proposal states are current before voting
	transition := VoteWithUpdate(pid, voter, yes)
	if err := applyTransition(transition); err != nil {
		panic(err)
	}

	// Get updated proposal and vote info for backward compatibility
	proposal, _ := governanceState.GetProposal(pid)
	voteInfo, _ := governanceState.GetUserVote(voter, pid)

	// Update backward compatibility variables
	voteKey := createVoteKey(pid, voter.String())
	setVote(pid, voter.String(), yes)
	setUserVote(voter, pid, voteWithWeight{
		Yes:         yes,
		Weight:      voteInfo.Weight,
		VotedHeight: voteInfo.VotedHeight,
		VotedAt:     voteInfo.VotedAt,
	})
	proposals.Set(formatUint(pid), proposal)

	// Get accumulated votes from state
	yesVotes, noVotes := governanceState.GetAccumulatedVotes(pid)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"Vote",
		"prevAddr", prevAddr,
		"prevPkgPath", prevPkgPath,
		"proposalId", formatUint(pid),
		"voter", voter.String(),
		"yes", voteToString(yes),
		"voteWeight", formatUint(voteInfo.Weight),
		"voteYes", formatUint(yesVotes),
		"voteNo", formatUint(noVotes),
	)

	return voteKey
}

// Cancel cancels the proposal with the given ID.
// Only callable by the proposer or if the proposer's stake has fallen below the threshold others can call.
// ref: https://docs.gnoswap.io/contracts/governance/vote.gno#cancel
func Cancel(cur realm, proposalId uint64) {
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}

	en.MintAndDistributeGns(cross)

	caller := std.PreviousRealm().Address()

	// Use CancelProposalTransition with state update
	transition := Compose(
		UpdateProposalStateTransition2(),
		CancelProposalTransition(proposalId, caller),
	)

	if err := applyTransition(transition); err != nil {
		panic(err)
	}

	// Update backward compatibility variables
	proposal, exists := governanceState.GetArchivedProposal(proposalId)
	if exists {
		proposals.Remove(formatUint(proposalId))
		archivedProposals.Set(formatUint(proposalId), proposal)
		proposalIdListByProposer.Remove(proposal.Proposer.String())
	}

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"Cancel",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"proposalId", formatUint(proposalId),
	)
}

// createVoteKey creates a vote key for a given proposal ID and voter address
func createVoteKey(pid uint64, voter string) string {
	return ufmt.Sprintf("%d:%s", pid, voter)
}

// getVote gets a vote for a given proposal ID and voter address
// Returns:
// - vote: the vote for the given proposal ID and voter address
// - exists: a boolean indicating if user has voted on the proposal
func getVote(pid uint64, voter string) (bool, bool) {
	value, exists := votes.Get(createVoteKey(pid, voter))
	if !exists {
		return false, false
	}
	return value.(bool), true
}

func setVote(pid uint64, voter string, vote bool) {
	voteKey := createVoteKey(pid, voter)
	votes.Set(voteKey, vote)
}

// createUserVoteKey creates a user vote key for a given voter address and proposal ID
func createUserVoteKey(voter std.Address, pid uint64) string {
	return ufmt.Sprintf("%s:%d", voter.String(), pid)
}

func getUserVote(voter std.Address, pid uint64) (voteWithWeight, bool) {
	value, exists := userVotes.Get(createUserVoteKey(voter, pid))
	if !exists {
		return voteWithWeight{}, false
	}
	return value.(voteWithWeight), true
}

func setUserVote(voter std.Address, pid uint64, vote voteWithWeight) {
	if vote.Yes {
		accumYesVotes[pid] += vote.Weight
	} else {
		accumNoVotes[pid] += vote.Weight
	}
	userVotes.Set(createUserVoteKey(voter, pid), vote)
}
