package governance

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gov/xgns"

	en "gno.land/r/gnoswap/v1/emission"
	gs "gno.land/r/gnoswap/v1/gov/staker"
)

var (
	proposalId               uint64
	proposals                = make(map[uint64]ProposalInfo) // proposalId -> ProposalInfo
	latestProposalByProposer = make(map[std.Address]uint64)  // proposer -> proposalId
)

const (
	GOV_SPLIT = "*GOV*"
	EXE_SPLIT = "*EXE*"
)

// ProposeText creates a new text proposal with the given data
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Returns the proposal ID
// ref: https://docs.gnoswap.io/contracts/governance/proposal.gno#proposetext
func ProposeText(
	title string,
	description string,
) uint64 { // proposalId
	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()

	proposer := std.PrevRealm().Addr()

	enough, balance, wanted := checkEnoughXGnsToPropose(proposer)
	if !enough {
		panic(addDetailToError(
			errNotEnoughBalance,
			ufmt.Sprintf("proposer(%s) has not enough xGNS, balance(%d), wanted(%d)", proposer.String(), balance, wanted),
		))
	}

	now := uint64(time.Now().Unix())
	votingMax, possibleAddressWithWeight := gs.GetPossibleVotingAddressWithWeight(now - config.VotingWeightSmoothingDuration)

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: Text,
		ExecutionState: ExecutionState{
			Created:   true,
			CreatedAt: now,
			Upcoming:  true,
		},
		Yea:                       u256.Zero(),
		Nay:                       u256.Zero(),
		MaxVotingWeight:           u256.NewUint(votingMax),
		PossibleAddressWithWeight: possibleAddressWithWeight,
		ConfigVersion:             uint64(len(configVersions)), // use latest config version
		QuorumAmount:              xgns.VotingSupply() * config.Quorum / 100,
		Title:                     title,
		Description:               description,
	}

	proposalId++
	proposals[proposalId] = proposal
	latestProposalByProposer[proposer] = proposalId

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"ProposeText",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"title", title,
		"description", description,
		"internal_proposalId", ufmt.Sprintf("%d", proposalId),
	)

	return proposalId
}

// ProposeCommunityPoolSpend creates a new community pool spend proposal with the given data
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Returns the proposal ID
// ref: https://docs.gnoswap.io/contracts/governance/proposal.gno#proposecommunitypoolspend
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

	proposer := std.PrevRealm().Addr()

	enough, balance, wanted := checkEnoughXGnsToPropose(proposer)
	if !enough {
		panic(addDetailToError(
			errNotEnoughBalance,
			ufmt.Sprintf("proposer(%s) has not enough xGNS, balance(%d), wanted(%d)", proposer.String(), balance, wanted),
		))
	}

	now := uint64(time.Now().Unix())
	votingMax, possibleAddressWithWeight := gs.GetPossibleVotingAddressWithWeight(now - config.VotingWeightSmoothingDuration)

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: CommunityPoolSpend,
		ExecutionState: ExecutionState{
			Created:   true,
			CreatedAt: now,
			Upcoming:  true,
		},
		Yea:                       u256.Zero(),
		Nay:                       u256.Zero(),
		MaxVotingWeight:           u256.NewUint(votingMax),
		PossibleAddressWithWeight: possibleAddressWithWeight,
		ConfigVersion:             uint64(len(configVersions)),
		QuorumAmount:              xgns.VotingSupply() * config.Quorum / 100,
		Title:                     title,
		Description:               description,
		CommunityPoolSpend: CommunityPoolSpendInfo{
			To:        to,
			TokenPath: tokenPath,
			Amount:    amount,
		},
	}

	proposalId++
	proposals[proposalId] = proposal
	latestProposalByProposer[proposer] = proposalId

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"ProposeCommunityPoolSpend",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"title", title,
		"description", description,
		"to", to.String(),
		"tokenPath", tokenPath,
		"amount", ufmt.Sprintf("%d", amount),
		"internal_proposalId", ufmt.Sprintf("%d", proposalId),
	)

	return proposalId
}

// ProposeParameterChange creates a new parameter change with the given data
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Returns the proposal ID
// ref: https://docs.gnoswap.io/contracts/governance/proposal.gno#proposeparameterchange
func ProposeParameterChange(
	title string,
	description string,
	numToExecute uint64,
	executions string,
) uint64 { // proposalId
	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()

	proposer := std.PrevRealm().Addr()

	enough, balance, wanted := checkEnoughXGnsToPropose(proposer)
	if !enough {
		panic(addDetailToError(
			errNotEnoughBalance,
			ufmt.Sprintf("proposer(%s) has not enough xGNS, balance(%d), wanted(%d)", proposer.String(), balance, wanted),
		))
	}

	if numToExecute == 0 {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("numToExecute is 0"),
		))
	}

	// check if numToExecute is a valid number
	splitGov := strings.Split(executions, GOV_SPLIT)
	if uint64(len(splitGov)) != numToExecute {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("numToExecute(%d) does not match the number of executions(%d)", numToExecute, len(splitGov)),
		))
	}

	now := uint64(time.Now().Unix())
	votingMax, possibleAddressWithWeight := gs.GetPossibleVotingAddressWithWeight(now - config.VotingWeightSmoothingDuration)

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: ParameterChange,
		ExecutionState: ExecutionState{
			Created:   true,
			CreatedAt: now,
			Upcoming:  true,
		},
		Yea:                       u256.Zero(),
		Nay:                       u256.Zero(),
		MaxVotingWeight:           u256.NewUint(votingMax),
		PossibleAddressWithWeight: possibleAddressWithWeight,
		ConfigVersion:             uint64(len(configVersions)),
		QuorumAmount:              xgns.VotingSupply() * config.Quorum / 100,
		Title:                     title,
		Description:               description,
		Execution: ExecutionInfo{
			Num:  numToExecute,
			Msgs: splitGov,
		},
	}

	proposalId++
	proposals[proposalId] = proposal
	latestProposalByProposer[proposer] = proposalId

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"ProposeParameterChange",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"title", title,
		"description", description,
		"numToExecute", ufmt.Sprintf("%d", numToExecute),
		"executions", executions,
		"internal_proposalId", ufmt.Sprintf("%d", proposalId),
	)

	return proposalId
}

