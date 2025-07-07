package governance

import (
	"errors"
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	gs "gno.land/r/gnoswap/v1/gov/staker"
	"gno.land/r/gnoswap/v1/gov/xgns"
)

// Transition represents a function that transforms governance state
// It returns the new state and any error that occurred
type Transition func(*GovernanceState) (*GovernanceState, error)

// TransitionResult contains the result of a state transition
type TransitionResult struct {
	State *GovernanceState
	Error error
}

// Compose combines multiple state transitions into a single transition
// Transitions are applied in order, and if any fails, the entire composition fails
func Compose(transitions ...Transition) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		current := s
		for i, transition := range transitions {
			next, err := transition(current)
			if err != nil {
				return s, ufmt.Errorf("transition %d failed: %v", i, err)
			}
			current = next
		}
		return current, nil
	}
}

// Conditional applies a transition only if the condition is true
func Conditional(condition func(*GovernanceState) bool, transition Transition) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		if condition(s) {
			return transition(s)
		}
		return s, nil
	}
}

// Try attempts a transition and returns the original state if it fails
func Try(transition Transition) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		newState, err := transition(s)
		if err != nil {
			return s, nil // Return original state, no error
		}
		return newState, nil
	}
}

// Map applies a transition to each element that matches a condition
func Map(selector func(*GovernanceState, uint64) bool, transition Transition) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		current := s
		var err error

		s.IterateProposals(func(id uint64, _ ProposalInfo) bool {
			if selector(s, id) {
				current, err = transition(current)
				if err != nil {
					return true // Stop iteration on error
				}
			}
			return false
		})

		if err != nil {
			return s, err
		}
		return current, nil
	}
}

// Validate ensures the state meets certain conditions after transition
func Validate(transition Transition, validator func(*GovernanceState) error) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		newState, err := transition(s)
		if err != nil {
			return s, err
		}

		if err := validator(newState); err != nil {
			return s, ufmt.Errorf("validation failed: %v", err)
		}

		return newState, nil
	}
}

// Specific state transitions for governance operations

// CreateProposalTransition creates a new proposal
func CreateProposalTransition(proposer std.Address, proposalType ProposalType, title, description string) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		// Check if proposer can create proposal
		if !s.CanPropose(proposer) {
			return s, errAlreadyActiveProposal
		}

		// ref: https://docs.gnoswap.io/core-concepts/governance#scope-of-proposals-5
		xGnsBalance := xgns.BalanceOf(proposer)
		threshold := s.currentConfig.ProposalCreationThreshold
		if xGnsBalance < int64(threshold) {
			return s, ufmt.Errorf("insufficient xGNS balance: %d < %d", xGnsBalance, threshold)
		}

		// Calculate voting weight
		now := uint64(time.Now().Unix())
		smoothingDuration := s.currentConfig.VotingWeightSmoothingDuration
		votingMax, possibleAddresses := gs.GetPossibleVotingAddressWithWeight(now - smoothingDuration)

		maxVotingWeight := u256.NewUint(votingMax)
		quorumAmount := maxVotingWeight.Uint64() * s.currentConfig.Quorum / 100

		// Create proposal with pre-calculated schedule
		schedule := createProposalSchedule(s.currentConfig, now)
		proposal := ProposalInfo{
			Proposer:     proposer,
			ProposalType: proposalType,
			State: ProposalState{
				Created:   true,
				CreatedAt: now,
				Upcoming:  true,
			},
			Schedule:    schedule,
			ActionState: ActionState{}, // Empty action state for new proposal
			Status: ProposalStatus{
				Schedule:    schedule,
				ActionState: ActionState{}, // Empty action state for new proposal
			},
			Yea:                       u256.Zero(),
			Nay:                       u256.Zero(),
			MaxVotingWeight:           maxVotingWeight,
			PossibleAddressWithWeight: possibleAddresses,
			ConfigVersion:             s.configCounter,
			QuorumAmount:              quorumAmount,
			Title:                     title,
			Description:               description,
		}

		return s.WithNewProposal(proposer, proposal), nil
	}
}

