package governance

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	gs "gno.land/r/gnoswap/v2/gov/staker"

	en "gno.land/r/gnoswap/v2/emission"
)

// GetProposals returns all proposals with necessary information.
func GetProposals() string {
	en.MintAndDistributeGns()
	updateProposalsState()

	if len(proposals) == 0 {
		return ""
	}

	proposalsObj := metaNode()
	proposalArr := json.ArrayNode("", nil)
	for proposalId, _ := range proposals {
		proposalObj := getProposalById(proposalId)
		proposalArr.AppendArray(proposalObj)
	}
	proposalsObj.AppendObject("proposals", proposalArr)

	return marshal(proposalsObj)
}

// GetProposalById returns a single proposal with necessary information.
func GetProposalById(id uint64) string {
	en.MintAndDistributeGns()
	updateProposalsState()

	_, exist := proposals[id]
	if !exist {
		return ""
	}

	proposalsObj := metaNode()
	proposalArr := json.ArrayNode("", nil)
	proposalObj := getProposalById(id)
	proposalArr.AppendArray(proposalObj)
	proposalsObj.AppendObject("proposals", proposalArr)

	return marshal(proposalsObj)
}

// helper function for GetProposals and GetProposalById
func getProposalById(id uint64) *json.Node {
	proposal, exist := proposals[id]
	if !exist {
		return nil
	}

	proposalObj := json.ObjectNode("", nil)
	proposalObj.AppendObject("id", json.StringNode("id", ufmt.Sprintf("%d", id)))
	proposalObj.AppendObject("configVersion", json.StringNode("configVersion", ufmt.Sprintf("%d", proposal.ConfigVersion)))
	proposalObj.AppendObject("proposer", json.StringNode("proposer", proposal.Proposer.String()))
	proposalObj.AppendObject("status", json.StringNode("status", b64Encode(getProposalStatus(id))))
	proposalObj.AppendObject("type", json.StringNode("type", proposal.ProposalType))
	proposalObj.AppendObject("title", json.StringNode("title", proposal.Title))
	proposalObj.AppendObject("description", json.StringNode("description", proposal.Description))
	proposalObj.AppendObject("vote", json.StringNode("vote", b64Encode(getProposalVotes(id))))
	proposalObj.AppendObject("extra", json.StringNode("extra", b64Encode(getProposalExtraData(id))))

	return proposalObj
}

// GetVoteStatusFromProposalById returns the vote status(max, yes, no) of a proposal.
func GetVoteStatusFromProposalById(id uint64) string {
	en.MintAndDistributeGns()
	updateProposalsState()

	_, exist := proposals[id]
	if !exist {
		return ""
	}

	votesObj := metaNode()
	votesObj.AppendObject("proposalId", json.StringNode("proposalId", ufmt.Sprintf("%d", id)))
	votesObj.AppendObject("votes", json.StringNode("votes", b64Encode(getProposalVotes(id)))) // max, yes, no

	return marshal(votesObj)
}

// GetVotesByAddress returns all votes of an address.
// included information:
// - proposalId
// - vote (yes/no)
// - weight
// - height
// - timestamp
func GetVotesByAddress(addr std.Address) string {
	en.MintAndDistributeGns()
	updateProposalsState()

	if _, exist := userVotes[addr]; !exist {
		return ""
	}

	votesObj := metaNode()

	votesArr := json.ArrayNode("", nil)
	for proposalId, _ := range userVotes[addr] {
		voteObj := getVoteByAddressFromProposalById(addr, proposalId)
		votesArr.AppendArray(voteObj)
	}
	votesObj.AppendObject("votes", votesArr)

	return marshal(votesObj)
}

// GetVoteByAddressFromProposalById returns the vote of an address from a certain proposal.
func GetVoteByAddressFromProposalById(addr std.Address, id uint64) string {
	en.MintAndDistributeGns()
	updateProposalsState()

	if _, exist := userVotes[addr]; !exist {
		return ""
	}

	if _, exist := userVotes[addr][id]; !exist {
		return ""
	}

	votesObj := metaNode()
	voteArr := json.ArrayNode("", nil)
	voteObj := getVoteByAddressFromProposalById(addr, id)
	voteArr.AppendArray(voteObj)
	votesObj.AppendObject("votes", voteArr)

	return marshal(votesObj)
}

// helper function for GetVotesByAddress and GetVoteByAddressFromProposalById
func getVoteByAddressFromProposalById(addr std.Address, id uint64) *json.Node {
	if _, exist := userVotes[addr]; !exist {
		return nil
	}

	if _, exist := userVotes[addr][id]; !exist {
		return nil
	}

	voteObj := json.ObjectNode("", nil)
	voteObj.AppendObject("proposalId", json.StringNode("proposalId", ufmt.Sprintf("%d", id)))
	voteObj.AppendObject("voteYes", json.StringNode("yes", ufmt.Sprintf("%t", userVotes[addr][id].Yes)))
	voteObj.AppendObject("voteWeight", json.StringNode("weight", ufmt.Sprintf("%d", userVotes[addr][id].Weight)))
	voteObj.AppendObject("voteHeight", json.StringNode("height", ufmt.Sprintf("%d", userVotes[addr][id].VotedHeight)))
	voteObj.AppendObject("voteTimestamp", json.StringNode("timestamp", ufmt.Sprintf("%d", userVotes[addr][id].VotedAt)))

	return voteObj
}

