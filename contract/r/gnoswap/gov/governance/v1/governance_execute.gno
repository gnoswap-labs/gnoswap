package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/common"
	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
)

// Execute executes an approved proposal.
//
// Processes and implements governance decisions after successful voting.
// Enforces timelock delays and execution windows for security.
// Anyone can trigger execution to ensure decentralization.
//
// Parameters:
//   - proposalID: ID of the proposal to execute
//
// Requirements:
//   - Proposal must have passed (majority yes votes)
//   - Quorum must be reached (50% of xGNS supply)
//   - Timelock period must have elapsed (1 day default)
//   - Must be within execution window (30 days default)
//   - Proposal not already executed or cancelled
//
// Effects:
//   - Executes proposal actions (parameter changes, treasury transfers)
//   - Marks proposal as executed
//   - Emits execution event
//   - Refunds gas costs from treasury
//
// Returns executed proposal ID.
// Callable by anyone once proposal is executable.
func (gv *governanceV1) Execute(proposalID int64) int64 {
	// Check if execution is allowed (system not halted for execution)
	halt.AssertIsNotHaltedGovernance()

	// Get caller information and current blockchain state
	caller := runtime.PreviousRealm().Address()
	currentHeight := runtime.ChainHeight()
	currentAt := time.Now().Unix()

	// Mint and distribute GNS tokens as part of the execution process
	en.MintAndDistributeGns(cross)

	var proposal *Proposal
	var err error

	func (cur realm) {
		// Attempt to execute the proposal with current context
		proposal, err = gv.executeProposal(
			proposalID,
			currentAt,
			currentHeight,
			caller,
		)
		if err != nil {
			panic(err)
		}
	}(cross)

	// Emit execution event for tracking and auditing
	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"Execute",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"proposalId", formatInt(proposalID),
	)

	return proposal.ID()
}

// executeProposal handles core logic of proposal execution.
func (gv *governanceV1) executeProposal(
	proposalID int64,
	executedAt int64,
	executedHeight int64,
	executedBy address,
) (*Proposal, error) {
	state := gv.GetGovernanceState()

	// Retrieve the proposal from storage
	proposal, ok := state.getProposal(proposalID)
	if !ok {
		return nil, errDataNotFound
	}

	// Text proposals cannot be executed (they are informational only)
	if proposal.IsTextType() {
		return nil, errTextProposalNotExecutable
	}

	// Verify proposal is in executable state (timing and voting requirements met)
	if !proposal.IsExecutable(executedAt) {
		return nil, errProposalNotExecutable
	}

	// Mark proposal as executed in its status
	err := proposal.execute(executedAt, executedHeight, executedBy)
	if err != nil {
		return nil, err
	}

	// Create parameter registry for handling execution actions
	parameterRegistry := gv.createParameterHandlers()

	// Execute proposal based on its type
	switch proposal.Type() {
	case CommunityPoolSpend:
		// Execute community pool spending (token transfers)
		err = executeCommunityPoolSpend(proposal, parameterRegistry, executedAt, executedHeight, executedBy)
		if err != nil {
			return nil, err
		}
	case ParameterChange:
		// Execute parameter changes (governance configuration updates)
		err = executeParameterChange(proposal, parameterRegistry, executedAt, executedHeight, executedBy)
		if err != nil {
			return nil, err
		}
	}

	return proposal, nil
}

// Cancel cancels a proposal in upcoming status.
//
// Allows proposers to withdraw their proposals before voting begins.
// Prevents accidental or malicious proposals from reaching vote.
// Safety mechanism for proposal errors or changed circumstances.
//
// Parameters:
//   - proposalID: ID of the proposal to cancel
//
// Requirements:
//   - Must be called by original proposer
//   - Proposal must be in "upcoming" status
//   - Voting must not have started yet
//   - Proposal not already cancelled or executed
//
// Effects:
//   - Sets proposal status to "cancelled"
//   - Prevents future voting or execution
//   - Emits cancellation event
//   - Frees up proposer's proposal slot
//
// Returns cancelled proposal ID.
// Only callable by original proposer before voting begins.
func (gv *governanceV1) Cancel(proposalID int64) int64 {
	halt.AssertIsNotHaltedGovernance()

	caller := runtime.PreviousRealm().Address()
	state := gv.GetGovernanceState()
	assertCallerIsProposer(state, proposalID, caller)

	// Get current blockchain state and caller information
	currentHeight := runtime.ChainHeight()
	currentAt := time.Now().Unix()

	// Mint and distribute GNS tokens as part of the process
	en.MintAndDistributeGns(cross)

	// Attempt to cancel the proposal
	proposal, err := gv.cancel(proposalID, currentAt, currentHeight, caller)
	if err != nil {
		panic(err)
	}

	// Emit cancellation event for tracking
	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"Cancel",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"proposalId", formatInt(proposalID),
	)

	return proposal.ID()
}

// cancel handles core logic of proposal cancellation.
// Validates proposal state and updates status to canceled.
func (gv *governanceV1) cancel(
	proposalID, canceledAt, canceledHeight int64,
	canceledBy address,
) (proposal *Proposal, err error) {
	state := gv.GetGovernanceState()

	// Retrieve the proposal from storage
	proposal, ok := state.getProposal(proposalID)
	if !ok {
		return nil, errDataNotFound
	}

	// Attempt to cancel the proposal (this validates cancellation conditions)
	err = proposal.cancel(canceledAt, canceledHeight, canceledBy)
	if err != nil {
		return nil, err
	}

	return proposal, nil
}

// executeCommunityPoolSpend executes community pool spending proposals.
// Handles token transfers from community pool to specified recipients.
func executeCommunityPoolSpend(
	proposal *Proposal,
	parameterRegistry *ParameterRegistry,
	executedAt int64,
	executedHeight int64,
	executedBy address,
) error {
	// Verify token registration for community pool spending
	if proposal.IsCommunityPoolSpendType() {
		common.MustRegistered(proposal.CommunityPoolSpendTokenPath())
	}

	// Execute all parameter changes defined in the proposal
	parameterChangesInfos := proposal.data.execution.ParameterChangesInfos()
	for _, parameterChangeInfo := range parameterChangesInfos {
		// Get the appropriate handler for this parameter change
		handler, err := parameterRegistry.handler(parameterChangeInfo.pkgPath, parameterChangeInfo.function)
		if err != nil {
			return err
		}

		// Execute the parameter change with provided parameters
		err = handler.Execute(parameterChangeInfo.params)
		if err != nil {
			return err
		}
	}

	return nil
}

// executeParameterChange executes parameter change proposals.
// Handles governance configuration updates and system parameter modifications.
func executeParameterChange(
	proposal *Proposal,
	parameterRegistry *ParameterRegistry,
	executedAt int64,
	executedHeight int64,
	executedBy address,
) error {
	// Execute all parameter changes defined in the proposal
	parameterChangesInfos := proposal.data.execution.ParameterChangesInfos()
	for _, parameterChangeInfo := range parameterChangesInfos {
		// Get the appropriate handler for this parameter change
		handler, err := parameterRegistry.handler(parameterChangeInfo.pkgPath, parameterChangeInfo.function)
		if err != nil {
			return err
		}

		// Execute the parameter change with provided parameters
		err = handler.Execute(parameterChangeInfo.params)
		if err != nil {
			return err
		}
	}

	return nil
}
