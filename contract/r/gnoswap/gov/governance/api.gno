package governance

import (
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/json"
)

func createProposalJsonNode(id uint64, proposal ProposalInfo) *json.Node {
	return json.Builder().
		WriteString("id", formatUint(id)).
		WriteString("configVersion", formatUint(proposal.ConfigVersion)).
		WriteString("proposer", proposal.Proposer.String()).
		WriteString("status", b64Encode(getProposalStatus(id))).
		WriteString("type", proposal.Data.ProposalType.String()).
		WriteString("title", proposal.Metadata.Title).
		WriteString("description", proposal.Metadata.Description).
		WriteString("vote", b64Encode(getProposalVotes(id))).
		WriteString("extra", b64Encode(getProposalExtraData(id))).
		Node()
}

// GetProposals returns all proposals with necessary information.
func GetProposals() string {
	return withStateUpdate(func() string {
		proposalsObj := metaNode()
		proposalArr := json.ArrayNode("", nil)

		// Iterate through all proposals in state
		governanceState.IterateProposals(func(id uint64, proposal ProposalInfo) bool {
			proposalObj := getProposalById(id)
			proposalArr.AppendArray(proposalObj)
			return false
		})

		proposalsObj.AppendObject("proposals", proposalArr)

		return marshal(proposalsObj)
	})
}

// GetProposalById returns a single proposal with necessary information.
func GetProposalById(id uint64) string {
	return withStateUpdate(func() string {
		_, exists := governanceState.GetProposal(id)
		if !exists {
			return ""
		}

		proposalsObj := metaNode()
		proposalArr := json.ArrayNode("", nil)
		proposalObj := getProposalById(id)
		proposalArr.AppendArray(proposalObj)
		proposalsObj.AppendObject("proposals", proposalArr)

		return marshal(proposalsObj)
	})
}

func GetArchivedProposalById(id uint64) string {
	return withStateUpdate(func() string {
		_, exists := governanceState.GetArchivedProposal(id)
		if !exists {
			return ""
		}

		proposalsObj := metaNode()
		proposalArr := json.ArrayNode("", nil)
		proposalObj := getProposalById(id)
		proposalArr.AppendArray(proposalObj)
		proposalsObj.AppendObject("proposals", proposalArr)

		return marshal(proposalsObj)
	})
}

// GetVoteStatusFromProposalById returns the vote status(max, yes, no) of a proposal.
func GetVoteStatusFromProposalById(id uint64) string {
	return withStateUpdate(func() string {
		_, exists := governanceState.GetProposal(id)
		if !exists {
			return ""
		}

		votesObj := metaNode()
		votesObj.AppendObject("proposalId", json.StringNode("proposalId", formatUint(id)))
		votesObj.AppendObject("votes", json.StringNode("votes", b64Encode(getProposalVotes(id)))) // max, yes, no

		return marshal(votesObj)
	})
}

// GetVotesByAddress returns all votes of an address.
// included information:
// - proposalId
// - vote (yes/no)
// - weight
// - height
// - timestamp
func GetVotesByAddress(addr std.Address) string {
	return withStateUpdate(func() string {
		votesObj := metaNode()
		votesArr := json.ArrayNode("", nil)

		// Iterate through all user votes for the given address
		governanceState.IterateUserVotes(addr, func(proposalId uint64, vote voteWithWeight) bool {
			voteObj := createVoteJsonNode(addr, proposalId, vote)
			votesArr.AppendArray(voteObj)
			return false
		})
		votesObj.AppendObject("votes", votesArr)

		return marshal(votesObj)
	})
}

// GetVoteByAddressFromProposalById returns the vote of an address from a certain proposal.
func GetVoteByAddressFromProposalById(addr std.Address, id uint64) string {
	return withStateUpdate(func() string {
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
	})
}

// helper function for GetProposals and GetProposalById
func getProposalById(id uint64) *json.Node {
	proposal := mustGetProposal(id)
	return createProposalJsonNode(id, proposal)
}

func createVoteJsonNode(addr std.Address, id uint64, vote voteWithWeight) *json.Node {
	return json.Builder().
		WriteString("proposalId", formatUint(id)).
		WriteString("voteYes", formatBool(vote.Yes)).
		WriteString("voteWeight", formatUint(vote.Weight)).
		WriteString("voteHeight", formatUint(vote.VotedHeight)).
		WriteString("voteTimestamp", formatUint(vote.VotedAt)).
		Node()
}

// getProposalExtraData returns the extra data of a proposal based on its type.
func getProposalExtraData(proposalId uint64) string {
	proposal, exist := governanceState.GetProposal(proposalId)
	if !exist {
		return ""
	}

	switch proposal.Data.ProposalType {
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
	spend := proposal.Data.CommunityPoolSpend

	proposalObj := json.Builder().
		WriteString("to", spend.To.String()).
		WriteString("tokenPath", spend.TokenPath).
		WriteString("amount", formatUint(spend.Amount)).
		Node()

	return marshal(proposalObj)
}

// parameter change proposal has three extra data
func getParameterChangeProposalData(proposalId uint64) string {
	proposal := mustGetProposal(proposalId)

	msgs := proposal.Data.Execution.Msgs
	msgsStr := strings.Join(msgs, "*GOV*")

	return msgsStr
}

// getProposalStatus returns the status of a proposal.
func getProposalStatus(id uint64) string {
	proposal, exist := governanceState.GetProposal(id)
	if !exist {
		return ""
	}

	// Get current status dynamically
	updater := newProposalStateUpdater(&proposal, uint64(time.Now().Unix()))
	status := updater.getCurrentStatus()

	schedule := proposal.Status.Schedule
	// Create status node with schedule and current status
	node := json.Builder().
		WriteString("status", status.String()).
		WriteString("createTime", formatUint(schedule.CreateTime)).
		WriteString("activeTime", formatUint(schedule.ActiveTime)).
		WriteString("votingEndTime", formatUint(schedule.VotingEndTime)).
		WriteString("executableTime", formatUint(schedule.ExecutableTime)).
		WriteString("expiredTime", formatUint(schedule.ExpiredTime))

	// Add action state if applicable
	if proposal.Status.ActionState.IsCanceled() {
		node.
			WriteString("canceled", formatBool(true)).
			WriteString("canceledAt", formatUint(proposal.Status.ActionState.CanceledAt)).
			WriteString("canceledBy", proposal.Status.ActionState.CanceledBy.String())
	}
	if proposal.Status.ActionState.IsExecuted() {
		node.
			WriteString("executed", formatBool(true)).
			WriteString("executedAt", formatUint(proposal.Status.ActionState.ExecutedAt)).
			WriteString("executedBy", proposal.Status.ActionState.ExecutedBy.String())
	}

	return marshal(node.Node())
}

// getProposalVotes returns the votes of a proposal.
func getProposalVotes(id uint64) string {
	proposal, exist := governanceState.GetProposal(id)
	if !exist {
		return ""
	}
	voting := proposal.Voting
	maxVoting := voting.MaxVotingWeight.ToString()

	proposalObj := json.Builder().
		WriteString("quorum", formatUint(voting.QuorumAmount)).
		WriteString("max", maxVoting).
		WriteString("yes", voting.Yea.ToString()).
		WriteString("no", voting.Nay.ToString()).
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
