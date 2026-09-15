package governance

import (
	"chain"
	"chain/runtime"
	"errors"
	"time"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"

	"gno.land/p/gnoswap/utils"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"

	"gno.land/r/gnoswap/gov/governance"
)

// Execute executes an approved proposal.
//
// Processes and implements governance decisions after successful voting.
// Enforces the configured execution delay and execution window.
// Anyone can trigger execution to ensure decentralization.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; must be current for authorized governance state updates and is crossed into execution-dependent calls.
//   - proposalID: ID of the proposal to execute
//
// Requirements:
//   - Proposal must have passed (quorum and strict yes-over-no majority)
//   - Quorum must be reached using the proposal's stored amount, derived from
//     the total xGNS supply and configured quorum percentage at creation
//   - Execution delay must have elapsed (1 day by default)
//   - Must be within the execution window (30 days by default)
//   - Proposal not already executed or cancelled
//
// Effects:
//   - Executes proposal actions (parameter changes, treasury transfers)
//   - Marks proposal as executed
//   - Emits execution event
//
// Returns:
//   - proposalID: ID of the executed proposal
//
// Callable by anyone once the proposal is executable.
func (gv *governanceV1) Execute(_ int, rlm realm, proposalID int64) int64 {
	access.AssertIsRlmCurrent(0, rlm)

	// Check if execution is allowed (system not halted for execution)
	halt.AssertIsNotHaltedGovernance()

	// Get caller information and current blockchain state
	prev := rlm.Previous()
	caller := prev.Address()
	currentHeight := runtime.ChainHeight()
	currentAt := time.Now().Unix()

	// Mint and distribute GNS tokens as part of the execution process
	emission.MintAndDistributeGns(cross(rlm))

	// Attempt to execute the proposal with current context
	proposal, err := gv.executeProposal(
		0, rlm,
		proposalID,
		currentAt,
		currentHeight,
		caller,
	)
	if err != nil {
		panic(err)
	}
	if err := gv.removeActiveProposal(0, rlm, proposal); err != nil {
		panic(err)
	}

	// Emit execution event for tracking and auditing
	chain.Emit(
		"Execute",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
		"proposalId", utils.FormatInt(proposalID),
	)

	return proposal.ID()
}

