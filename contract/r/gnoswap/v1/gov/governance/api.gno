package governance

import (
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/onbloc/json"
)

func createProposalJsonNode(id int64, proposal *Proposal) *json.Node {
	return json.Builder().
		WriteString("id", formatInt(id)).
		WriteString("configVersion", formatInt(proposal.ConfigVersion)).
		WriteString("proposer", proposal.Proposer().String()).
		WriteString("status", b64Encode(getProposalStatus(id))).
		WriteString("type", proposal.Type().String()).
		WriteString("title", proposal.Title()).
		WriteString("description", proposal.Description()).
		WriteString("vote", b64Encode(getProposalVotes(id))).
		WriteString("extra", b64Encode(getProposalExtraData(id))).
		Node()
}

// GetProposalById returns a single proposal with necessary information.
func GetProposalById(id int64) string {
	_, exists := getProposal(id)
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

// GetVoteStatusFromProposalById returns the vote status(max, yes, no) of a proposal.
func GetVoteStatusFromProposalById(id int64) string {
	_, exists := getProposal(id)
	if !exists {
		return ""
	}

	votesObj := metaNode()
	votesObj.AppendObject("proposalId", json.StringNode("proposalId", formatInt(id)))
	votesObj.AppendObject("votes", json.StringNode("votes", b64Encode(getProposalVotes(id)))) // max, yes, no

	return marshal(votesObj)
}

// GetVoteByAddressFromProposalById returns the vote of an address from a certain proposal.
func GetVoteByAddressFromProposalById(addr std.Address, id int64) string {
	vote, exists := getProposalUserVotingInfo(id, addr)
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

// getProposalById is a helper function for GetProposals and GetProposalById.
func getProposalById(id int64) *json.Node {
	proposal := mustGetProposal(id)
	return createProposalJsonNode(id, proposal)
}

func createVoteJsonNode(addr std.Address, id int64, vote *VotingInfo) *json.Node {
	return json.Builder().
		WriteString("proposalId", formatInt(id)).
		WriteString("voteYes", formatBool(vote.votedYes)).
		WriteString("voteWeight", formatInt(vote.votedWeight)).
		WriteString("voteHeight", formatInt(vote.votedHeight)).
		WriteString("voteTimestamp", formatInt(vote.votedAt)).
		Node()
}

// getProposalExtraData returns extra data of a proposal based on its type.
func getProposalExtraData(proposalId int64) string {
	proposal, exist := getProposal(proposalId)
	if !exist {
		return ""
	}

	switch proposal.Type() {
	case Text:
		return ""
	case CommunityPoolSpend:
		return getCommunityPoolSpendProposalData(proposalId)
	case ParameterChange:
		return getParameterChangeProposalData(proposalId)
	}

	return ""
}

// getCommunityPoolSpendProposalData returns community pool spending proposal data including recipient address, token path, and amount.
func getCommunityPoolSpendProposalData(proposalId int64) string {
	proposal := mustGetProposal(proposalId)
	spend := proposal.data.CommunityPoolSpend()

	proposalObj := json.Builder().
		WriteString("to", spend.to.String()).
		WriteString("tokenPath", spend.tokenPath).
		WriteString("amount", formatInt(spend.amount)).
		Node()

	return marshal(proposalObj)
}

// getParameterChangeProposalData returns parameter change proposal data as a joined string of messages.
func getParameterChangeProposalData(proposalId int64) string {
	proposal := mustGetProposal(proposalId)

	msgs := proposal.data.Execution().msgs
	msgsStr := strings.Join(msgs, "*GOV*")

	return msgsStr
}

// getProposalStatus returns status of a proposal.
func getProposalStatus(id int64) string {
	proposal, exist := getProposal(id)
	if !exist {
		return ""
	}

	// Get current status dynamically
	status := proposal.Status(time.Now().Unix())

	schedule := proposal.status.schedule
	// Create status node with schedule and current status
	node := json.Builder().
		WriteString("status", status).
		WriteString("createTime", formatInt(schedule.createTime)).
		WriteString("activeTime", formatInt(schedule.activeTime)).
		WriteString("votingEndTime", formatInt(schedule.votingEndTime)).
		WriteString("executableTime", formatInt(schedule.executableTime)).
		WriteString("expiredTime", formatInt(schedule.expiredTime))

	// Add action state if applicable
	if proposal.status.IsCanceled(time.Now().Unix()) {
		node.
			WriteString("canceled", formatBool(true)).
			WriteString("canceledAt", formatInt(proposal.status.actionStatus.canceledAt)).
			WriteString("canceledBy", proposal.status.actionStatus.canceledBy.String())
	}
	if proposal.status.IsExecuted(time.Now().Unix()) {
		node.
			WriteString("executed", formatBool(true)).
			WriteString("executedAt", formatInt(proposal.status.actionStatus.executedAt)).
			WriteString("executedBy", proposal.status.actionStatus.executedBy.String())
	}

	return marshal(node.Node())
}

// getProposalVotes returns votes of a proposal.
func getProposalVotes(id int64) string {
	proposal, exist := getProposal(id)
	if !exist {
		return ""
	}
	voting := proposal.status.voteStatus
	maxVoting := formatInt(voting.maxVotingWeight)

	proposalObj := json.Builder().
		WriteString("quorum", formatInt(voting.quorumAmount)).
		WriteString("max", maxVoting).
		WriteString("yes", formatInt(voting.yea)).
		WriteString("no", formatInt(voting.nay)).
		Node()

	return marshal(proposalObj)
}

func metaNode() *json.Node {
	height := std.ChainHeight()
	now := time.Now().Unix()

	return json.Builder().
		WriteString("height", strconv.FormatInt(height, 10)).
		WriteString("now", strconv.FormatInt(now, 10)).
		Node()
}
