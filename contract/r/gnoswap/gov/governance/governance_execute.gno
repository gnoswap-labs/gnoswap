package governance

import (
	"std"
	"time"

	"gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
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
	assertHaltedExecute()

	// Get caller information and current blockchain state
	previousRealm := std.PreviousRealm()
	currentHeight := std.ChainHeight()
	currentAt := time.Now().Unix()

	// Mint and distribute GNS tokens as part of the execution process
	en.MintAndDistributeGns(cross)

	// Attempt to execute the proposal with current context
	proposal, err := executeProposal(
		proposalID,
		currentAt,
		currentHeight,
		previousRealm.Address(),
	)
	if err != nil {
		panic(err)
	}

	// Emit execution event for tracking and auditing
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

// Cancel cancels an active proposal with the given ID.
// This function can be called by the proposer or others if the proposer's stake has fallen below threshold.
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - proposalID: unique identifier of the proposal to cancel
//
// Returns:
//   - int64: the canceled proposal ID
//
// Panics:
//   - if system is halted
//   - if cancellation fails
//
// ref: https://docs.gnoswap.io/contracts/governance/vote.gno#cancel
func Cancel(cur realm, proposalID int64) int64 {
	// Check if system is halted before allowing cancellation
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}

	// Get current blockchain state and caller information
	currentHeight := std.ChainHeight()
	currentAt := time.Now().Unix()
	previousRealm := std.PreviousRealm()

	// Mint and distribute GNS tokens as part of the process
	en.MintAndDistributeGns(cross)

	// Attempt to cancel the proposal
	proposal, err := cancel(proposalID, currentAt, currentHeight, previousRealm.Address())
	if err != nil {
		panic(err)
	}

	// Emit cancellation event for tracking
	prevAddr, prevPkgPath := previousRealm.Address(), previousRealm.PkgPath()
	std.Emit(
		"Cancel",
		"prevAddr", prevAddr.String(),
		"prevRealm", prevPkgPath,
		"proposalId", formatInt(proposalID),
	)

	return proposal.ID()
}

// cancel handles the core logic of proposal cancellation.
// This internal function validates the proposal state and updates its status to canceled.
//
// Parameters:
//   - proposalID: unique identifier of the proposal
//   - canceledAt: timestamp when cancellation is performed
//   - canceledHeight: blockchain height at cancellation
//   - canceledBy: address of the canceller
//
// Returns:
//   - *Proposal: pointer to the canceled proposal
//   - error: cancellation error if any
func cancel(proposalID, canceledAt, canceledHeight int64, canceledBy std.Address) (proposal *Proposal, err error) {
	// Retrieve the proposal from storage
	proposal, ok := getProposal(proposalID)
	if !ok {
		return nil, errDataNotFound
	}

	// Check if the caller is the proposer or if proposer's stake has fallen below threshold
	if canceledBy != proposal.proposer {
		// If not the proposer, check if proposer's stake is below threshold
		config, ok := getCurrentConfig()
		if !ok {
			return nil, errDataNotFound
		}

		proposerGnsBalance := gns.BalanceOf(proposal.proposer)
		if proposerGnsBalance >= config.ProposalCreationThreshold {
			// Proposer still has enough stake, only proposer can cancel
			return nil, errNotAuthorized
		}
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
