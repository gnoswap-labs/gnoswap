package governance

import (
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"

	en "gno.land/r/gnoswap/v1/emission"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/p/demo/ufmt"
)

type voteWithWeight struct {
	Yes         bool
	Weight      uint64
	VotedHeight uint64
	VotedAt     uint64
}

var (
	votes     = make(map[string]bool)                           // voteKey(proposalId:user) -> yes/no
	userVotes = make(map[std.Address]map[uint64]voteWithWeight) // user -> proposalId -> voteWithWeight
)

// Vote allows a user to vote on a given proposal.
// The user's voting weight is determined by their accumulated delegated stake until proposal creation time.
// ref: https://docs.gnoswap.io/contracts/governance/vote.gno#vote
func Vote(pid uint64, yes bool) string {
	common.IsHalted()
	en.MintAndDistributeGns()
	updateProposalsState()

	proposal, exists := proposals[pid]
	if !exists {
		panic(addDetailToError(errDataNotFound, ufmt.Sprintf("proposalId(%d) does not exist", pid)))
	}

	voter := std.PrevRealm().Addr()
	now := uint64(time.Now().Unix())

	voteKey := createVoteKey(pid, voter.String())

	state, err := newVoteState(proposal, voteKey, voter, now)
	if err != nil {
		panic(err)
	}

	if err := state.validate(); err != nil {
		panic(err)
	}

	executor := newVoteExecutor(&proposal, voter, state.userWeight)
	if err := executor.execute(yes); err != nil {
		panic(err)
	}

	proposals[pid] = proposal
	votes[voteKey] = yes

	if userVotes[voter] == nil {
		userVotes[voter] = make(map[uint64]voteWithWeight)
	}
	userVotes[voter][pid] = voteWithWeight{
		Yes:         yes,
		Weight:      state.userWeight,
		VotedHeight: uint64(std.GetHeight()),
		VotedAt:     now,
	}

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"Vote",
		"prevAddr", prevAddr,
		"prevPkgPath", prevPkgPath,
		"proposalId", ufmt.Sprintf("%d", pid),
		"yes", voteToString(yes),
		"internal_weight", ufmt.Sprintf("%d", state.userWeight),
	)

	return voteKey
}

///////////////////// Vote State /////////////////////

type VoteState struct {
	isVotingPeriod  bool
	isProposalValid bool
	hasUserVoted    bool
	userWeight      uint64
}

func newVoteState(proposal ProposalInfo, voteKey string, voter std.Address, now uint64) (*VoteState, error) {
	cfg := GetConfigVersion(proposal.ConfigVersion)
	votingStartTime := proposal.ExecutionState.CreatedAt + cfg.VotingStartDelay
	votingEndTime := votingStartTime + cfg.VotingPeriod

	return &VoteState{
		isVotingPeriod:  now >= votingStartTime && now < votingEndTime,
		isProposalValid: !proposal.ExecutionState.Canceled,
		hasUserVoted:    votes[voteKey],
		userWeight:      proposal.PossibleAddressWithWeight[voter],
	}, nil
}

func (s *VoteState) validate() error {
	if !s.isVotingPeriod {
		return errUnableToVoteOutOfPeriod
	}
	if !s.isProposalValid {
		return errUnableToVoteCanceledProposal
	}
	if s.hasUserVoted {
		return errAlreadyVoted
	}
	if s.userWeight == 0 {
		return errNotEnoughVotingWeight
	}
	return nil
}

func createVoteKey(pid uint64, voter string) string {
	return ufmt.Sprintf("%d:%s", pid, voter)
}

///////////////////// Vote Execution /////////////////////

type VoteExecutor struct {
	proposal *ProposalInfo
	voter    std.Address
	weight   uint64
}

func newVoteExecutor(proposal *ProposalInfo, voter std.Address, weight uint64) *VoteExecutor {
	return &VoteExecutor{
		proposal: proposal,
		voter:    voter,
		weight:   weight,
	}
}

func (e *VoteExecutor) execute(yes bool) error {
	if yes {
		e.proposal.Yea = safeVoteSum(e.proposal.Yea, e.weight)
	} else {
		e.proposal.Nay = safeVoteSum(e.proposal.Nay, e.weight)
	}
	return nil
}

func safeVoteSum(collected *u256.Uint, weight uint64) *u256.Uint {
	newSum, overflow := new(u256.Uint).AddOverflow(collected, u256.NewUint(weight))
	if overflow {
		panic(errOutOfRange)
	}
	return newSum
}

// Cancel cancels the proposal with the given ID.
// Only callable by the proposer or if the proposer's stake has fallen below the threshold others can call.
// ref: https://docs.gnoswap.io/contracts/governance/vote.gno#cancel
func Cancel(proposalId uint64) {
	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()

	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("proposalId(%d) does not exist", proposalId),
		))
	}

	if proposal.ExecutionState.Canceled {
		panic(addDetailToError(
			errAlreadyCanceledProposal,
			ufmt.Sprintf("proposalId(%d) has already canceled", proposalId),
		))
	}

	config := GetConfigVersion(proposal.ConfigVersion)
	now := uint64(time.Now().Unix())
	if now >= (proposal.ExecutionState.CreatedAt + config.VotingStartDelay) {
		panic(addDetailToError(
			errUnableToCancleVotingProposal,
			ufmt.Sprintf("voting has already started for proposalId(%d)", proposalId),
		))
	}

	caller := std.PrevRealm().Addr()
	if caller != proposal.Proposer {
		// If the caller is not the proposer, check if the proposer's stake has fallen below the threshold
		enough, balance, wanted := checkEnoughXGnsToPropose(proposal.Proposer)
		if enough {
			panic(addDetailToError(
				errUnableToCancelProposalWithVoterEnoughDelegated,
				ufmt.Sprintf(
					"caller(%s) is not the proposer(%s) and proposer's xgns balance(%d) is above the threshold(%d)",
					caller, proposal.Proposer,
					balance, wanted,
				),
			))
		}
	}

	proposal.ExecutionState.Canceled = true
	proposal.ExecutionState.CanceledAt = now
	proposal.ExecutionState.Upcoming = false
	proposal.ExecutionState.Active = false

	proposals[proposalId] = proposal

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"Cancel",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"proposalId", ufmt.Sprintf("%d", proposalId),
	)
}
