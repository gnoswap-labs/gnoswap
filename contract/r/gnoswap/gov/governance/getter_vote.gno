package governance

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
)

func GetVoteWeight(proposalID int64, address std.Address) int64 {
	proposalUserVotingInfo, ok := getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.VotedWeight()
}

func GetVotedHeight(proposalID int64, address std.Address) int64 {
	proposalUserVotingInfo, ok := getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.votedHeight
}

func GetVotedAt(proposalID int64, address std.Address) int64 {
	proposalUserVotingInfo, ok := getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.votedAt
}

func divideVoteKeyToProposalIdAndUser(voteKey string) (proposalId int64, user std.Address) {
	parts, err := common.Split(voteKey, ":", 2)
	if err != nil {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("voteKey(%s) is invalid", voteKey),
		))
	}
	
	return parseNumber(parts[0], kindInt64).(int64), std.Address(parts[1])
}
