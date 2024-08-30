package governance

import (
	"fmt"
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	cp "gno.land/r/gnoswap/v2/community_pool"
	gs "gno.land/r/gnoswap/v2/gov/staker"

	"gno.land/r/gnoswap/v2/common"

	"gno.land/p/demo/ufmt"
)

var (
	votes = make(map[string]bool) // voteKey -> yes/no

	proposalId               uint64
	proposals                = make(map[uint64]ProposalInfo) // proposalId -> ProposalInfo
	latestProposalByProposer = make(map[string]uint64)       // proposer -> proposalId
)

// ProposeText creates a new text proposal with the given data
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Returns the proposal ID
func ProposeText(
	title string,
	description string,
) uint64 { // proposalId
	common.IsHalted()

	updateProposalsState()

	proposer := std.GetOrigCaller()
	checkExisitngProposal(proposer)

	avgDelegatedStr := gs.GetAverageDelegatedOverLast(proposer.String(), config.VotingWeightSmoothingDuration)
	avgDelegated := strToU256U64(avgDelegatedStr)
	if avgDelegated < config.ProposalCreationThreshold {
		panic(ufmt.Sprintf("THRESHOLD NOT MET: %d < %d", avgDelegated, config.ProposalCreationThreshold))
	}

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: "TEXT",
		ExecutionState: ExecutionState{
			Created:   true,
			CreatedAt: uint64(time.Now().Unix()),
			Upcoming:  true,
		},
		Yea:           u256.Zero(),
		Nay:           u256.Zero(),
		ConfigVersion: uint64(len(configVersions)), // use latest config version
		Title:         title,
		Description:   description,
	}

	proposalId++
	proposals[proposalId] = proposal
	latestProposalByProposer[proposer.String()] = proposalId

	std.Emit(
		"Proposed",
		"proposalType", "TEXT",
		"proposer", proposer.String(),
		"proposalId", ufmt.Sprintf("%d", proposalId),
		"title", title,
		"description", description,
	)

	return proposalId
}

// ProposeCommunityPoolSpend creates a new community pool spend proposal with the given data
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Returns the proposal ID
func ProposeCommunityPoolSpend(
	title string,
	description string,
	to std.Address,
	tokenPath string,
	amount uint64,
) uint64 { // proposalId
	common.IsHalted()

	updateProposalsState()

	proposer := std.GetOrigCaller()
	checkExisitngProposal(proposer)

	avgDelegatedStr := gs.GetAverageDelegatedOverLast(proposer.String(), config.VotingWeightSmoothingDuration)
	avgDelegated := strToU256U64(avgDelegatedStr)
	if avgDelegated < config.ProposalCreationThreshold {
		panic(ufmt.Sprintf("THRESHOLD NOT MET: %d < %d", avgDelegated, config.ProposalCreationThreshold))
	}

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: "COMMUNITY_POOL_SPEND",
		ExecutionState: ExecutionState{
			Created:   true,
			CreatedAt: uint64(time.Now().Unix()),
			Upcoming:  true,
		},
		Yea:           u256.Zero(),
		Nay:           u256.Zero(),
		ConfigVersion: uint64(len(configVersions)),
		Title:         title,
		Description:   description,
		CommunityPoolSpend: CommunityPoolSpendInfo{
			To:        to,
			TokenPath: tokenPath,
			Amount:    amount,
		},
	}

	proposalId++
	proposals[proposalId] = proposal
	latestProposalByProposer[proposer.String()] = proposalId

	std.Emit(
		"Proposed",
		"proposalType", "COMMUNITY_POOL_SPEND",
		"proposer", proposer.String(),
		"proposalId", ufmt.Sprintf("%d", proposalId),
		"title", title,
		"description", description,
		"to", to.String(),
		"tokenPath", tokenPath,
		"amount", fmt.Sprintf("%d", amount),
	)

	return proposalId
}

// ProposeParameterChange creates a new parameter change with the given data
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Returns the proposal ID
func ProposeParameterChange(
	title string,
	description string,
	pkgPath string,
	function string,
	param string,
) uint64 { // proposalId
	common.IsHalted()

	updateProposalsState()

	proposer := std.GetOrigCaller()
	checkExisitngProposal(proposer)

	avgDelegatedStr := gs.GetAverageDelegatedOverLast(proposer.String(), config.VotingWeightSmoothingDuration)
	avgDelegated := strToU256U64(avgDelegatedStr)
	if avgDelegated < config.ProposalCreationThreshold {
		panic(ufmt.Sprintf("THRESHOLD NOT MET: %d < %d", avgDelegated, config.ProposalCreationThreshold))
	}

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: "PARAMETER_CHANGE",
		ExecutionState: ExecutionState{
			Created:   true,
			CreatedAt: uint64(time.Now().Unix()),
			Upcoming:  true,
		},
		Yea:           u256.Zero(),
		Nay:           u256.Zero(),
		ConfigVersion: uint64(len(configVersions)),
		Title:         title,
		Description:   description,
		ParameterChange: ParameterChangeInfo{
			PkgPath:  pkgPath,
			Function: function,
			Params:   param,
		},
	}

	proposalId++
	proposals[proposalId] = proposal
	latestProposalByProposer[proposer.String()] = proposalId

	std.Emit(
		"Proposed",
		"proposalType", "PARAMETER_CHANGE",
		"proposer", proposer.String(),
		"proposalId", ufmt.Sprintf("%d", proposalId),
		"title", title,
		"description", description,
		"pkgPath", pkgPath,
		"function", function,
		"param", param,
	)

	return proposalId
}

