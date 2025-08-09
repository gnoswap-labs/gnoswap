package governance

import (
	"std"
	"time"

	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"
)

// Execute executes an approved proposal with the given ID.
// This function can be called by anyone once a proposal is in executable state.
// It processes the proposal based on its type (CommunityPoolSpend or ParameterChange).
// Returns the executed proposal ID.
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

// executeProposal handles core logic of proposal execution.
// Validates proposal state, executes appropriate actions, and updates proposal status.
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

	return proposal, nil
}

// Cancel cancels a proposal in upcoming status.
// Only the original proposer can cancel their proposal before voting begins.
// Provides safety mechanism for proposers to withdraw proposals before voting starts.
func Cancel(cur realm, proposalID int64) int64 {
	halt.AssertIsNotHaltedGovernance()

	caller := std.PreviousRealm().Address()
	assertCallerIsProposer(proposalID, caller)

	// Get current blockchain state and caller information
	currentHeight := std.ChainHeight()
	currentAt := time.Now().Unix()

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

// cancel handles core logic of proposal cancellation.
// Validates proposal state and updates status to canceled.
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
// Handles token transfers from community pool to specified recipients.
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
// Handles governance configuration updates and system parameter modifications.
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