// getProposalExtraData returns the extra data of a proposal based on its type.
func getProposalExtraData(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		return ""
	}

	switch proposal.ProposalType {
	case "TEXT":
		return ""
	case "COMMUNITY_POOL_SPEND":
		return getCommunityPoolSpendProposalData(proposalId)
	case "PARAMETER_CHANGE":
		return getParameterChangeProposalData(proposalId)
	}

	return ""
}

// community pool has three extra data
// 1. to
// 2. tokenPath
// 3. amount
func getCommunityPoolSpendProposalData(proposalId uint64) string {
	proposal := proposals[proposalId]

	proposalObj := json.ObjectNode("", nil)
	proposalObj.AppendObject("to", json.StringNode("to", proposal.CommunityPoolSpend.To.String()))
	proposalObj.AppendObject("tokenPath", json.StringNode("tokenPath", proposal.CommunityPoolSpend.TokenPath))
	proposalObj.AppendObject("amount", json.StringNode("amount", ufmt.Sprintf("%d", proposal.CommunityPoolSpend.Amount)))

	return marshal(proposalObj)
}

// parameter change proposal has three extra data
func getParameterChangeProposalData(proposalId uint64) string {
	proposal := proposals[proposalId]

	msgs := proposal.Execution.Msgs
	msgsStr := strings.Join(msgs, "*GOV*")

	return msgsStr
}

// getProposalStatus returns the status of a proposal.
func getProposalStatus(id uint64) string {
	proposal, exist := proposals[id]
	if !exist {
		return ""
	}

	proposalObj := json.ObjectNode("", nil)
	proposalObj.AppendObject("CreatedAt", json.StringNode("CreatedAt", ufmt.Sprintf("%d", proposal.ExecutionState.CreatedAt)))
	proposalObj.AppendObject("Upcoming", json.StringNode("Upcoming", ufmt.Sprintf("%t", proposal.ExecutionState.Upcoming)))
	proposalObj.AppendObject("Active", json.StringNode("Active", ufmt.Sprintf("%t", proposal.ExecutionState.Active)))

	config := GetConfigVersion(proposal.ConfigVersion)
	votingStart := proposal.ExecutionState.CreatedAt + config.VotingStartDelay
	votingEnd := votingStart + config.VotingPeriod

	proposalObj.AppendObject("VotingStart", json.StringNode("VotingStart", ufmt.Sprintf("%d", votingStart)))
	proposalObj.AppendObject("VotingEnd", json.StringNode("VotingEnd", ufmt.Sprintf("%d", votingEnd)))

	proposalObj.AppendObject("Passed", json.StringNode("Passed", ufmt.Sprintf("%t", proposal.ExecutionState.Passed)))
	proposalObj.AppendObject("PassedAt", json.StringNode("PassedAt", ufmt.Sprintf("%d", proposal.ExecutionState.PassedAt)))

	proposalObj.AppendObject("Rejected", json.StringNode("Rejected", ufmt.Sprintf("%t", proposal.ExecutionState.Rejected)))
	proposalObj.AppendObject("RejectedAt", json.StringNode("RejectedAt", ufmt.Sprintf("%d", proposal.ExecutionState.RejectedAt)))

	proposalObj.AppendObject("Canceled", json.StringNode("Canceled", ufmt.Sprintf("%t", proposal.ExecutionState.Canceled)))
	proposalObj.AppendObject("CanceledAt", json.StringNode("CanceledAt", ufmt.Sprintf("%d", proposal.ExecutionState.CanceledAt)))

	proposalObj.AppendObject("Executed", json.StringNode("Executed", ufmt.Sprintf("%t", proposal.ExecutionState.Executed)))
	proposalObj.AppendObject("ExecutedAt", json.StringNode("ExecutedAt", ufmt.Sprintf("%d", proposal.ExecutionState.ExecutedAt)))

	proposalObj.AppendObject("Expired", json.StringNode("Expired", ufmt.Sprintf("%t", proposal.ExecutionState.Expired)))
	proposalObj.AppendObject("ExpiredAt", json.StringNode("ExpiredAt", ufmt.Sprintf("%d", proposal.ExecutionState.ExpiredAt)))

	return marshal(proposalObj)
}

// getProposalVotes returns the votes of a proposal.
func getProposalVotes(id uint64) string {
	proposal, exist := proposals[id]
	if !exist {
		return ""
	}

	proposalObj := json.ObjectNode("", nil)

	config := GetConfigVersion(proposal.ConfigVersion)
	weightUntilTimestamp := proposal.ExecutionState.CreatedAt - config.VotingWeightSmoothingDuration

	max := gs.GetTotalDelegatedUntil(weightUntilTimestamp)

	proposalObj.AppendObject("quorum", json.StringNode("quorum", ufmt.Sprintf("%d", proposal.QuorumAmount)))
	proposalObj.AppendObject("max", json.StringNode("max", ufmt.Sprintf("%d", max)))
	proposalObj.AppendObject("yes", json.StringNode("yes", proposal.Yea.ToString()))
	proposalObj.AppendObject("no", json.StringNode("no", proposal.Nay.ToString()))

	return marshal(proposalObj)
}

func metaNode() *json.Node {
	height := std.GetHeight()
	now := time.Now().Unix()

	metaObj := json.ObjectNode("", nil)
	metaObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", height)))
	metaObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", now)))
	return metaObj
}
