package v1

import (
	"chain/runtime"
	"strconv"
	"strings"
	"time"

	"gno.land/p/onbloc/json"

	"gno.land/r/gnoswap/gov/governance"
)

// GetProposalById returns a single proposal with necessary information.
func (gv *governanceV1) GetProposalById(id int64) string {
	_, exists := gv.getProposal(id)
	if !exists {
		return ""
	}

	proposalsObj := metaNode()
	proposalArr := json.ArrayNode("", nil)

	proposalObj := gv.getProposalByIdHelper(id)
	proposalArr.AppendArray(proposalObj)
	proposalsObj.AppendObject("proposals", proposalArr)

	return marshal(proposalsObj)
}

// GetVoteStatusFromProposalById returns the vote status(max, yes, no) of a proposal.
func (gv *governanceV1) GetVoteStatusFromProposalById(id int64) string {
	_, exists := gv.getProposal(id)
	if !exists {
		return ""
	}

	votesObj := metaNode()
	votesObj.AppendObject("proposalId", json.StringNode("proposalId", formatInt(id)))
	votesObj.AppendObject("votes", json.StringNode("votes", b64Encode(gv.getProposalVotes(id)))) // max, yes, no

	return marshal(votesObj)
}

// GetVoteByAddressFromProposalById returns the vote of an address from a certain proposal.
func (gv *governanceV1) GetVoteByAddressFromProposalById(addr address, id int64) string {
	vote, exists := gv.getProposalUserVotingInfo(id, addr)
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

// getProposalByIdHelper is a helper function for GetProposals and GetProposalById.
func (gv *governanceV1) getProposalByIdHelper(id int64) *json.Node {
	proposal := gv.mustGetProposal(id)
	return gv.createProposalJsonNode(id, proposal)
}

// getProposalExtraData returns extra data of a proposal based on its type.
func (gv *governanceV1) getProposalExtraData(proposalId int64) string {
	proposal := gv.mustGetProposal(proposalId)

	switch proposal.Type() {
	case governance.Text:
		return ""
	case governance.CommunityPoolSpend:
		return gv.getCommunityPoolSpendProposalData(proposalId)
	case governance.ParameterChange:
		return gv.getParameterChangeProposalData(proposalId)
	}

	return ""
}

// getCommunityPoolSpendProposalData returns community pool spending proposal data including recipient address, token path, and amount.
func (gv *governanceV1) getCommunityPoolSpendProposalData(proposalId int64) string {
	proposal := gv.mustGetProposal(proposalId)
	spend := proposal.Data().CommunityPoolSpend()

	proposalObj := json.Builder().
		WriteString("to", spend.To().String()).
		WriteString("tokenPath", spend.TokenPath()).
		WriteString("amount", formatInt(spend.Amount())).
		Node()

	return marshal(proposalObj)
}

// getParameterChangeProposalData returns parameter change proposal data as a joined string of messages.
func (gv *governanceV1) getParameterChangeProposalData(proposalId int64) string {
	proposal := gv.mustGetProposal(proposalId)

	msgs := proposal.Data().Execution().Msgs()
	msgsStr := strings.Join(msgs, "*GOV*")

	return msgsStr
}

// getProposalStatus returns status of a proposal.
func (gv *governanceV1) getProposalStatus(id int64) string {
	proposal := gv.mustGetProposal(id)
	proposalResolver := NewProposalResolver(proposal)

	// Get current status dynamically
	status := proposalResolver.Status(time.Now().Unix())

	schedule := proposal.Status().Schedule()
	// Create status node with schedule and current status
	node := json.Builder().
		WriteString("status", status).
		WriteString("createTime", formatInt(schedule.CreateTime())).
		WriteString("activeTime", formatInt(schedule.ActiveTime())).
		WriteString("votingEndTime", formatInt(schedule.VotingEndTime())).
		WriteString("executableTime", formatInt(schedule.ExecutableTime())).
		WriteString("expiredTime", formatInt(schedule.ExpiredTime()))

	// Add action state if applicable
	if proposal.Status().ActionStatus().IsCanceled() {
		node.
			WriteString("canceled", formatBool(true)).
			WriteString("canceledAt", formatInt(proposal.Status().ActionStatus().CanceledAt())).
			WriteString("canceledBy", proposal.Status().ActionStatus().CanceledBy().String())
	}
	if proposal.Status().ActionStatus().IsExecuted() {
		node.
			WriteString("executed", formatBool(true)).
			WriteString("executedAt", formatInt(proposal.Status().ActionStatus().ExecutedAt())).
			WriteString("executedBy", proposal.Status().ActionStatus().ExecutedBy().String())
	}

	return marshal(node.Node())
}

// getProposalVotes returns votes of a proposal.
func (gv *governanceV1) getProposalVotes(id int64) string {
	proposal, exist := gv.getProposal(id)
	if !exist {
		return ""
	}
	voting := proposal.Status().VoteStatus()
	maxVoting := formatInt(voting.MaxVotingWeight())

	proposalObj := json.Builder().
		WriteString("quorum", formatInt(voting.QuorumAmount())).
		WriteString("max", maxVoting).
		WriteString("yes", formatInt(voting.YesWeight())).
		WriteString("no", formatInt(voting.NoWeight())).
		Node()

	return marshal(proposalObj)
}

func (gv *governanceV1) createProposalJsonNode(id int64, proposal *governance.Proposal) *json.Node {
	return json.Builder().
		WriteString("id", formatInt(id)).
		WriteString("configVersion", formatInt(proposal.ConfigVersion())).
		WriteString("proposer", proposal.Proposer().String()).
		WriteString("status", b64Encode(gv.getProposalStatus(id))).
		WriteString("type", proposal.Type().String()).
		WriteString("title", proposal.Title()).
		WriteString("description", proposal.Description()).
		WriteString("vote", b64Encode(gv.getProposalVotes(id))).
		WriteString("extra", b64Encode(gv.getProposalExtraData(id))).
		Node()
}

func createVoteJsonNode(addr address, id int64, vote *VotingInfo) *json.Node {
	return json.Builder().
		WriteString("proposalId", formatInt(id)).
		WriteString("voteYes", formatBool(vote.votedYes)).
		WriteString("voteWeight", formatInt(vote.votedWeight)).
		WriteString("voteHeight", formatInt(vote.votedHeight)).
		WriteString("voteTimestamp", formatInt(vote.votedAt)).
		Node()
}

func metaNode() *json.Node {
	height := runtime.ChainHeight()
	now := time.Now().Unix()

	return json.Builder().
		WriteString("height", strconv.FormatInt(height, 10)).
		WriteString("now", strconv.FormatInt(now, 10)).
		Node()
}

// marshal marshals a JSON node to a string.
func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}
