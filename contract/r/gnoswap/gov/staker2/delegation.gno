package staker2

import (
	"std"
)

// validateDelegation checks if a delegation is valid according to DoS protection rules
func validateDelegation(staker *StakerState, to std.Address, amount uint64) error {
	// Check self-delegation
	if staker.Address == to {
		return ErrSelfDelegation
	}

	// Check if it's a new delegation or adding to existing
	if _, exists := staker.Delegations[to]; exists {
		// Adding to existing delegation - check minimum increment
		if amount < MIN_DELEGATION_INCREMENT {
			return ErrInsufficientIncrement
		}
	} else {
		// New delegation - check minimum per address and max delegations
		if amount < MIN_DELEGATION_PER_ADDRESS {
			return ErrInsufficientDelegation
		}
		if len(staker.Delegations) >= MAX_DELEGATIONS_PER_USER {
			return ErrTooManyDelegations
		}
	}

	return nil
}

// addDelegation adds a delegation to the staker state
func addDelegation(staker *StakerState, to std.Address, amount uint64, currentEpoch uint64) error {
	// Validate first
	if err := validateDelegation(staker, to, amount); err != nil {
		return err
	}

	// Add or update delegation
	if existing, exists := staker.Delegations[to]; exists {
		// Update existing delegation
		existing.Amount += amount
		staker.Delegations[to] = existing
	} else {
		// Create new delegation
		staker.Delegations[to] = DelegationInfo{
			Amount:     amount,
			StartEpoch: currentEpoch,
		}
	}

	// Update total staked
	staker.TotalStaked += amount
	staker.LastUpdateEpoch = currentEpoch

	return nil
}

// removeDelegation removes a delegation from the staker state
func removeDelegation(staker *StakerState, from std.Address, amount uint64) (uint64, error) {
	delegation, exists := staker.Delegations[from]
	if !exists {
		return 0, ErrNoDelegation
	}

	// Calculate actual amount to remove (cap at delegation amount)
	removeAmount := amount
	if removeAmount > delegation.Amount {
		removeAmount = delegation.Amount
	}

	// Update delegation
	delegation.Amount -= removeAmount
	if delegation.Amount == 0 {
		// Remove delegation entirely if amount is 0
		delete(staker.Delegations, from)
	} else {
		// Update with reduced amount
		staker.Delegations[from] = delegation
	}

	// Update total staked
	staker.TotalStaked -= removeAmount

	return removeAmount, nil
}
