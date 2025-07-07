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
		WriteString("type", proposal.ProposalType.String()).
		WriteString("title", proposal.Title).
		WriteString("description", proposal.Description).
		WriteString("vote", b64Encode(getProposalVotes(id))).
		WriteString("extra", b64Encode(getProposalExtraData(id))).
		Node()
}

// GetProposals returns all proposals with necessary information.
func GetProposals() string {
	// Update proposal states before returning data
	transition := UpdateProposalStateTransition()
	if err := applyTransition(transition); err != nil {
		panic(err)
	}

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
}

// GetProposalById returns a single proposal with necessary information.
func GetProposalById(id uint64) string {
	// Update proposal states before returning data
	transition := UpdateProposalStateTransition()
	if err := applyTransition(transition); err != nil {
		panic(err)
	}

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
}

func GetArchivedProposalById(id uint64) string {
	// Update proposal states before returning data
	transition := UpdateProposalStateTransition()
	if err := applyTransition(transition); err != nil {
		panic(err)
	}

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
}

// GetVoteStatusFromProposalById returns the vote status(max, yes, no) of a proposal.
func GetVoteStatusFromProposalById(id uint64) string {
	// Update proposal states before returning data
	transition := UpdateProposalStateTransition()
	if err := applyTransition(transition); err != nil {
		panic(err)
	}

	_, exists := governanceState.GetProposal(id)
	if !exists {
		return ""
	}

	votesObj := metaNode()
	votesObj.AppendObject("proposalId", json.StringNode("proposalId", formatUint(id)))
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
	// Update proposal states before returning data
	transition := UpdateProposalStateTransition()
	if err := applyTransition(transition); err != nil {
		panic(err)
	}

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
}