// CastVoteTransition records a vote on a proposal
func CastVoteTransition(proposalId uint64, voter std.Address, vote bool) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		// Check if proposal exists
		proposal, exists := s.GetProposal(proposalId)
		if !exists {
			return s, errProposalNotFound
		}

		// Check if already voted
		if s.HasVoted(proposalId, voter) {
			return s, errAlreadyVoted
		}

		// Check voting period
		now := uint64(time.Now().Unix())
		
		// Priority 1: Use Status.Schedule if available
		if proposal.Status.Schedule.CreateTime != 0 {
			if !proposal.Status.Schedule.IsVotingPeriod(now) {
				return s, errUnableToVoteOutOfPeriod
			}
			// Check if proposal is canceled
			if proposal.Status.ActionState.IsCanceled() {
				return s, errUnableToVoteCanceledProposal
			}
		} else {
			// Fallback: Use State field
			config, _ := s.GetConfig(proposal.ConfigVersion)
			votingStart := proposal.State.CreatedAt + config.VotingStartDelay
			votingEnd := votingStart + config.VotingPeriod

			if now < votingStart || now >= votingEnd {
				return s, errUnableToVoteOutOfPeriod
			}
			// Check if proposal is canceled
			if proposal.ActionState.IsCanceled() {
				return s, errUnableToVoteCanceledProposal
			}
		}

		// Get voter weight
		weight := proposal.PossibleAddressWithWeight[voter]
		if weight == 0 {
			return s, errNotEnoughVotingWeight
		}

		return s.WithVote(proposalId, voter, vote, weight), nil
	}
}

// UpdateProposalStateTransition2 updates proposal states based on current time
func UpdateProposalStateTransition() Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		now := uint64(time.Now().Unix())
		current := s

		s.IterateProposals(func(id uint64, proposal ProposalInfo) bool {
			// Skip if already terminated
			if isTerminated(&proposal) {
				return false
			}

			config, _ := s.GetConfig(proposal.ConfigVersion)
			updater := newProposalStateUpdater(&proposal, now)
			updater.config = config

			if updater.shouldUpdate() {
				updater.update()
				current = current.WithUpdatedProposal(id, func(_ ProposalInfo) ProposalInfo {
					return *updater.proposal
				})
			}

			// Archive if terminated
			if isTerminated(updater.proposal) {
				current = current.WithArchivedProposal(id)
			}

			return false
		})

		return current, nil
	}
}

// ExecuteProposalTransition executes a proposal
func ExecuteProposalTransition(proposalId uint64) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		proposal, exists := s.GetProposal(proposalId)
		if !exists {
			return s, errProposalNotFound
		}

		// Validate proposal can be executed
		if proposal.ProposalType == Text {
			return s, errTextProposalNotExecutable
		}

		// Check ActionState first
		if proposal.Status.Schedule.CreateTime != 0 {
			if proposal.Status.ActionState.IsActionTaken() {
				return s, errProposalNotExecutable
			}
		} else if proposal.ActionState.IsActionTaken() {
			return s, errProposalNotExecutable
		}

		// Check proposal status
		updater := newProposalStateUpdater(&proposal, uint64(time.Now().Unix()))
		status := updater.getCurrentStatus()
		
		if status == StatusRejected {
			return s, errProposalNotExecutable
		}

		if status != StatusPassed {
			return s, errProposalNotPassed
		}

		// Check execution window using Schedule
		now := uint64(time.Now().Unix())

		// Priority 1: Use Status.Schedule if available
		if proposal.Status.Schedule.CreateTime != 0 {
			if now < proposal.Status.Schedule.ExecutableTime {
				return s, errExecutionWindowNotStarted
			}
			if now >= proposal.Status.Schedule.ExpiredTime {
				return s, errors.New("execution window expired")
			}
		} else if proposal.Schedule.CreateTime != 0 {
			// Priority 2: Use Schedule field if available
			if now < proposal.Schedule.ExecutableTime {
				return s, errExecutionWindowNotStarted
			}
			if now >= proposal.Schedule.ExpiredTime {
				return s, errors.New("execution window expired")
			}
		} else {
			// Fallback for proposals without Schedule
			config, _ := s.GetConfig(proposal.ConfigVersion)
			votingEnd := proposal.State.CreatedAt + config.VotingStartDelay + config.VotingPeriod
			windowStart := votingEnd + config.ExecutionDelay
			windowEnd := windowStart + config.ExecutionWindow

			if now < windowStart {
				return s, errExecutionWindowNotStarted
			}
			if now >= windowEnd {
				return s, errors.New("execution window expired")
			}
		}

		// Update proposal state with ActionState
		executor := std.PreviousRealm().Address()
		return s.WithUpdatedProposal(proposalId, func(p ProposalInfo) ProposalInfo {
			// Update ActionState
			p.ActionState.Executed = true
			p.ActionState.ExecutedAt = now
			p.ActionState.ExecutedBy = executor

			// Update Status.ActionState
			p.Status.ActionState.Executed = true
			p.Status.ActionState.ExecutedAt = now
			p.Status.ActionState.ExecutedBy = executor

			// Update legacy State for backward compatibility
			p.State.Executed = true
			p.State.ExecutedAt = now
			p.State.Upcoming = false
			p.State.Active = false
			return p
		}), nil
	}
}