// Vote allows a user to vote on a given proposal.
// The user's voting weight is determined by their average delegated stake over a specified period.
// Panics if the voting conditions are not met (e.g., voting period hasn't started, has ended, or user has already voted).
func Vote(proposalId uint64, yes bool) string {
	common.IsHalted()

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
	common.IsHalted()

	updateProposalsState()

	proposal, exist := proposals[proposalId]
	if !exist {
		panic(ufmt.Sprintf("proposal %d does not exist", proposalId))
	}

	if proposal.ExecutionState.Canceled {
		panic(ufmt.Sprintf("proposal %d has already canceled", proposalId))
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
func Execute(proposalId uint64) {
	common.IsHalted()

	updateProposalsState()

	proposal, exist := proposals[proposalId]
	if !exist {
		panic(ufmt.Sprintf("proposal %d does not exist. failed to execute", proposalId))
	}

	if proposal.ProposalType == "TEXT" {
		panic(ufmt.Sprintf("proposal %d is a TEXT proposal. not executable", proposalId))
	}

	if proposal.ExecutionState.Executed || proposal.ExecutionState.Canceled || proposal.ExecutionState.Rejected {
		panic(ufmt.Sprintf("proposal %d has already executed(%t) or canceled(%t) or rejected(%t). failed to execute", proposalId, proposal.ExecutionState.Executed, proposal.ExecutionState.Canceled, proposal.ExecutionState.Rejected))
	}

	if !proposal.ExecutionState.Passed {
		panic(ufmt.Sprintf("proposal %d has not passed. failed to execute", proposalId))
	}

	now := uint64(time.Now().Unix())

	config := GetConfigVersion(proposal.ConfigVersion)
	votingEnd := proposal.ExecutionState.CreatedAt + config.VotingStartDelay + config.VotingPeriod
	windowStart := votingEnd + config.ExecutionDelay
	if now < windowStart {
		panic(ufmt.Sprintf("EXECUTION_WINDOW_NOT_STARTED (now(%d) < windowStart(%d))", now, windowStart))
	}

	windowEnd := windowStart + config.ExecutionWindow
	if now >= windowEnd {
		panic(ufmt.Sprintf("EXECUTION_WINDOW_OVER (now(%d) >= windowEnd(%d))", now, windowEnd))
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

	if proposal.ProposalType == "COMMUNITY_POOL_SPEND" {
		// check if the token is registered to community pool
		registered := cp.GetRegisteredTokens()
		if !contains(registered, proposal.CommunityPoolSpend.TokenPath) {
			panic(ufmt.Sprintf("token %s is not registered to community pool", proposal.CommunityPoolSpend.TokenPath))
		}

		// trigger community pool spend
		cp.TransferToken(proposal.CommunityPoolSpend.TokenPath, proposal.CommunityPoolSpend.To, proposal.CommunityPoolSpend.Amount)
	}

	if proposal.ProposalType == "PARAMETER_CHANGE" {
		// trigger parameter change
		executeParameterChange(proposal.ParameterChange)
	}

	proposal.ExecutionState.Executed = true
	proposal.ExecutionState.ExecutedAt = now
	proposal.ExecutionState.Upcoming = false
	proposal.ExecutionState.Active = false
	proposals[proposalId] = proposal

	std.Emit(
		"Executed",
		"proposalId", ufmt.Sprintf("%d", proposalId),
		"executor", std.GetOrigCaller().String(),
	)
}

func checkExisitngProposal(proposer std.Address) {
	latestProposalId, exist := latestProposalByProposer[proposer.String()]
	if exist {
		latestProposal := proposals[latestProposalId]
		if latestProposal.ExecutionState.Upcoming || latestProposal.ExecutionState.Active {
			panic("PROPOSER_HAS_UPCOMING_OR_ACTIVE_PROPOSAL")
		}
	}
}

func updateProposalsState() {
	for id, proposal := range proposals {
		// check if proposal is in a state that needs to be updated
		// - created
		// - not canceled
		// - not executed
		if proposal.ExecutionState.Created &&
			!proposal.ExecutionState.Canceled &&
			!proposal.ExecutionState.Executed {

			config := GetConfigVersion(proposal.ConfigVersion)
			now := uint64(time.Now().Unix())

			// proposal is in voting period
			if proposal.ExecutionState.Upcoming && // was upcoming
				now >= (proposal.ExecutionState.CreatedAt+config.VotingStartDelay) && // voting started
				now <= (proposal.ExecutionState.CreatedAt+config.VotingStartDelay+config.VotingPeriod) { // voting not ended
				proposal.ExecutionState.Upcoming = false
				proposal.ExecutionState.Active = true
			}

			// proposal voting ended, check if passed or rejected
			if now > (proposal.ExecutionState.CreatedAt + config.VotingStartDelay + config.VotingPeriod) {
				yeaUint := proposal.Yea.Uint64()
				nayUint := proposal.Nay.Uint64()
				quorumUint := config.Quorum

				if yeaUint >= quorumUint && yeaUint > nayUint {
					proposal.ExecutionState.Passed = true
					proposal.ExecutionState.PassedAt = now
				} else {
					proposal.ExecutionState.Rejected = true
					proposal.ExecutionState.RejectedAt = now
				}

				proposal.ExecutionState.Active = false
			}

			// (non text) proposal passed but not executed until executing window ends
			if proposal.ProposalType != "TEXT" && // isn't text type ≈ can be executed
				proposal.ExecutionState.Passed && // passed
				!proposal.ExecutionState.Executed { // not executed

				votingEnd := proposal.ExecutionState.CreatedAt + config.VotingStartDelay + config.VotingPeriod
				windowStart := votingEnd + config.ExecutionDelay
				windowEnd := windowStart + config.ExecutionWindow

				if now >= windowEnd { // execution window ended
					proposal.ExecutionState.Expired = true
					proposal.ExecutionState.ExpiredAt = now
				}
			}

			proposals[id] = proposal
		}
	}
}
