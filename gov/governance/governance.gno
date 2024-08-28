package governance

import (
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	gs "gno.land/r/gnoswap/v2/gov/staker"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

var (
	votes = make(map[string]bool) // voteKey -> yes/no

	proposalId               uint64
	proposals                = make(map[uint64]ProposalInfo) // proposalId -> ProposalInfo
	latestProposalByProposer = make(map[string]uint64)       // proposer -> proposalId
)

// Propose creates a new proposal with the given set of calls.
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Returns the proposal ID and an error if the proposal creation fails.
func Propose(
	proposalType string,
	title string,
	text string,
	msgToExecute string, // for proposalType == "COMMUNITY_POOL_SPEND" or "PARAMETER_CHANGE"
) uint64 { // proposalId
	updateProposalsState()

	checkProposalType(proposalType)
	if proposalType == "TEXT" && msgToExecute != "" {
		panic("TEXT_PROPOSAL_SHOULD_NOT_HAVE_MSG_TO_EXECUTE")
	}

	proposer := std.GetOrigCaller()
	proposalId++

	now := uint64(time.Now().Unix())

	latestProposalId, exist := latestProposalByProposer[proposer.String()]
	if exist {
		latestProposal := proposals[latestProposalId]
		if !latestProposal.ExecutionState.Canceled && !latestProposal.ExecutionState.Executed {
			if latestProposal.ExecutionState.CreatedAt+config.VotingStartDelay+config.VotingPeriod > now { // check end of voting period
				panic("PROPOSER_HAS_ACTIVE_PROPOSAL")
			}
		}
	}

	avgDelegatedStr := gs.GetAverageDelegatedOverLast(proposer.String(), config.VotingWeightSmoothingDuration)
	avgDelegated := strToU256U64(avgDelegatedStr)
	if avgDelegated < config.ProposalCreationThreshold {
		panic(ufmt.Sprintf("THRESHOLD NOT MET: %d < %d", avgDelegated, config.ProposalCreationThreshold))
	}

	proposal := ProposalInfo{
		Proposer: proposer,
		ExecutionState: ExecutionState{
			Created:   true,
			CreatedAt: now,
			Upcoming:  true,
		},
		Yea:           u256.Zero(),
		Nay:           u256.Zero(),
		ConfigVersion: uint64(len(configVersions)),
		Title:         title,
		Description:   text,
		ExecuteMsg:    msgToExecute,
	}

	proposals[proposalId] = proposal
	latestProposalByProposer[proposer.String()] = proposalId

	std.Emit(
		"Proposed",
		"proposalId", ufmt.Sprintf("%d", proposalId),
		"proposer", proposer.String(),
		"proposalType", proposalType,
		"title", title, // TODO: length
		"text", text, // TODO: length
		"msgToExecute", msgToExecute, // TODO: vulnerability
	)

	return proposalId
}

// Vote allows a user to vote on a given proposal.
// The user's voting weight is determined by their average delegated stake over a specified period.
// Panics if the voting conditions are not met (e.g., voting period hasn't started, has ended, or user has already voted).
func Vote(proposalId uint64, yes bool) string {
	updateProposalsState()

	proposal, exist := proposals[proposalId]
	if !exist {
		panic(ufmt.Sprintf("Proposal %d does not exist", proposalId))
	}

	config := GetConfigVersion(proposal.ConfigVersion)
	now := uint64(time.Now().Unix())
	votingStartTime := proposal.ExecutionState.CreatedAt + config.VotingStartDelay

	voter := std.GetOrigCaller()

	if now < votingStartTime {
		panic(ufmt.Sprintf("voting has not started yet. Current time: %d, Voting start time: %d", now, votingStartTime))
	}

	votingEndTime := votingStartTime + config.VotingPeriod
	if now >= votingEndTime {
		panic(ufmt.Sprintf("voting has ended. Current time: %d, Voting end time: %d", now, votingStartTime+config.VotingPeriod))
	}

	// check proposal state
	if proposal.ExecutionState.Canceled {
		panic(ufmt.Sprintf("proposal %d has canceled(%t)", proposalId, proposal.ExecutionState.Canceled))
	}

	voteKey := ufmt.Sprintf("%d", proposalId) + ":" + voter.String()
	_, voted := votes[voteKey]
	if voted {
		panic(ufmt.Sprintf("user %s has already voted on proposal %d", voter.String(), proposalId))
	}

	weight := gs.GetAverageDelegated(
		voter.String(),
		votingStartTime-config.VotingWeightSmoothingDuration,
		votingStartTime,
	)
	if weight == "0" {
		panic(ufmt.Sprintf("no average delegated found for voter %s", voter.String()))
	}

	var overflow bool
	if yes {
		proposal.Yea, overflow = new(u256.Uint).AddOverflow(proposal.Yea, u256.MustFromDecimal(weight))
		if overflow {
			panic("VOTE YES OVERFLOW")
		}
	} else {
		proposal.Nay, overflow = new(u256.Uint).AddOverflow(proposal.Nay, u256.MustFromDecimal(weight))
		if overflow {
			panic("VOTE NO OVERFLOW")
		}
	}

	proposals[proposalId] = proposal // update Yea, Nay
	votes[voteKey] = yes

	std.Emit(
		"Voted",
		"proposalId", ufmt.Sprintf("%d", proposalId),
		"voter", voter.String(),
		"weight", weight,
		"yes", voteToString(yes),
	)

	return voteKey
}

// Cancel cancels the proposal with the given ID.
// Only callable by the proposer or if the proposer's stake has fallen below the threshold.
// Panics if the proposal doesn't exist, is already canceled, or if voting has already started.
func Cancel(proposalId uint64) {
	updateProposalsState()

	proposal, exist := proposals[proposalId]
	if !exist {
		panic(ufmt.Sprintf("proposal %d does not exist", proposalId))
	}

	if proposal.ExecutionState.Canceled {
		panic(ufmt.Sprintf("proposal %d has already been canceled", proposalId))
	}

	config := GetConfigVersion(proposal.ConfigVersion)
	now := uint64(time.Now().Unix())
	if now >= (proposal.ExecutionState.CreatedAt + config.VotingStartDelay) {
		panic(ufmt.Sprintf("voting has already started for proposal %d", proposalId))
	}

	caller := std.GetOrigCaller()
	if caller != proposal.Proposer {
		// If the caller is not the proposer, check if the proposer's stake has fallen below the threshold
		avgDelegatedStr := gs.GetAverageDelegatedOverLast(proposal.Proposer.String(), config.VotingWeightSmoothingDuration)
		if avgDelegatedStr == "0" {
			panic(ufmt.Sprintf("no average delegated found for proposer %s", proposal.Proposer.String()))
		}

		if strToU256U64(avgDelegatedStr) >= config.ProposalCreationThreshold {
			panic(
				ufmt.Sprintf(
					"caller %s is not the proposer(%s) and proposer's stake(%s) is above the threshold(%d)",
					caller, proposal.Proposer, avgDelegatedStr, config.ProposalCreationThreshold,
				),
			)
		}
	}

	proposal.ExecutionState.Canceled = true
	proposal.ExecutionState.CanceledAt = now
	proposal.ExecutionState.Upcoming = false
	proposal.ExecutionState.Active = false

	proposals[proposalId] = proposal

	std.Emit(
		"Canceled",
		"proposalId", ufmt.Sprintf("%d", proposalId),
		"by", caller.String(),
	)
}

// Execute executes the given proposal.
// It checks various conditions such as voting period, execution window, quorum, and majority.
// Returns the results of the executed calls.
// Panics if any of the execution conditions are not met.
//
// XXX: Dynamic Call
func Execute(proposalId uint64, callsJSON string) {
	updateProposalsState()

	proposal, exist := proposals[proposalId]
	if !exist {
		panic(ufmt.Sprintf("proposal %d does not exist. failed to execute", proposalId))
	}

	if proposal.ExecutionState.Executed || proposal.ExecutionState.Canceled || proposal.ExecutionState.Rejected {
		panic(ufmt.Sprintf("proposal %d has already been executed(%t) or canceled(%t) or rejected(%t). failed to execute", proposalId, proposal.ExecutionState.Executed, proposal.ExecutionState.Canceled, proposal.ExecutionState.Rejected))
	}

	now := uint64(time.Now().Unix())

	config := GetConfigVersion(proposal.ConfigVersion)
	votingEnd := proposal.ExecutionState.CreatedAt + config.VotingStartDelay + config.VotingPeriod
	if now < votingEnd {
		panic("VOTING_NOT_ENDED")
	}

	windowStart := votingEnd + config.ExecutionDelay
	if now < windowStart {
		panic("EXECUTION_WINDOW_NOT_STARTED")
	}

	windowEnd := windowStart + config.ExecutionWindow
	if now >= windowEnd {
		panic("EXECUTION_WINDOW_OVER")
	}

	yeaUint := proposal.Yea.Uint64()
	nayUint := proposal.Nay.Uint64()
	quorumUint := config.Quorum

	if yeaUint < quorumUint {
		panic("QUORUM_NOT_MET")
	}

	if yeaUint < nayUint {
		panic("NO_MAJORITY")
	}

	proposal.ExecutionState.Executed = true
	proposal.ExecutionState.ExecutedAt = now
	proposal.ExecutionState.Upcoming = false
	proposal.ExecutionState.Active = false
	proposals[proposalId] = proposal

	calls := parseCallsFromJSON(json.Must(json.Unmarshal([]byte(callsJSON))))

	results := make([]string, 0, len(calls))
	for _, call := range calls {
		result := executeCall(call)
		results = append(results, result)
	}

	std.Emit(
		"Executed",
		"proposalId", ufmt.Sprintf("%d", proposalId),
		"executor", std.GetOrigCaller().String(),
	)
}

func updateProposalsState() {
	// TODO: update proposals state
}
