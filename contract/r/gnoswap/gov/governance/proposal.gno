package governance

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"
	gs "gno.land/r/gnoswap/v1/gov/staker"
	"gno.land/r/gnoswap/v1/gov/xgns"
	"gno.land/r/gnoswap/v1/halt"
)

var (
	proposalId               uint64
	proposals                = avl.NewTree() // Only stores active proposals
	archivedProposals        = avl.NewTree() // Stores terminated proposals
	proposalIdListByProposer = avl.NewTree() // proposer -> proposalId
)

// Governance can execute multiple messages in a single proposal
// To separate the messages, we use this separator
// Look for ProposeParameterChange() for more details
const (
	GOV_SPLIT   = "*GOV*"
	ROLE_PREFIX = "ROLE_CHANGE:"
)

func init() {
	proposalId = 0 // initialize proposalId
}

// ProposeText creates a new text proposal with the given data
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Returns the proposal ID
// ref: https://docs.gnoswap.io/contracts/governance/proposal.gno#proposetext
func ProposeText(
	cur realm,
	title string,
	description string,
) uint64 { // proposalId
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}
	proposer := std.PreviousRealm().Address()
	enough, balance, wanted := checkEnoughXGnsToPropose(proposer)
	if !enough {
		panic(addDetailToError(
			errNotEnoughBalance,
			ufmt.Sprintf("proposer(%s) has not enough xGNS, balance(%d), wanted(%d)", proposer.String(), balance, wanted),
		))
	}

	en.MintAndDistributeGns(cross)
	updateProposalsState()

	now := uint64(time.Now().Unix())
	// votingMax does not include quantities delegated through Launchpad.
	votingMax, possibleAddressWithWeight := gs.GetPossibleVotingAddressWithWeight(now - config.VotingWeightSmoothingDuration)

	maxVotingWeight := u256.NewUint(votingMax)
	quorumAmount := maxVotingWeight.Uint64() * config.Quorum / 100

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: Text,
		State: ProposalState{
			Created:   true,
			CreatedAt: now,
			Upcoming:  true,
		},
		Yea:                       u256.Zero(),
		Nay:                       u256.Zero(),
		MaxVotingWeight:           maxVotingWeight,
		PossibleAddressWithWeight: possibleAddressWithWeight,
		ConfigVersion:             uint64(configVersions.Size()), // use latest config version
		QuorumAmount:              quorumAmount,
		Title:                     title,
		Description:               description,
	}

	increaseProposalId()
	newProposalId := getProposalId()
	proposals.Set(formatUint(newProposalId), proposal)
	proposalIdListByProposer.Set(proposer.String(), newProposalId)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"ProposeText",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"title", title,
		"description", description,
		"proposalId", formatUint(newProposalId),
		"quorumAmount", formatUint(proposal.QuorumAmount),
		"maxVotingWeight", proposal.MaxVotingWeight.ToString(),
		"configVersion", formatUint(proposal.ConfigVersion),
		"createdAt", formatUint(proposal.State.CreatedAt),
	)
	return proposalId
}

// ProposeCommunityPoolSpend creates a new community pool spend proposal with the given data
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Returns the proposal ID
// ref: https://docs.gnoswap.io/contracts/governance/proposal.gno#proposecommunitypoolspend
func ProposeCommunityPoolSpend(
	cur realm,
	title string,
	description string,
	to std.Address,
	tokenPath string,
	amount uint64,
) uint64 { // proposalId
	// Skip halt check if current level is MainnetSafeMode
	currentLevel := halt.GetCurrentHaltLevel()
	if currentLevel != halt.LvMainnetSafeMode {
		// Check if withdrawals are specifically halted, not just if the system is halted
		if err := halt.IsHalted(halt.OpTypeWithdraw); err != nil {
			panic(err.Error())
		}

		if halt.IsContractHalted(halt.OpTypeGovernance) {
			panic("gov/governance contract operations are currently disabled")
		}
	}

	proposer := std.PreviousRealm().Address()
	enough, balance, wanted := checkEnoughXGnsToPropose(proposer)
	if !enough {
		panic(addDetailToError(
			errNotEnoughBalance,
			ufmt.Sprintf("proposer(%s) has not enough xGNS, balance(%d), wanted(%d)", proposer.String(), balance, wanted),
		))
	}
	if !to.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("address is %s", to.String()),
		))
	}
	common.MustRegistered(tokenPath)
	if amount == 0 {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("amount is 0"),
		))
	}

	en.MintAndDistributeGns(cross)
	updateProposalsState()

	now := uint64(time.Now().Unix())
	votingMax, possibleAddressWithWeight := gs.GetPossibleVotingAddressWithWeight(now - config.VotingWeightSmoothingDuration)

	maxVotingWeight := u256.NewUint(votingMax)
	quorumAmount := maxVotingWeight.Uint64() * config.Quorum / 100

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: CommunityPoolSpend,
		State: ProposalState{
			Created:   true,
			CreatedAt: now,
			Upcoming:  true,
		},
		Yea:                       u256.Zero(),
		Nay:                       u256.Zero(),
		MaxVotingWeight:           maxVotingWeight,
		PossibleAddressWithWeight: possibleAddressWithWeight,
		ConfigVersion:             uint64(configVersions.Size()),
		QuorumAmount:              quorumAmount,
		Title:                     title,
		Description:               description,
		CommunityPoolSpend: CommunityPoolSpendInfo{
			To:        to,
			TokenPath: tokenPath,
			Amount:    amount,
		},
	}

	increaseProposalId()
	proposals.Set(formatUint(proposalId), proposal)
	proposalIdListByProposer.Set(proposer.String(), proposalId)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"ProposeCommunityPoolSpend",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"title", title,
		"description", description,
		"to", to.String(),
		"tokenPath", tokenPath,
		"amount", formatUint(amount),
		"proposalId", formatUint(proposalId),
		"quorumAmount", formatUint(proposal.QuorumAmount),
		"maxVotingWeight", proposal.MaxVotingWeight.ToString(),
		"configVersion", formatUint(proposal.ConfigVersion),
		"createdAt", formatUint(proposal.State.CreatedAt),
	)

	return proposalId
}