// proposalStateUpdater handles the state transitions of a proposal.
type proposalStateUpdater struct {
	proposal *ProposalInfo
	config   Config
	now      uint64
}

// updateProposalsState updates the state of all proposals based on current time.
// It processes voting periods, results, and execution windows for each proposal.
func updateProposalsState() {
	now := uint64(time.Now().Unix())

	for id, proposal := range proposals {
		updater := newProposalStateUpdater(&proposal, now)

		updater.updateVotingState()
		updater.updateVotingResult()
		updater.updateExecutionState()

		proposals[id] = *updater.proposal
	}
}

// newProposalStateUpdater creates a new proposalStateUpdater.
func newProposalStateUpdater(proposal *ProposalInfo, now uint64) *proposalStateUpdater {
	return &proposalStateUpdater{
		proposal: proposal,
		config:   GetConfigVersion(proposal.ConfigVersion),
		now:      now,
	}
}

// shouldUpdate determines if the proposal state should be updated.
// Returns true if the proposal is created, not canceled, and not executed.
func (u *proposalStateUpdater) shouldUpdate() bool {
	return u.proposal.ExecutionState.Created &&
		!u.proposal.ExecutionState.Canceled &&
		!u.proposal.ExecutionState.Executed
}

// getVotingTimes returns the start and end timestamps of the voting period.
// The start time is CreatedAt + VotingStartDelay.
// The end time is start time + VotingPeriod.
func (u *proposalStateUpdater) getVotingTimes() (start, end uint64) {
	start = u.proposal.ExecutionState.CreatedAt + u.config.VotingStartDelay
	end = start + u.config.VotingPeriod
	return
}

// getExecutionTimes returns the start and end timestamps of the execution window.
// The start time is after voting end + ExecutionDelay.
// The end time is start time + ExecutionWindow.
func (u *proposalStateUpdater) getExecutionTimes() (start, end uint64) {
	_, votingEnd := u.getVotingTimes()
	start = votingEnd + u.config.ExecutionDelay
	end = start + u.config.ExecutionWindow
	return
}

// updateVotingState updates the voting state of the proposal.
// It transitions from upcoming to active state when voting period starts.
func (u *proposalStateUpdater) updateVotingState() {
	if !u.shouldUpdate() {
		return
	}

	votingStart, votingEnd := u.getVotingTimes()
	isVotingPeriod := u.now >= votingStart && u.now <= votingEnd

	if u.proposal.ExecutionState.Upcoming && isVotingPeriod {
		u.proposal.ExecutionState.Upcoming = false
		u.proposal.ExecutionState.Active = true
	}
}

// updateVotingResult determines the outcome of voting when voting period ends.
// It sets the proposal as passed if it meets quorum and has more yes votes than no votes.
// Otherwise, it marks the proposal as rejected.
func (u *proposalStateUpdater) updateVotingResult() {
	_, votingEnd := u.getVotingTimes()

	hasNoResult := !u.proposal.ExecutionState.Passed &&
		!u.proposal.ExecutionState.Rejected &&
		!u.proposal.ExecutionState.Canceled

	if u.now <= votingEnd || !hasNoResult {
		return
	}

	yeaUint := u.proposal.Yea.Uint64()
	nayUint := u.proposal.Nay.Uint64()

	if yeaUint >= u.proposal.QuorumAmount && yeaUint > nayUint {
		u.proposal.ExecutionState.Passed = true
		u.proposal.ExecutionState.PassedAt = u.now
	} else {
		u.proposal.ExecutionState.Rejected = true
		u.proposal.ExecutionState.RejectedAt = u.now
	}

	u.proposal.ExecutionState.Upcoming = false
	u.proposal.ExecutionState.Active = false
}

// updateExecutionState checks if a non-text proposal should expire.
// It marks the proposal as expired if execution window has ended.
func (u *proposalStateUpdater) updateExecutionState() {
	if u.proposal.ProposalType == Text ||
		!u.proposal.ExecutionState.Passed ||
		u.proposal.ExecutionState.Executed ||
		u.proposal.ExecutionState.Expired {
		return
	}

	_, executionEnd := u.getExecutionTimes()

	if u.now >= executionEnd {
		u.proposal.ExecutionState.Expired = true
		u.proposal.ExecutionState.ExpiredAt = u.now
	}
}

func checkEnoughXGnsToPropose(proposer std.Address) (bool, uint64, uint64) {
	xGNSBalance := xgns.BalanceOf(a2u(proposer))

	if xGNSBalance < config.ProposalCreationThreshold {
		return false, xGNSBalance, config.ProposalCreationThreshold
	}

	return true, xGNSBalance, config.ProposalCreationThreshold
}
