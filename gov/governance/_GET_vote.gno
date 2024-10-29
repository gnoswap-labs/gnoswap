package governance

import (
	"std"

	"strconv"
	"strings"
)

func GetVoteByVoteKey(voteKey string) bool {
	vote, exist := votes[voteKey]
	if !exist {
		panic("VOTE_NOT_FOUND")
	}

	return vote
}

func GetVoteYesByVoteKey(voteKey string) bool {
	_, exist := votes[voteKey]
	if !exist {
		panic("VOTE_NOT_FOUND")
	}

	proposalId, address := divideVoteKeyToProposalIdAndUser(voteKey)

	vote, exist := userVotes[address][proposalId]
	if !exist {
		panic("VOTE_NOT_FOUND")
	}

	return vote.Yes
}

func GetVoteWeightByVoteKey(voteKey string) uint64 {
	_, exist := votes[voteKey]
	if !exist {
		panic("VOTE_NOT_FOUND")
	}

	proposalId, address := divideVoteKeyToProposalIdAndUser(voteKey)

	vote, exist := userVotes[address][proposalId]
	if !exist {
		panic("VOTE_NOT_FOUND")
	}

	return vote.Weight
}

func GetVotedHeightByVoteKey(voteKey string) uint64 {
	_, exist := votes[voteKey]
	if !exist {
		panic("VOTE_NOT_FOUND")
	}

	proposalId, address := divideVoteKeyToProposalIdAndUser(voteKey)

	vote, exist := userVotes[address][proposalId]
	if !exist {
		panic("VOTE_NOT_FOUND")
	}

	return vote.VotedHeight
}

func GetVotedAtByVoteKey(voteKey string) uint64 {
	_, exist := votes[voteKey]
	if !exist {
		panic("VOTE_NOT_FOUND")
	}

	proposalId, address := divideVoteKeyToProposalIdAndUser(voteKey)

	vote, exist := userVotes[address][proposalId]
	if !exist {
		panic("VOTE_NOT_FOUND")
	}

	return vote.VotedAt
}

func divideVoteKeyToProposalIdAndUser(voteKey string) (uint64, std.Address) {
	parts := strings.Split(voteKey, ":")
	if len(parts) != 2 {
		panic("INVALID_VOTE_KEY")
	}

	proposalId, err := strconv.ParseUint(parts[0], 10, 64)
	if err != nil {
		panic("INVALID_PROPOSAL_ID")
	}

	return proposalId, std.Address(parts[1])
}
