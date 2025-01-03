package governance

import (
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/json"

	en "gno.land/r/gnoswap/v1/emission"
)

func createProposalJsonNode(id uint64, proposal ProposalInfo) *json.Node {
	return json.Builder().
		WriteString("id", strconv.FormatUint(id, 10)).
		WriteString("configVersion", strconv.FormatUint(proposal.ConfigVersion, 10)).
		WriteString("proposer", proposal.Proposer.String()).
		WriteString("status", b64Encode(getProposalStatus(id))).
		WriteString("type", proposal.ProposalType.String()).
		WriteString("title", proposal.Title).
		WriteString("description", proposal.Description).
		WriteString("vote", b64Encode(getProposalVotes(id))).
		WriteString("extra", b64Encode(getProposalExtraData(id))).
		Node()
}

// GetProposals returns all proposals with necessary information.
func GetProposals() string {
	en.MintAndDistributeGns()
	updateProposalsState()

	if proposals.Size() == 0 {
		return ""
	}

	proposalsObj := metaNode()
	proposalArr := json.ArrayNode("", nil)

	proposals.Iterate("", "", func(key string, value interface{}) bool {
		proposalObj := getProposalById(proposalId)
		proposalArr.AppendArray(proposalObj)
		return true
	})

	proposalsObj.AppendObject("proposals", proposalArr)

	return marshal(proposalsObj)
}