// ProposeParameterChange creates a new parameter change with the given data
// It checks if the proposer is eligible to create a proposal and if they don't have an active proposal.
// Through gnoswap interface, following string will be passed in for executions:
// <pkgPath>*EXE*<function>*EXE*<params>*GOV*<pkgPath>*EXE*<function>*EXE*<params>
// *GOV* is used to separate the messages
//
// Returns the proposal ID
// ref: https://docs.gnoswap.io/contracts/governance/proposal.gno#proposeparameterchange
func ProposeParameterChange(
	cur realm,
	title string,
	description string,
	numToExecute uint64,
	executions string,
) uint64 { // proposalId
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}
	proposer := std.PreviousRealm().Address()
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

	if strings.HasPrefix(executions, ROLE_PREFIX) {
		return handleRoleChangeProposal(cur, title, description, proposer, executions)
	}

	// check if numToExecute is a valid number
	splitGov := strings.Split(executions, GOV_SPLIT)
	if uint64(len(splitGov)) != numToExecute {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("numToExecute(%d) does not match the number of executions(%d)", numToExecute, len(splitGov)),
		))
	}

	en.MintAndDistributeGns(cross)
	updateProposalsState()

	now := uint64(time.Now().Unix())
	votingMax, possibleAddressWithWeight := gs.GetPossibleVotingAddressWithWeight(now - config.VotingWeightSmoothingDuration)

	maxVotingWeight := u256.NewUint(votingMax)
	quorumAmount := maxVotingWeight.Uint64() * config.Quorum / 100

	proposal := ProposalInfo{
		Proposer:     proposer,
		ProposalType: ParameterChange,
		State: ProposalState{
			Created:   true,
			CreatedAt: now,
			Upcoming:  true,
		},
		Yea:                       u256.Zero(),
		Nay:                       u256.Zero(),
		MaxVotingWeight:           maxVotingWeight,
		PossibleAddressWithWeight: possibleAddressWithWeight,
		ConfigVersion:             uint64(configVersions.Size()),
		QuorumAmount:              quorumAmount,
		Title:                     title,
		Description:               description,
		Execution: ExecutionInfo{
			Num:  numToExecute,
			Msgs: splitGov,
		},
	}

	increaseProposalId()
	proposals.Set(formatUint(proposalId), proposal)
	proposalIdListByProposer.Set(proposer.String(), proposalId)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"ProposeParameterChange",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"title", title,
		"description", description,
		"numToExecute", formatUint(numToExecute),
		"executions", executions,
		"proposalId", formatUint(proposalId),
		"quorumAmount", formatUint(proposal.QuorumAmount),
		"maxVotingWeight", proposal.MaxVotingWeight.ToString(),
		"configVersion", formatUint(proposal.ConfigVersion),
		"createdAt", formatUint(proposal.State.CreatedAt),
	)

	return proposalId
}

// checkEnoughXGnsToPropose checks if the proposer has enough xGNS to propose a proposal.
// ref: https://docs.gnoswap.io/core-concepts/governance#scope-of-proposals-5
// It returns a boolean indicating if the proposer has enough xGNS, the balance of xGNS, and the threshold of xGNS.
func checkEnoughXGnsToPropose(proposer std.Address) (bool, int64, uint64) {
	xGNSBalance := xgns.BalanceOf(proposer)

	if xGNSBalance < int64(config.ProposalCreationThreshold) {
		return false, xGNSBalance, config.ProposalCreationThreshold
	}

	return true, xGNSBalance, config.ProposalCreationThreshold
}

func increaseProposalId() {
	proposalId++
}

func getProposalId() uint64 {
	return proposalId
}