// ReconfigureTransition updates the governance configuration
func ReconfigureTransition(newConfig Config) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		return s.WithNewConfig(newConfig), nil
	}
}

// Helper function to check if proposal is terminated
func isTerminated(proposal *ProposalInfo) bool {
	// Priority 1: Check Status.ActionState if available
	if proposal.Status.Schedule.CreateTime != 0 {
		if proposal.Status.ActionState.IsActionTaken() {
			return true
		}
		// Check if proposal status is terminal by getting current status
		updater := newProposalStateUpdater(proposal, uint64(time.Now().Unix()))
		status := updater.getCurrentStatus()
		return status.IsTerminated()
	}
	
	// Fallback: Check ActionState first (takes priority)
	if proposal.ActionState.IsActionTaken() {
		return true
	}
	// Then check time-based terminal states
	return proposal.State.Expired || proposal.State.Rejected
}

// Batch operations using state transitions

// ProcessAllProposals updates all proposal states
func ProcessAllProposals() Transition {
	return UpdateProposalStateTransition()
}

// CreateAndValidateProposal creates a proposal with validation
func CreateAndValidateProposal(proposer std.Address, proposalType ProposalType, title, description string) Transition {
	return Validate(
		CreateProposalTransition(proposer, proposalType, title, description),
		func(s *GovernanceState) error {
			// Validate the proposal was created
			proposalId, exists := s.GetProposalByProposer(proposer)
			if !exists {
				return errors.New("proposal creation failed")
			}

			proposal, exists := s.GetProposal(proposalId)
			if !exists {
				return errors.New("proposal not found")
			}

			if proposal.Title != title {
				return errors.New("proposal title mismatch")
			}

			return nil
		},
	)
}

// VoteTransition creates a state transition for casting a vote
func VoteTransition(proposalId uint64, voter std.Address, vote bool) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		proposal, exists := s.GetProposal(proposalId)
		if !exists {
			return s, errProposalNotFound
		}

		// Check if already voted
		if s.HasVoted(proposalId, voter) {
			return s, errAlreadyVoted
		}

		// Validate voting period using Schedule
		now := uint64(time.Now().Unix())

		// Priority 1: Use Status.Schedule if available
		if proposal.Status.Schedule.CreateTime != 0 {
			if !proposal.Status.Schedule.IsVotingPeriod(now) {
				return s, errUnableToVoteOutOfPeriod
			}
			// Check if proposal is canceled
			if proposal.Status.ActionState.IsCanceled() {
				return s, errUnableToVoteCanceledProposal
			}
		} else if proposal.Schedule.CreateTime != 0 {
			// Priority 2: Use Schedule field if available
			if !proposal.Schedule.IsVotingPeriod(now) {
				return s, errUnableToVoteOutOfPeriod
			}
			// Check if proposal is canceled
			if proposal.ActionState.IsCanceled() {
				return s, errUnableToVoteCanceledProposal
			}
		} else {
			// Fallback for proposals without Schedule
			config, _ := s.GetConfig(proposal.ConfigVersion)
			votingStart := proposal.State.CreatedAt + config.VotingStartDelay
			votingEnd := votingStart + config.VotingPeriod

			if now < votingStart || now >= votingEnd {
				return s, errUnableToVoteOutOfPeriod
			}
			// Check if proposal is canceled
			if proposal.ActionState.IsCanceled() {
				return s, errUnableToVoteCanceledProposal
			}
		}

		// Get voting weight
		weight, exists := proposal.PossibleAddressWithWeight[voter]
		if !exists || weight == 0 {
			return s, errNotEnoughVotingWeight
		}

		// Cast vote
		return s.WithVote(proposalId, voter, vote, weight), nil
	}
}

