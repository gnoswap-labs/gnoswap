package governance

import (
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"

	en "gno.land/r/gnoswap/v2/emission"
	gs "gno.land/r/gnoswap/v2/gov/staker"

	"gno.land/r/gnoswap/v2/common"

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
// The user's voting weight is determined by their average delegated stake over a specified period.
// Panics if the voting conditions are not met (e.g., voting period hasn't started, has ended, or user has already voted).
func Vote(proposalId uint64, yes bool) string {
	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()

	proposal, exist := proposals[proposalId]
	if !exist {
		panic(ufmt.Sprintf("Proposal %d does not exist", proposalId))
	}

	config := GetConfigVersion(proposal.ConfigVersion)
	now := uint64(time.Now().Unix())
	votingStartTime := proposal.ExecutionState.CreatedAt + config.VotingStartDelay

	voter := std.PrevRealm().Addr()

	if now < votingStartTime {
		panic(ufmt.Sprintf("voting has not started yet. Current time: %d, Voting start time: %d", now, votingStartTime))
	}

	votingEndTime := votingStartTime + config.VotingPeriod
	if now >= votingEndTime {
		panic(ufmt.Sprintf("voting has ended. Current time: %d, Voting end time: %d", now, votingStartTime+config.VotingPeriod))
	}

	// check proposal state
	if proposal.ExecutionState.Canceled {
		panic(ufmt.Sprintf("proposal %d has canceled(%t)", proposalId, proposal.ExecutionState.Canceled))
	}

	voteKey := ufmt.Sprintf("%d", proposalId) + ":" + voter.String()
	_, voted := votes[voteKey]
	if voted {
		panic(ufmt.Sprintf("user %s has already voted on proposal %d", voter.String(), proposalId))
	}

	weight := gs.GetDelegatedCumulative(
		voter,
		proposal.ExecutionState.CreatedAt-config.VotingWeightSmoothingDuration,
	)
	if weight == 0 {
		panic(ufmt.Sprintf("no average delegated found for voter %s", voter.String()))
	}

	var overflow bool
	if yes {
		proposal.Yea, overflow = new(u256.Uint).AddOverflow(proposal.Yea, u256.NewUint(weight))
		if overflow {
			panic("VOTE YES OVERFLOW")
		}
	} else {
		proposal.Nay, overflow = new(u256.Uint).AddOverflow(proposal.Nay, u256.NewUint(weight))
		if overflow {
			panic("VOTE NO OVERFLOW")
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
// Only callable by the proposer or if the proposer's stake has fallen below the threshold.
// Panics if the proposal doesn't exist, is already canceled, or if voting has already started.
func Cancel(proposalId uint64) {
	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()

	proposal, exist := proposals[proposalId]
	if !exist {
		panic(ufmt.Sprintf("proposal %d does not exist", proposalId))
	}

	if proposal.ExecutionState.Canceled {
		panic(ufmt.Sprintf("proposal %d has already canceled", proposalId))
	}

	config := GetConfigVersion(proposal.ConfigVersion)
	now := uint64(time.Now().Unix())
	if now >= (proposal.ExecutionState.CreatedAt + config.VotingStartDelay) {
		panic(ufmt.Sprintf("voting has already started for proposal %d", proposalId))
	}

	caller := std.PrevRealm().Addr()
	if caller != proposal.Proposer {
		// If the caller is not the proposer, check if the proposer's stake has fallen below the threshold
		enough := checkEnoughXGnsToPropose(proposal.Proposer)
		if enough {
			panic(
				ufmt.Sprintf(
					"caller %s is not the proposer(%s) and proposer's xgns balance is above the threshold",
					caller, proposal.Proposer,
				),
			)
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
