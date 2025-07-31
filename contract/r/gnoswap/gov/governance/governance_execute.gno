package governance

import (
	"std"
	"time"

	"gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/halt"
)

// Execute executes an approved proposal with the given ID.
// This function can be called by anyone once a proposal is in executable state.
// It processes the proposal based on its type (CommunityPoolSpend or ParameterChange).
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - proposalID: unique identifier of the proposal to execute
//
// Returns:
//   - int64: the executed proposal ID
//
// Panics:
//   - if system is halted during execution phase
//   - if proposal execution fails for any reason
//
// ref: https://docs.gnoswap.io/contracts/governance/vote.gno#execute
func Execute(cur realm, proposalID int64) int64 {
	// Check if execution is allowed (system not halted for execution)
	halt.AssertIsNotHaltedGovernance()

	// Get caller information and current blockchain state
	caller := std.PreviousRealm().Address()
	currentHeight := std.ChainHeight()
	currentAt := time.Now().Unix()

	// Mint and distribute GNS tokens as part of the execution process
	en.MintAndDistributeGns(cross)

	// Attempt to execute the proposal with current context
	proposal, err := executeProposal(
		proposalID,
		currentAt,
		currentHeight,
		caller,
	)
	if err != nil {
		panic(err)
	}

	// Emit execution event for tracking and auditing
	previousRealm := std.PreviousRealm()
	std.Emit(
		"Execute",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"proposalId", formatInt(proposalID),
	)

	return proposal.ID()
}

// executeProposal handles the core logic of proposal execution.
// This internal function validates the proposal state, executes the appropriate actions,
// and updates the proposal status.
//
// Parameters:
//   - proposalID: unique identifier of the proposal
//   - executedAt: timestamp when execution is performed
//   - executedHeight: blockchain height at execution
//   - executedBy: address of the executor
//
// Returns:
//   - *Proposal: pointer to the executed proposal
//   - error: execution error if any
func executeProposal(
	proposalID int64,
	executedAt int64,
	executedHeight int64,
	executedBy std.Address,
) (*Proposal, error) {
	// Retrieve the proposal from storage
	proposal, ok := getProposal(proposalID)
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
	parameterRegistry := createParameterHandlers()

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

	// Mark execution as successful
	proposal.status.updateExecuteResult(true)

	return proposal, nil
}

// Cancel cancels a proposal in upcoming status.
// This function allows cancellation of proposals that are in the upcoming state,
// before entering the voting period. Only the proposal creator can cancel their proposal
// during this upcoming window.
//
// Parameters:
//   - cur: realm context for cross-realm calls and contract interactions
//   - proposalID: unique identifier of the proposal to cancel (must be positive)
//
// Returns:
//   - int64: the ID of the successfully canceled proposal
//
// Panics:
//   - if governance system is in halted state
//   - if proposal does not exist
//   - if proposal is not in upcoming status
//   - if proposal is already executed or canceled
//   - if caller is not the original proposer
//
// ref: https://docs.gnoswap.io/contracts/governance/vote.gno#cancel
func Cancel(cur realm, proposalID int64) int64 {
	halt.AssertIsNotHaltedGovernance()

	// Get current blockchain state and caller information
	currentHeight := std.ChainHeight()
	currentAt := time.Now().Unix()
	caller := std.PreviousRealm().Address()

	// Mint and distribute GNS tokens as part of the process
	en.MintAndDistributeGns(cross)

	// Attempt to cancel the proposal
	proposal, err := cancel(proposalID, currentAt, currentHeight, caller)
	if err != nil {
		panic(err)
	}

	// Emit cancellation event for tracking
	previousRealm := std.PreviousRealm()
	std.Emit(
		"Cancel",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"proposalId", formatInt(proposalID),
	)

	return proposal.ID()
}

// cancel handles the core logic of proposal cancellation.
// This internal function validates the proposal state and updates its status to canceled.
// It checks if the proposal exists and can be canceled, then updates its status.
//
// Parameters:
//   - proposalID: unique identifier of the proposal to be canceled
//   - canceledAt: unix timestamp when cancellation is requested
//   - canceledHeight: blockchain height at time of cancellation
//   - canceledBy: address of the account requesting cancellation
//
// Returns:
//   - *Proposal: the canceled proposal if successful
//   - error: returns error if proposal not found or cancellation fails
func cancel(proposalID, canceledAt, canceledHeight int64, canceledBy std.Address) (proposal *Proposal, err error) {
	// Retrieve the proposal from storage
	proposal, ok := getProposal(proposalID)
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
// This function handles token transfers from the community pool to specified recipients.
//
// Parameters:
//   - proposal: the proposal containing spending details
//   - parameterRegistry: registry of parameter handlers for execution
//   - executedAt: execution timestamp
//   - executedHeight: execution block height
//   - executedBy: executor address
//
// Returns:
//   - error: execution error if any
func executeCommunityPoolSpend(
	proposal *Proposal,
	parameterRegistry *ParameterRegistry,
	executedAt int64,
	executedHeight int64,
	executedBy std.Address,
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
// This function handles governance configuration updates and system parameter modifications.
//
// Parameters:
//   - proposal: the proposal containing parameter changes
//   - parameterRegistry: registry of parameter handlers for execution
//   - executedAt: execution timestamp
//   - executedHeight: execution block height
//   - executedBy: executor address
//
// Returns:
//   - error: execution error if any
func executeParameterChange(
	proposal *Proposal,
	parameterRegistry *ParameterRegistry,
	executedAt int64,
	executedHeight int64,
	executedBy std.Address,
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
