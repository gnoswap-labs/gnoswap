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
			ufmt.Sprintf("governance.gno__ProposeText() || proposer(%s) has not enough xGNS, balance(%d), wanted(%d)", proposer.String(), balance, wanted),
		))
	}

	now := uint64(time.Now().Unix())
	votingMax, possibleAddressWithWeight := gs.GetPossibleVotingAddressWithWeight(now - config.VotingWeightSmoothingDuration)

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: "TEXT",
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
			ufmt.Sprintf("governance.gno__ProposeCommunityPoolSpend() || proposer(%s) has not enough xGNS, balance(%d), wanted(%d)", proposer.String(), balance, wanted),
		))
	}

	now := uint64(time.Now().Unix())
	votingMax, possibleAddressWithWeight := gs.GetPossibleVotingAddressWithWeight(now - config.VotingWeightSmoothingDuration)

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: "COMMUNITY_POOL_SPEND",
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
			ufmt.Sprintf("governance.gno__ProposeParameterChange() || proposer(%s) has not enough xGNS, balance(%d), wanted(%d)", proposer.String(), balance, wanted),
		))
	}

	if numToExecute == 0 {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("governance.gno__ProposeParameterChange() || numToExecute is 0"),
		))
	}

	// check if numToExecute is a valid number
	splitGov := strings.Split(executions, "*GOV*")
	if uint64(len(splitGov)) != numToExecute {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("governance.gno__ProposeParameterChange() || numToExecute(%d) does not match the number of executions(%d)", numToExecute, len(splitGov)),
		))
	}

	// check if each execution is valid
	for _, gov := range splitGov {
		splitExe := strings.Split(gov, "*EXE*")
		if len(splitExe) != 3 {
			panic(addDetailToError(
				errInvalidInput,
				ufmt.Sprintf("governance.gno__ProposeParameterChange() || invalid execution(%s) to split by *EXE*, seems like param didn't passed", gov),
			))
		}

		pkgPath := splitExe[0]
		funcName := splitExe[1]
		params := splitExe[2]

		// check if msg is callable
		callableMsg(pkgPath, funcName, params)
	}

	now := uint64(time.Now().Unix())
	votingMax, possibleAddressWithWeight := gs.GetPossibleVotingAddressWithWeight(now - config.VotingWeightSmoothingDuration)

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: "PARAMETER_CHANGE",
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

func checkEnoughXGnsToPropose(proposer std.Address) (bool, uint64, uint64) {
	xGNSBalance := xgns.BalanceOf(a2u(proposer))

	if xGNSBalance < config.ProposalCreationThreshold {
		return false, xGNSBalance, config.ProposalCreationThreshold
	}

	return true, xGNSBalance, config.ProposalCreationThreshold
}