// GetVoteByAddressFromProposalById returns the vote of an address from a certain proposal.
func GetVoteByAddressFromProposalById(addr std.Address, id uint64) string {
	// Update proposal states before returning data
	transition := UpdateProposalStateTransition()
	if err := applyTransition(transition); err != nil {
		panic(err)
	}

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

	switch proposal.ProposalType {
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
		WriteString("amount", formatUint(proposal.CommunityPoolSpend.Amount)).
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
	proposal, exist := governanceState.GetProposal(id)
	if !exist {
		return ""
	}

	// Get current status dynamically
	updater := newProposalStateUpdater(&proposal, uint64(time.Now().Unix()))
	status := updater.getCurrentStatus()

	// Create status node with schedule and current status
	node := json.Builder().
		WriteString("status", status.String()).
		WriteString("createTime", formatUint(proposal.Status.Schedule.CreateTime)).
		WriteString("activeTime", formatUint(proposal.Status.Schedule.ActiveTime)).
		WriteString("votingEndTime", formatUint(proposal.Status.Schedule.VotingEndTime)).
		WriteString("executableTime", formatUint(proposal.Status.Schedule.ExecutableTime)).
		WriteString("expiredTime", formatUint(proposal.Status.Schedule.ExpiredTime))

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

// func buildProposalStateFromStatus(proposal ProposalInfo) ProposalState {
// 	// Get current status dynamically
// 	updater := newProposalStateUpdater(&proposal, uint64(time.Now().Unix()))
// 	status := updater.getCurrentStatus()

// 	state := ProposalState{
// 		CreatedAt: proposal.Status.Schedule.CreateTime,
// 		Created: true, // All proposals are created
// 	}

// 	// Update state fields based on current status
// 	switch status {
// 	case StatusUpcoming:
// 		state.Upcoming = true
// 	case StatusActive:
// 		state.Active = true
// 	case StatusPassed:
// 		state.Passed = true
// 		// More accurate: passed at voting end time
// 		state.PassedAt = proposal.Status.Schedule.VotingEndTime
// 	case StatusRejected:
// 		state.Rejected = true
// 		// More accurate: rejected at voting end time 
// 		state.RejectedAt = proposal.Status.Schedule.VotingEndTime
// 	case StatusExpired:
// 		state.Expired = true
// 		state.ExpiredAt = proposal.Status.Schedule.ExpiredTime
// 		// Check if it was passed before expiring
// 		yeaVotes := proposal.Yea.Uint64()
// 		nayVotes := proposal.Nay.Uint64()
// 		if yeaVotes >= proposal.QuorumAmount && yeaVotes > nayVotes {
// 			state.Passed = true
// 			state.PassedAt = proposal.Status.Schedule.VotingEndTime
// 		}
// 	case StatusExecuted:
// 		state.Executed = true
// 		state.ExecutedAt = proposal.Status.ActionState.ExecutedAt
// 		state.Passed = true // Must have passed to be executed
// 		state.PassedAt = proposal.Status.Schedule.VotingEndTime
// 	case StatusCanceled:
// 		state.Canceled = true
// 		state.CanceledAt = proposal.Status.ActionState.CanceledAt
// 	}

// 	return state
// }

// func createProposalStateNode(state ProposalState, votingStart, votingEnd uint64) *json.Node {
// 	return json.Builder().
// 		WriteString("createdAt", formatUint(state.CreatedAt)).
// 		WriteString("upcoming", formatBool(state.Upcoming)).
// 		WriteString("active", formatBool(state.Active)).
// 		WriteString("votingStart", formatUint(votingStart)).
// 		WriteString("votingEnd", formatUint(votingEnd)).
// 		WriteString("passed", formatBool(state.Passed)).
// 		WriteString("passedAt", formatUint(state.PassedAt)).
// 		WriteString("rejected", formatBool(state.Rejected)).
// 		WriteString("rejectedAt", formatUint(state.RejectedAt)).
// 		WriteString("canceled", formatBool(state.Canceled)).
// 		WriteString("canceledAt", formatUint(state.CanceledAt)).
// 		WriteString("executed", formatBool(state.Executed)).
// 		WriteString("executedAt", formatUint(state.ExecutedAt)).
// 		WriteString("expired", formatBool(state.Expired)).
// 		WriteString("expiredAt", formatUint(state.ExpiredAt)).
// 		Node()
// }

// getProposalVotes returns the votes of a proposal.
func getProposalVotes(id uint64) string {
	proposal, exist := governanceState.GetProposal(id)
	if !exist {
		return ""
	}
	maxVoting := proposal.MaxVotingWeight.ToString()

	proposalObj := json.Builder().
		WriteString("quorum", formatUint(proposal.QuorumAmount)).
		WriteString("max", maxVoting).
		WriteString("yes", proposal.Yea.ToString()).
		WriteString("no", proposal.Nay.ToString()).
		Node()

	return marshal(proposalObj)
}

// // GetProposalStatusById returns the ProposalStatus directly
// func GetProposalStatusById(id uint64) string {
// 	// Update proposal states before returning data
// 	transition := UpdateProposalStateTransition()
// 	if err := applyTransition(transition); err != nil {
// 		panic(err)
// 	}

// 	proposal, exists := governanceState.GetProposal(id)
// 	if !exists {
// 		return ""
// 	}

// 	statusObj := metaNode()
// 	statusObj.AppendObject("status", createProposalStatusNode(proposal.Status))
// 	return marshal(statusObj)
// }

// // GetProposalScheduleById returns only the Schedule information
// func GetProposalScheduleById(id uint64) string {
// 	// Update proposal states before returning data
// 	transition := UpdateProposalStateTransition()
// 	if err := applyTransition(transition); err != nil {
// 		panic(err)
// 	}

// 	proposal, exists := governanceState.GetProposal(id)
// 	if !exists {
// 		return ""
// 	}

// 	scheduleObj := metaNode()
// 	scheduleObj.AppendObject("schedule", createProposalScheduleNode(proposal.Status.Schedule))
// 	return marshal(scheduleObj)
// }

// // GetProposalActionStateById returns only the ActionState information
// func GetProposalActionStateById(id uint64) string {
// 	// Update proposal states before returning data
// 	transition := UpdateProposalStateTransition()
// 	if err := applyTransition(transition); err != nil {
// 		panic(err)
// 	}

// 	proposal, exists := governanceState.GetProposal(id)
// 	if !exists {
// 		return ""
// 	}

// 	actionStateObj := metaNode()
// 	actionStateObj.AppendObject("actionState", createActionStateNode(proposal.Status.ActionState))
// 	return marshal(actionStateObj)
// }

// // Helper functions for new API endpoints
// func createProposalStatusNode(status ProposalStatus) *json.Node {
// 	return json.Builder().
// 		WriteObject("schedule", createProposalScheduleNode(status.Schedule)).
// 		WriteObject("actionState", createActionStateNode(status.ActionState)).
// 		Node()
// }

// func createProposalScheduleNode(schedule ProposalSchedule) *json.Node {
// 	return json.Builder().
// 		WriteString("createTime", formatUint(schedule.CreateTime)).
// 		WriteString("activeTime", formatUint(schedule.ActiveTime)).
// 		WriteString("votingEndTime", formatUint(schedule.VotingEndTime)).
// 		WriteString("executableTime", formatUint(schedule.ExecutableTime)).
// 		WriteString("expiredTime", formatUint(schedule.ExpiredTime)).
// 		Node()
// }

// func createActionStateNode(actionState ActionState) *json.Node {
// 	builder := json.Builder()
	
// 	if actionState.IsCanceled() {
// 		builder.
// 			WriteString("canceled", formatBool(true)).
// 			WriteString("canceledAt", formatUint(actionState.CanceledAt)).
// 			WriteString("canceledBy", actionState.CanceledBy.String())
// 	} else {
// 		builder.WriteString("canceled", formatBool(false))
// 	}
	
// 	if actionState.IsExecuted() {
// 		builder.
// 			WriteString("executed", formatBool(true)).
// 			WriteString("executedAt", formatUint(actionState.ExecutedAt)).
// 			WriteString("executedBy", actionState.ExecutedBy.String())
// 	} else {
// 		builder.WriteString("executed", formatBool(false))
// 	}
	
// 	return builder.Node()
// }

func metaNode() *json.Node {
	height := std.ChainHeight()
	now := time.Now().Unix()

	return json.Builder().
		WriteString("height", strconv.FormatInt(height, 10)).
		WriteString("now", strconv.FormatInt(now, 10)).
		Node()
}
