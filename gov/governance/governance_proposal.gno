package governance

import (
	"std"
	"strings"
	"time"

	u256 "gno.land/p/gnoswap/uint256"

	cp "gno.land/r/gnoswap/v2/community_pool"
	en "gno.land/r/gnoswap/v2/emission"
	gs "gno.land/r/gnoswap/v2/gov/staker"

	"gno.land/r/gnoswap/v2/gov/xgns"

	"gno.land/r/gnoswap/v2/common"

	"gno.land/p/demo/ufmt"
)

type voteWithWeight struct {
	Yes         bool
	Weight      uint64
	VotedHeight uint64
	VotedAt     uint64
}

var (
	votes     = make(map[string]bool)                      // voteKey(proposalId:user) -> yes/no
	userVotes = make(map[string]map[uint64]voteWithWeight) // user -> proposalId -> voteWithWeight

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

	en.MintAndDistributeGns()
	updateProposalsState()

	proposer := std.GetOrigCaller()

	enough := checkEnoughXGnsToPropose(proposer)
	if !enough {
		panic("PROPOSER_HAS_NOT_ENOUGH_XGNS")
	}

	now := uint64(time.Now().Unix())
	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: "TEXT",
		ExecutionState: ExecutionState{
			Created:   true,
			CreatedAt: now,
			Upcoming:  true,
		},
		Yea:           u256.Zero(),
		Nay:           u256.Zero(),
		ConfigVersion: uint64(len(configVersions)), // use latest config version
		QuorumAmount:  xgns.VotingSupply() * config.Quorum / 100,
		Title:         title,
		Description:   description,
	}

	proposalId++
	proposals[proposalId] = proposal
	latestProposalByProposer[proposer.String()] = proposalId

	std.Emit(
		"Proposed",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_title", title,
		"p_description", description,
		"proposalType", "TEXT",
		"proposer", proposer.String(),
		"proposalId", ufmt.Sprintf("%d", proposalId),
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

	en.MintAndDistributeGns()
	updateProposalsState()

	proposer := std.GetOrigCaller()

	enough := checkEnoughXGnsToPropose(proposer)
	if !enough {
		panic("PROPOSER_HAS_NOT_ENOUGH_XGNS")
	}

	now := uint64(time.Now().Unix())
	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: "COMMUNITY_POOL_SPEND",
		ExecutionState: ExecutionState{
			Created:   true,
			CreatedAt: now,
			Upcoming:  true,
		},
		Yea:           u256.Zero(),
		Nay:           u256.Zero(),
		ConfigVersion: uint64(len(configVersions)),
		QuorumAmount:  xgns.VotingSupply() * config.Quorum / 100,
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
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_title", title,
		"p_description", description,
		"p_to", to.String(),
		"p_tokenPath", tokenPath,
		"p_amount", ufmt.Sprintf("%d", amount),
		"proposalType", "COMMUNITY_POOL_SPEND",
		"proposer", proposer.String(),
		"proposalId", ufmt.Sprintf("%d", proposalId),
	)

	return proposalId
}

// ProposeParameterChange creates a new parameter change with the given data
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Returns the proposal ID
func ProposeParameterChange(
	title string,
	description string,
	numToExecute uint64,
	executions string,
) uint64 { // proposalId
	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()

	proposer := std.GetOrigCaller()

	enough := checkEnoughXGnsToPropose(proposer)
	if !enough {
		panic("PROPOSER_HAS_NOT_ENOUGH_XGNS")
	}

	if numToExecute == 0 {
		panic("numToExecute is 0")
	}

	// check if numToExecute is a valid number
	splitGov := strings.Split(executions, "*GOV*")
	if uint64(len(splitGov)) != numToExecute {
		panic(ufmt.Sprintf("numToExecute(%d) does not match the number of executions(%d)", numToExecute, len(splitGov)))
	}

	// check if each execution is valid
	for _, gov := range splitGov {
		splitExe := strings.Split(gov, "*EXE*")
		if len(splitExe) != 3 {
			panic(ufmt.Sprintf("invalid execution(%s) to split by *EXE*, seems like param didn't passed", gov))
		}

		pkgPath := splitExe[0]
		funcName := splitExe[1]
		params := splitExe[2]

		// check if msg is callable
		callableMsg(pkgPath, funcName, params)
	}

	now := uint64(time.Now().Unix())
	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: "PARAMETER_CHANGE",
		ExecutionState: ExecutionState{
			Created:   true,
			CreatedAt: now,
			Upcoming:  true,
		},
		Yea:           u256.Zero(),
		Nay:           u256.Zero(),
		ConfigVersion: uint64(len(configVersions)),
		QuorumAmount:  xgns.VotingSupply() * config.Quorum / 100,
		Title:         title,
		Description:   description,
		Execution: ExecutionInfo{
			Num:  numToExecute,
			Msgs: splitGov,
		},
	}

	proposalId++
	proposals[proposalId] = proposal
	latestProposalByProposer[proposer.String()] = proposalId

	std.Emit(
		"Proposed",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_title", title,
		"p_description", description,
		"p_numToExecute", ufmt.Sprintf("%d", numToExecute),
		"p_executions", executions,
		"proposalType", "PARAMETER_CHANGE",
		"proposer", proposer.String(),
		"proposalId", ufmt.Sprintf("%d", proposalId),
	)

	return proposalId
}