// GetProposalById returns a single proposal with necessary information.
func GetProposalById(id uint64) string {
	en.MintAndDistributeGns()
	updateProposalsState()

	_, exists := proposals.Get(strconv.FormatUint(id, 10))
	if !exists {
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
	proposal := mustGetProposal(id)
	return createProposalJsonNode(id, proposal)
}

// GetVoteStatusFromProposalById returns the vote status(max, yes, no) of a proposal.
func GetVoteStatusFromProposalById(id uint64) string {
	en.MintAndDistributeGns()
	updateProposalsState()

	_, exists := proposals.Get(strconv.FormatUint(id, 10))
	if !exists {
		return ""
	}

	votesObj := metaNode()
	votesObj.AppendObject("proposalId", json.StringNode("proposalId", strconv.FormatUint(id, 10)))
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

	if _, exist := userVotes.Get(addr.String()); !exist {
		return ""
	}

	votesObj := metaNode()
	votesArr := json.ArrayNode("", nil)

	userVotes.Iterate(addr.String(), "", func(key string, value interface{}) bool {
		voteObj := createVoteJsonNode(addr, proposalId, value.(voteWithWeight))
		votesArr.AppendArray(voteObj)
		return true
	})
	votesObj.AppendObject("votes", votesArr)

	return marshal(votesObj)
}

// GetVoteByAddressFromProposalById returns the vote of an address from a certain proposal.
func GetVoteByAddressFromProposalById(addr std.Address, id uint64) string {
	en.MintAndDistributeGns()
	updateProposalsState()

	vote, exists := getUserVote(addr, id)
	if !exists {
		return ""
	}

	votesObj := metaNode()
	voteArr := json.ArrayNode("", nil)
	voteObj := createVoteJsonNode(addr, id, vote)
	voteArr.AppendArray(voteObj)
	votesObj.AppendObject("votes", voteArr)

	return marshal(votesObj)
}

func createVoteJsonNode(addr std.Address, id uint64, vote voteWithWeight) *json.Node {
	return json.Builder().
		WriteString("proposalId", strconv.FormatUint(id, 10)).
		WriteString("voteYes", strconv.FormatBool(vote.Yes)).
		WriteString("voteWeight", strconv.FormatUint(vote.Weight, 10)).
		WriteString("voteHeight", strconv.FormatUint(vote.VotedHeight, 10)).
		WriteString("voteTimestamp", strconv.FormatUint(vote.VotedAt, 10)).
		Node()
}

// getProposalExtraData returns the extra data of a proposal based on its type.
func getProposalExtraData(proposalId uint64) string {
	proposal, exist := proposals.Get(strconv.FormatUint(proposalId, 10))
	if !exist {
		return ""
	}

	switch proposal.(ProposalInfo).ProposalType {
	case Text:
		return ""
	case CommunityPoolSpend:
		return getCommunityPoolSpendProposalData(proposalId)
	case ParameterChange:
		return getParameterChangeProposalData(proposalId)
	}

	return ""
}

// community pool has three extra data
// 1. to
// 2. tokenPath
// 3. amount
func getCommunityPoolSpendProposalData(proposalId uint64) string {
	proposal := mustGetProposal(proposalId)

	proposalObj := json.Builder().
		WriteString("to", proposal.CommunityPoolSpend.To.String()).
		WriteString("tokenPath", proposal.CommunityPoolSpend.TokenPath).
		WriteString("amount", strconv.FormatUint(proposal.CommunityPoolSpend.Amount, 10)).
		Node()

	return marshal(proposalObj)
}

// parameter change proposal has three extra data
func getParameterChangeProposalData(proposalId uint64) string {
	proposal := mustGetProposal(proposalId)

	msgs := proposal.Execution.Msgs
	msgsStr := strings.Join(msgs, "*GOV*")

	return msgsStr
}

// getProposalStatus returns the status of a proposal.
func getProposalStatus(id uint64) string {
	prop, exist := proposals.Get(strconv.Itoa(int(id)))
	if !exist {
		return ""
	}

	proposal := prop.(ProposalInfo)
	config := GetConfigVersion(proposal.ConfigVersion)
	votingStart := proposal.State.CreatedAt + config.VotingStartDelay
	votingEnd := votingStart + config.VotingPeriod

	proposalObj := json.Builder().
		WriteString("CreatedAt", strconv.FormatUint(proposal.State.CreatedAt, 10)).
		WriteString("Upcoming", strconv.FormatBool(proposal.State.Upcoming)).
		WriteString("Active", strconv.FormatBool(proposal.State.Active)).
		WriteString("VotingStart", strconv.FormatUint(votingStart, 10)).
		WriteString("VotingEnd", strconv.FormatUint(votingEnd, 10)).
		WriteString("Passed", strconv.FormatBool(proposal.State.Passed)).
		WriteString("PassedAt", strconv.FormatUint(proposal.State.PassedAt, 10)).
		WriteString("Rejected", strconv.FormatBool(proposal.State.Rejected)).
		WriteString("RejectedAt", strconv.FormatUint(proposal.State.RejectedAt, 10)).
		WriteString("Canceled", strconv.FormatBool(proposal.State.Canceled)).
		WriteString("CanceledAt", strconv.FormatUint(proposal.State.CanceledAt, 10)).
		WriteString("Executed", strconv.FormatBool(proposal.State.Executed)).
		WriteString("ExecutedAt", strconv.FormatUint(proposal.State.ExecutedAt, 10)).
		WriteString("Expired", strconv.FormatBool(proposal.State.Expired)).
		WriteString("ExpiredAt", strconv.FormatUint(proposal.State.ExpiredAt, 10)).
		Node()

	return marshal(proposalObj)
}

// getProposalVotes returns the votes of a proposal.
func getProposalVotes(id uint64) string {
	prop, exist := proposals.Get(strconv.FormatUint(id, 10))
	if !exist {
		return ""
	}

	proposal := prop.(ProposalInfo)
	maxVoting := proposal.MaxVotingWeight.ToString()

	proposalObj := json.Builder().
		WriteString("quorum", strconv.FormatUint(proposal.QuorumAmount, 10)).
		WriteString("max", maxVoting).
		WriteString("yes", proposal.Yea.ToString()).
		WriteString("no", proposal.Nay.ToString()).
		Node()

	return marshal(proposalObj)
}

func metaNode() *json.Node {
	height := std.GetHeight()
	now := time.Now().Unix()

	return json.Builder().
		WriteString("height", strconv.FormatInt(height, 10)).
		WriteString("now", strconv.FormatInt(now, 10)).
		Node()
}
