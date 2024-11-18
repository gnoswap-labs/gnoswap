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
func Vote(proposalId uint64, yes bool) string {
	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()

	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("vote.gno__Vote() || proposalId(%d) does not exist", proposalId),
		))
	}

	config := GetConfigVersion(proposal.ConfigVersion)
	now := uint64(time.Now().Unix())
	votingStartTime := proposal.ExecutionState.CreatedAt + config.VotingStartDelay

	voter := std.PrevRealm().Addr()

	if now < votingStartTime {
		panic(addDetailToError(
			errUnableToVoteBeforeStarting,
			ufmt.Sprintf("vote.gno__Vote() || voting has not started yet. now(%d) < votingStart(%d)", now, votingStartTime),
		))
	}

	votingEndTime := votingStartTime + config.VotingPeriod
	if now >= votingEndTime {
		panic(addDetailToError(
			errUnableToVoteAfterEnding,
			ufmt.Sprintf("vote.gno__Vote() || voting has ended. now(%d) >= votingEnd(%d)", now, votingEndTime),
		))
	}

	// check proposal state
	if proposal.ExecutionState.Canceled {
		panic(addDetailToError(
			errUnableToVoteCanceledProposal,
			ufmt.Sprintf("vote.gno__Vote() || proposalId(%d) has canceled(%t)", proposalId, proposal.ExecutionState.Canceled),
		))
	}

	voteKey := ufmt.Sprintf("%d", proposalId) + ":" + voter.String()
	_, voted := votes[voteKey]
	if voted {
		panic(addDetailToError(
			errAlreadyVoted,
			ufmt.Sprintf("vote.gno__Vote() || user(%s) has already voted on proposalId(%d)", voter.String(), proposalId),
		))
	}

	weight, exist := proposal.PossibleAddressWithWeight[voter]
	if !exist || weight == 0 {
		panic(addDetailToError(
			errNotEnoughVotingWeight,
			ufmt.Sprintf("vote.gno__Vote() || no voting weight found for voter(%s)", voter.String()),
		))
	}

	var overflow bool
	if yes {
		proposal.Yea, overflow = new(u256.Uint).AddOverflow(proposal.Yea, u256.NewUint(weight))
		if overflow {
			panic(addDetailToError(
				errOutOfRange,
				"vote.gno__Vote() || VOTE YES OVERFLOW",
			))
		}
	} else {
		proposal.Nay, overflow = new(u256.Uint).AddOverflow(proposal.Nay, u256.NewUint(weight))
		if overflow {
			panic(addDetailToError(
				errOutOfRange,
				"vote.gno__Vote() || VOTE NO OVERFLOW",
			))
		}
	}

	proposals[proposalId] = proposal // update Yea, Nay
	votes[voteKey] = yes

	if userVotes[voter] == nil {
		userVotes[voter] = make(map[uint64]voteWithWeight)
	}
	userVotes[voter][proposalId] = voteWithWeight{
		Yes:         yes,
		Weight:      weight,
		VotedHeight: uint64(std.GetHeight()),
		VotedAt:     now,
	}

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"Vote",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"proposalId", ufmt.Sprintf("%d", proposalId),
		"yes", voteToString(yes),
		"internal_weight", ufmt.Sprintf("%d", weight),
	)

	return voteKey
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
			ufmt.Sprintf("vote.gno__Cancel() || proposalId(%d) does not exist", proposalId),
		))
	}

	if proposal.ExecutionState.Canceled {
		panic(addDetailToError(
			errAlreadyCanceledProposal,
			ufmt.Sprintf("vote.gno__Cancel() || proposalId(%d) has already canceled", proposalId),
		))
	}

	config := GetConfigVersion(proposal.ConfigVersion)
	now := uint64(time.Now().Unix())
	if now >= (proposal.ExecutionState.CreatedAt + config.VotingStartDelay) {
		panic(addDetailToError(
			errUnableToCancleVotingProposal,
			ufmt.Sprintf("vote.gno__Cancel() || voting has already started for proposalId(%d)", proposalId),
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