// Vote allows a user to vote on a given proposal.
// The user's voting weight is determined by their average delegated stake over a specified period.
// Panics if the voting conditions are not met (e.g., voting period hasn't started, has ended, or user has already voted).
func Vote(proposalId uint64, yes bool) string {
	common.IsHalted()

	en.MintAndDistributeGns()
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

	weight := gs.GetDelegatedCumulative(
		voter.String(),
		votingStartTime-config.VotingWeightSmoothingDuration,
	)
	if weight == 0 {
		panic(ufmt.Sprintf("no average delegated found for voter %s", voter.String()))
	}

	var overflow bool
	if yes {
		proposal.Yea, overflow = new(u256.Uint).AddOverflow(proposal.Yea, u256.NewUint(weight))
		if overflow {
			panic("VOTE YES OVERFLOW")
		}
	} else {
		proposal.Nay, overflow = new(u256.Uint).AddOverflow(proposal.Nay, u256.NewUint(weight))
		if overflow {
			panic("VOTE NO OVERFLOW")
		}
	}

	proposals[proposalId] = proposal // update Yea, Nay
	votes[voteKey] = yes

	if userVotes[voter.String()] == nil {
		userVotes[voter.String()] = make(map[uint64]voteWithWeight)
	}
	userVotes[voter.String()][proposalId] = voteWithWeight{
		Yes:         yes,
		Weight:      weight,
		VotedHeight: uint64(std.GetHeight()),
		VotedAt:     now,
	}

	std.Emit(
		"Voted",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_proposalId", ufmt.Sprintf("%d", proposalId),
		"p_yes", voteToString(yes),
		"voter", voter.String(),
		"weight", ufmt.Sprintf("%d", weight),
	)

	return voteKey
}

// Cancel cancels the proposal with the given ID.
// Only callable by the proposer or if the proposer's stake has fallen below the threshold.
// Panics if the proposal doesn't exist, is already canceled, or if voting has already started.
func Cancel(proposalId uint64) {
	common.IsHalted()

	en.MintAndDistributeGns()
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
		enough := checkEnoughXGnsToPropose(proposal.Proposer)
		if enough {
			panic(
				ufmt.Sprintf(
					"caller %s is not the proposer(%s) and proposer's xgns balance is above the threshold",
					caller, proposal.Proposer,
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
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_proposalId", ufmt.Sprintf("%d", proposalId),
		"by", caller.String(),
	)
}

// Execute executes the given proposal.
// It checks various conditions such as voting period, execution window, quorum, and majority.
// Returns the results of the executed calls.
// Panics if any of the execution conditions are not met.
func Execute(proposalId uint64) {
	common.IsHalted()

	en.MintAndDistributeGns()
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
	quorumUint := proposal.QuorumAmount

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
		executeParameterChange(proposal.Execution.Msgs)
	}

	proposal.ExecutionState.Executed = true
	proposal.ExecutionState.ExecutedAt = now
	proposal.ExecutionState.Upcoming = false
	proposal.ExecutionState.Active = false
	proposals[proposalId] = proposal

	std.Emit(
		"Executed",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_proposalId", ufmt.Sprintf("%d", proposalId),
		"executor", std.GetOrigCaller().String(),
	)
}

func updateProposalsState() {
	now := uint64(time.Now().Unix())
	for id, proposal := range proposals {
		config := GetConfigVersion(proposal.ConfigVersion)

		// check if proposal is in a state that needs to be updated
		// - created
		// - not canceled
		// - not executed

		// proposal is in voting period
		if proposal.ExecutionState.Created &&
			!proposal.ExecutionState.Canceled &&
			!proposal.ExecutionState.Executed {

			if proposal.ExecutionState.Upcoming && // was upcoming
				now >= (proposal.ExecutionState.CreatedAt+config.VotingStartDelay) && // voting started
				now <= (proposal.ExecutionState.CreatedAt+config.VotingStartDelay+config.VotingPeriod) { // voting not ended
				proposal.ExecutionState.Upcoming = false
				proposal.ExecutionState.Active = true
			}
		}

		// proposal voting ended, check if passed or rejected
		if now > (proposal.ExecutionState.CreatedAt+config.VotingStartDelay+config.VotingPeriod) &&
			(proposal.ExecutionState.Passed == false && proposal.ExecutionState.Rejected == false && proposal.ExecutionState.Canceled == false) {
			yeaUint := proposal.Yea.Uint64()
			nayUint := proposal.Nay.Uint64()
			quorumUint := proposal.QuorumAmount

			if yeaUint >= quorumUint && yeaUint > nayUint {
				proposal.ExecutionState.Passed = true
				proposal.ExecutionState.PassedAt = now
			} else {
				proposal.ExecutionState.Rejected = true
				proposal.ExecutionState.RejectedAt = now
			}
			proposal.ExecutionState.Upcoming = false
			proposal.ExecutionState.Active = false
		}

		// (non text) proposal passed but not executed until executing window ends
		if proposal.ProposalType != "TEXT" && // isn't text type ≈ can be executed
			proposal.ExecutionState.Passed && // passed
			!proposal.ExecutionState.Executed && // not executed
			!proposal.ExecutionState.Expired { // not expired

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

func checkEnoughXGnsToPropose(proposer std.Address) bool {
	xGNS := xgns.BalanceOf(a2u(proposer))
	if xGNS < config.ProposalCreationThreshold {
		return false
	}

	return true
}
