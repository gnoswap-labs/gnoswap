package governance

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
)

// Helper function to validate and get vote information
func getVoteInfoFromKey(voteKey string) (voteWithWeight, bool) {
	_, exists := votes.Get(voteKey)
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("voteKey(%s) not found", voteKey),
		))
	}

	pid, addr := divideVoteKeyToProposalIdAndUser(voteKey)

	voteInfo, exists := getUserVote(addr, pid)
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("voteKey(%s) not found", voteKey),
		))
	}

	return voteInfo, true
}

func GetVoteByVoteKey(voteKey string) bool {
	vote, exist := votes.Get(voteKey)
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("voteKey(%s) not found", voteKey),
		))
	}

	return vote.(bool)
}

func GetVoteYesByVoteKey(voteKey string) bool {
	voteInfo, _ := getVoteInfoFromKey(voteKey)
	return voteInfo.Yes
}

func GetVoteWeightByVoteKey(voteKey string) uint64 {
	voteInfo, _ := getVoteInfoFromKey(voteKey)
	return voteInfo.Weight
}

func GetVotedHeightByVoteKey(voteKey string) uint64 {
	voteInfo, _ := getVoteInfoFromKey(voteKey)
	return voteInfo.VotedHeight
}

func GetVotedAtByVoteKey(voteKey string) uint64 {
	voteInfo, _ := getVoteInfoFromKey(voteKey)
	return voteInfo.VotedAt
}

func divideVoteKeyToProposalIdAndUser(voteKey string) (uint64, std.Address) {
	parts, err := common.Split(voteKey, ":", 2)
	if err != nil {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("voteKey(%s) is invalid", voteKey),
		))
	}

	proposalId, err := strconv.ParseUint(parts[0], 10, 64)
	if err != nil {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("proposalId(%s) is invalid", parts[0]),
		))
	}

	return proposalId, std.Address(parts[1])
}