// VoteWithUpdate composes state update and vote in a single transition
func VoteWithUpdate(proposalId uint64, voter std.Address, vote bool) Transition {
	return Compose(
		UpdateProposalStateTransition(),
		VoteTransition(proposalId, voter, vote),
	)
}

// CancelProposalTransition cancels a proposal
func CancelProposalTransition(proposalId uint64, caller std.Address) Transition {
	return func(s *GovernanceState) (*GovernanceState, error) {
		proposal, exists := s.GetProposal(proposalId)
		if !exists {
			return s, errProposalNotFound
		}

		// Check if already canceled
		if proposal.Status.Schedule.CreateTime != 0 {
			if proposal.Status.ActionState.IsCanceled() {
				return s, errAlreadyCanceledProposal
			}
		} else if proposal.ActionState.IsCanceled() {
			return s, errAlreadyCanceledProposal
		}

		// Check if voting has started using Schedule
		now := uint64(time.Now().Unix())

		// Priority 1: Use Status.Schedule if available
		if proposal.Status.Schedule.CreateTime != 0 {
			if now >= proposal.Status.Schedule.ActiveTime {
				return s, errUnableToCancleVotingProposal
			}
		} else if proposal.Schedule.CreateTime != 0 {
			// Priority 2: Use Schedule field if available
			if now >= proposal.Schedule.ActiveTime {
				return s, errUnableToCancleVotingProposal
			}
		} else {
			// Fallback for proposals without Schedule
			config, _ := s.GetConfig(proposal.ConfigVersion)
			votingStart := proposal.State.CreatedAt + config.VotingStartDelay

			if now >= votingStart {
				return s, errUnableToCancleVotingProposal
			}
		}

		// Get config for threshold check
		config, _ := s.GetConfig(proposal.ConfigVersion)

		// Check if caller is authorized to cancel
		if caller != proposal.Proposer {
			// Check if proposer's stake has fallen below threshold
			balance := xgns.BalanceOf(proposal.Proposer)
			threshold := config.ProposalCreationThreshold

			if balance >= int64(threshold) {
				return s, errUnableToCancelProposalWithVoterEnoughDelegated
			}
		}

		// Cancel the proposal with ActionState
		return s.WithUpdatedProposal(proposalId, func(p ProposalInfo) ProposalInfo {
			// Update ActionState
			p.ActionState.Canceled = true
			p.ActionState.CanceledAt = now
			p.ActionState.CanceledBy = caller

			// Update Status.ActionState
			p.Status.ActionState.Canceled = true
			p.Status.ActionState.CanceledAt = now
			p.Status.ActionState.CanceledBy = caller

			// Update legacy State for backward compatibility
			p.State.Canceled = true
			p.State.CanceledAt = now
			p.State.Upcoming = false
			p.State.Active = false
			return p
		}).WithArchivedProposal(proposalId), nil
	}
}

// VoteWithRetry attempts to cast a vote with retry logic
func VoteWithRetry(proposalId uint64, voter std.Address, vote bool) Transition {
	return Compose(
		Try(UpdateProposalStateTransition()), // Update states first
		CastVoteTransition(proposalId, voter, vote),
	)
}
