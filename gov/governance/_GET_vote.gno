package governance

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
)

func GetVoteByVoteKey(voteKey string) bool {
	vote, exist := votes[voteKey]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_vote.gno__GetVoteByVoteKey() || voteKey(%s) not found", voteKey),
		))
	}

	return vote
}

func GetVoteYesByVoteKey(voteKey string) bool {
	_, exist := votes[voteKey]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_vote.gno__GetVoteYesByVoteKey() || voteKey(%s) not found", voteKey),
		))
	}

	proposalId, address := divideVoteKeyToProposalIdAndUser(voteKey)

	vote, exist := userVotes[address][proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_vote.gno__GetVoteYesByVoteKey() || voteKey(%s) not found", voteKey),
		))
	}

	return vote.Yes
}

func GetVoteWeightByVoteKey(voteKey string) uint64 {
	_, exist := votes[voteKey]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_vote.gno__GetVoteWeightByVoteKey() || voteKey(%s) not found", voteKey),
		))
	}

	proposalId, address := divideVoteKeyToProposalIdAndUser(voteKey)

	vote, exist := userVotes[address][proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_vote.gno__GetVoteWeightByVoteKey() || voteKey(%s) not found", voteKey),
		))
	}

	return vote.Weight
}

func GetVotedHeightByVoteKey(voteKey string) uint64 {
	_, exist := votes[voteKey]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_vote.gno__GetVotedHeightByVoteKey() || voteKey(%s) not found", voteKey),
		))
	}

	proposalId, address := divideVoteKeyToProposalIdAndUser(voteKey)

	vote, exist := userVotes[address][proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_vote.gno__GetVotedHeightByVoteKey() || voteKey(%s) not found", voteKey),
		))
	}

	return vote.VotedHeight
}

func GetVotedAtByVoteKey(voteKey string) uint64 {
	_, exist := votes[voteKey]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_vote.gno__GetVotedAtByVoteKey() || voteKey(%s) not found", voteKey),
		))
	}

	proposalId, address := divideVoteKeyToProposalIdAndUser(voteKey)

	vote, exist := userVotes[address][proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_vote.gno__GetVotedAtByVoteKey() || voteKey(%s) not found", voteKey),
		))
	}

	return vote.VotedAt
}

func divideVoteKeyToProposalIdAndUser(voteKey string) (uint64, std.Address) {
	parts, err := common.Split(voteKey, ":", 2)
	if err != nil {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("_GET_vote.gno__divideVoteKeyToProposalIdAndUser() || voteKey(%s) is invalid", voteKey),
		))
	}

	proposalId, err := strconv.ParseUint(parts[0], 10, 64)
	if err != nil {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("_GET_vote.gno__divideVoteKeyToProposalIdAndUser() || proposalId(%s) is invalid", parts[0]),
		))
	}

	return proposalId, std.Address(parts[1])
}