// executeProposal resolves and executes the proposal identified by proposalID.
//
// Parameters:
//   - _: Internal call discriminator; pass 0 when forwarding the governance realm.
//   - rlm: Propagated current realm context used for proposal action calls.
//   - proposalID: Identifier of the proposal to execute.
//   - executedAt: Unix timestamp at which execution is attempted.
//   - executedHeight: Chain height at which execution is attempted.
//   - executedBy: Address credited as the executor.
//
// Returns:
//   - *governance.Proposal: executed proposal, or nil when lookup/validation/action execution fails.
//   - error: nil on success; non-nil when the proposal is missing, not executable, or an action fails.
//
// executeProposal handles core logic of proposal execution.
func (gv *governanceV1) executeProposal(
	_ int, rlm realm,
	proposalID int64,
	executedAt int64,
	executedHeight int64,
	executedBy address,
) (*governance.Proposal, error) {
	// Retrieve the proposal from storage
	proposal, ok := gv.getProposal(proposalID)
	if !ok {
		return nil, errors.New(errDataNotFound)
	}

	// Text proposals cannot be executed (they are informational only)
	if proposal.IsTextType() {
		return nil, errors.New(errTextProposalNotExecutable)
	}

	proposalResolver := NewProposalResolver(proposal)

	// Verify proposal is in executable state (timing and voting requirements met)
	if !proposalResolver.IsExecutable(executedAt) {
		return nil, errors.New(errProposalNotExecutable)
	}

	// Mark proposal as executed in its status
	err := proposalResolver.execute(executedAt, executedHeight, executedBy)
	if err != nil {
		return nil, err
	}

	// Execute proposal based on its type
	switch proposal.Type() {
	case governance.CommunityPoolSpend:
		// Execute community pool spending (token transfers)
		err = executeCommunityPoolSpend(0, rlm, proposal, globalParameterRegistry, executedAt, executedHeight, executedBy)
		if err != nil {
			return nil, err
		}
	case governance.ParameterChange:
		// Execute parameter changes (governance configuration updates)
		err = executeParameterChange(0, rlm, proposal, globalParameterRegistry, executedAt, executedHeight, executedBy)
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
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; must be current for authorized governance state updates and is crossed into reward-distribution calls.
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
// Returns:
//   - proposalID: ID of the cancelled proposal
//
// Only callable by original proposer before voting begins.
func (gv *governanceV1) Cancel(_ int, rlm realm, proposalID int64) int64 {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedGovernance()

	prev := rlm.Previous()
	caller := prev.Address()
	assertCallerIsProposer(gv, proposalID, caller)

	// Get current blockchain state and caller information
	currentHeight := runtime.ChainHeight()
	currentAt := time.Now().Unix()

	// Mint and distribute GNS tokens as part of the process
	emission.MintAndDistributeGns(cross(rlm))

	// Attempt to cancel the proposal
	proposal, err := gv.cancel(proposalID, currentAt, currentHeight, caller)
	if err != nil {
		panic(err)
	}
	if err := gv.removeActiveProposal(0, rlm, proposal); err != nil {
		panic(err)
	}

	// Emit cancellation event for tracking
	chain.Emit(
		"Cancel",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
		"proposalId", utils.FormatInt(proposalID),
	)

	return proposal.ID()
}

// RemoveInactiveProposalFromIndex removes one inactive proposal from the
// snapshot index without deleting its proposal or voting history.
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context used for the authorized snapshot-index update.
//   - proposalID: Identifier of the inactive proposal to remove from the snapshot index.
func (gv *governanceV1) RemoveInactiveProposalFromIndex(_ int, rlm realm, proposalID int64) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedGovernance()

	proposal, exists := gv.getProposal(proposalID)
	if !exists {
		panic(makeErrorWithDetails(errProposalNotFound, ufmt.Sprintf("proposalID: %d", proposalID)))
	}
	if NewProposalResolver(proposal).IsActive(time.Now().Unix()) {
		panic(makeErrorWithDetails(errInvalidInput, ufmt.Sprintf("proposal %d is still active", proposalID)))
	}
	if err := gv.removeActiveProposal(0, rlm, proposal); err != nil {
		panic(err)
	}

	prev := rlm.Previous()
	chain.Emit(
		"RemoveInactiveProposalFromIndex",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
		"proposalId", utils.FormatInt(proposalID),
	)
}

// cancel handles core logic of proposal cancellation.
// Validates proposal state and updates status to canceled.
// cancel validates and marks a proposal as cancelled.
//
// Parameters:
//   - proposalID: Identifier of the proposal to cancel.
//   - canceledAt: Unix timestamp at which cancellation is recorded.
//   - canceledHeight: Chain height at which cancellation is recorded.
//   - canceledBy: Address credited as the cancelling proposer.
//
// Returns:
//   - proposal: cancelled proposal, or nil when it is missing or fails validation.
//   - err: nil on success; non-nil when lookup or cancellation-state validation fails.
func (gv *governanceV1) cancel(
	proposalID, canceledAt, canceledHeight int64,
	canceledBy address,
) (proposal *governance.Proposal, err error) {
	// Retrieve the proposal from storage
	proposal, ok := gv.getProposal(proposalID)
	if !ok {
		return nil, errors.New(errDataNotFound)
	}

	proposalResolver := NewProposalResolver(proposal)

	// Attempt to cancel the proposal (this validates cancellation conditions)
	err = proposalResolver.cancel(canceledAt, canceledHeight, canceledBy)
	if err != nil {
		return nil, err
	}

	return proposal, nil
}

// executeCommunityPoolSpend executes community pool spending proposals.
// Handles token transfers from community pool to specified recipients.
// Parameters:
//   - _: Internal call discriminator; pass 0 when forwarding the governance realm.
//   - rlm: Propagated realm context used for handler execution and token authorization.
//   - proposal: Community-pool-spend proposal whose encoded actions are executed.
//   - parameterRegistry: Registry resolving each encoded package/function handler.
//   - executedAt: Unix timestamp at which the proposal is executed.
//   - executedHeight: Chain height at which the proposal is executed.
//   - executedBy: Address credited as executor of the proposal.
//
// Returns:
//   - error: nil when every registered action succeeds; non-nil when token validation, decoding, lookup, or handler execution fails.
func executeCommunityPoolSpend(
	_ int, rlm realm,
	proposal *governance.Proposal,
	parameterRegistry *ParameterRegistry,
	executedAt int64,
	executedHeight int64,
	executedBy address,
) error {
	// Verify token registration for community pool spending
	if proposal.IsCommunityPoolSpendType() {
		common.MustRegistered(proposal.Data().CommunityPoolSpend().TokenPath())
	}

	// Execute all parameter changes defined in the proposal
	dataResolver := NewProposalDataResolver(proposal.Data())
	parameterChangesInfos, err := dataResolver.ParameterChangesInfos()
	if err != nil {
		return err
	}
	for _, parameterChangeInfo := range parameterChangesInfos {
		// Get the appropriate handler for this parameter change
		key := makeHandlerKey(parameterChangeInfo.PkgPath(), parameterChangeInfo.Function())
		handler, err := parameterRegistry.Handler(key)
		if err != nil {
			return err
		}

		// Execute the parameter change with provided parameters
		err = handler.Execute(0, rlm, parameterChangeInfo.Params())
		if err != nil {
			return err
		}
	}

	return nil
}

// executeParameterChange executes parameter change proposals.
// Handles governance configuration updates and system parameter modifications.
// Parameters:
//   - _: Internal call discriminator; pass 0 when forwarding the governance realm.
//   - rlm: Propagated realm context used for handler execution and parameter authorization.
//   - proposal: Parameter-change proposal whose encoded actions are executed.
//   - parameterRegistry: Registry resolving each encoded package/function handler.
//   - executedAt: Unix timestamp at which the proposal is executed.
//   - executedHeight: Chain height at which the proposal is executed.
//   - executedBy: Address credited as executor of the proposal.
//
// Returns:
//   - error: nil when every registered action succeeds; non-nil when decoding, lookup, or handler execution fails.
func executeParameterChange(
	_ int, rlm realm,
	proposal *governance.Proposal,
	parameterRegistry *ParameterRegistry,
	executedAt int64,
	executedHeight int64,
	executedBy address,
) error {
	// Execute all parameter changes defined in the proposal
	dataResolver := NewProposalDataResolver(proposal.Data())
	parameterChangesInfos, err := dataResolver.ParameterChangesInfos()
	if err != nil {
		return err
	}
	for _, parameterChangeInfo := range parameterChangesInfos {
		// Get the appropriate handler for this parameter change
		key := makeHandlerKey(parameterChangeInfo.PkgPath(), parameterChangeInfo.Function())
		handler, err := parameterRegistry.Handler(key)
		if err != nil {
			return err
		}

		// Execute the parameter change with provided parameters
		err = handler.Execute(0, rlm, parameterChangeInfo.Params())
		if err != nil {
			return err
		}
	}

	return nil
}
