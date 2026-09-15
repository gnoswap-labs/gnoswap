package staker

import (
	"chain"
	"chain/runtime"
	"errors"
	"time"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"

	"gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
)

// Spoofed-realm guards on entry points reject any caller that fabricates a
// realm value distinct from the current crossing frame. The proxy in
// gno.land/r/gnoswap/gov/staker always forwards its own `cur`, so a mismatch
// here means somebody bypassed the proxy and threaded a fake realm directly
// into the implementation.

// Delegate delegates GNS tokens to an address.
//
// Converts GNS to xGNS and assigns voting power.
// Primary mechanism for participating in governance.
// Can delegate to self or any other address.
//
// Parameters:
//
//   - _: Noncrossing implementation-call discriminator; pass 0.
//
//   - rlm: Current realm context forwarded unchanged by the governance-staker proxy.
//
//   - to: Address to receive voting power (can be self)
//
//   - amount: Amount of GNS to stake and delegate
//
//   - referrer: Optional referral address for tracking
//
// Process:
//  1. Transfers GNS from caller
//  2. Mints equivalent xGNS (1:1 ratio)
//  3. Assigns voting power to target address
//  4. Creates delegation snapshot for voting
//
// Requirements:
//   - Minimum 1 GNS delegation
//   - Valid target address
//   - Sufficient GNS balance
//   - Approval for GNS transfer
//
// Returns:
//   - delegatedAmount: amount of GNS delegated and mirrored as xGNS
func (gs *govStakerV1) Delegate(
	_ int,
	rlm realm,
	to address,
	amount int64,
	referrer string,
) int64 {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedGovStaker()

	prev := rlm.Previous()
	access.AssertIsValidAddress(to)

	assertIsValidDelegateAmount(amount)

	caller := prev.Address()
	from := caller
	currentHeight := runtime.ChainHeight()
	currentTimestamp := time.Now().Unix()

	emission.MintAndDistributeGns(cross(rlm))

	delegation, err := gs.delegate(
		0,
		rlm,
		from,
		to,
		amount,
		currentHeight,
		currentTimestamp,
	)
	if err != nil {
		panic(err)
	}

	if err := gs.increaseTotalDelegatedAmount(0, rlm, amount); err != nil {
		panic(err)
	}
	if err := gs.increaseTotalLockedAmount(0, rlm, amount); err != nil {
		panic(err)
	}

	gns.TransferFrom(cross(rlm), from, rlm.Address(), amount)
	xgns.Mint(cross(rlm), from, amount)

	registeredReferrer := referral.TryRegister(cross(rlm), caller, referrer)

	resolver := NewDelegationResolver(delegation)

	chain.Emit(
		"Delegate",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
		"from", resolver.delegation.DelegateFrom().String(),
		"to", resolver.delegation.DelegateTo().String(),
		"amount", utils.FormatInt(resolver.DelegatedAmount()),
		"totalDelegatedAmount", utils.FormatInt(gs.store.GetTotalDelegatedAmount()),
		"referrer", registeredReferrer,
	)

	return amount
}

// Undelegate undelegates xGNS from the existing delegate.
//
// Initiates withdrawal of staked GNS with lockup period.
// Voting power removed immediately, tokens locked for configurable period.
// Prevents governance attacks through time delay.
//
// Parameters:
//
//   - _: Noncrossing implementation-call discriminator; pass 0.
//
//   - rlm: Current realm context forwarded unchanged by the governance-staker proxy.
//
//   - from: Address currently delegated to
//
//   - amount: Amount of xGNS to undelegate
//
// Process:
//  1. Removes voting power immediately
//  2. Creates withdrawal request with timestamp
//  3. Locks GNS for configurable cooldown period
//
// Requirements:
//   - Must have delegated to target address
//   - Sufficient delegated amount
//
// After lockup period ends, use CollectUndelegatedGns() to claim GNS.
//
// Returns:
//   - undelegatedAmount: amount moved out of active delegation into undelegation lockup
func (gs *govStakerV1) Undelegate(
	_ int,
	rlm realm,
	from address,
	amount int64,
) int64 {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	prev := rlm.Previous()
	caller := prev.Address()
	access.AssertIsValidAddress(from)

	assertIsValidDelegateAmount(amount)

	currentHeight := runtime.ChainHeight()
	currentTimestamp := time.Now().Unix()

	emission.MintAndDistributeGns(cross(rlm))

	unDelegationAmount, err := gs.unDelegate(
		0,
		rlm,
		caller,
		from,
		amount,
		currentHeight,
		currentTimestamp,
	)
	if err != nil {
		panic(err)
	}

	if err := gs.decreaseTotalDelegatedAmount(0, rlm, unDelegationAmount); err != nil {
		panic(err)
	}

	chain.Emit(
		"Undelegate",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
		"from", caller.String(),
		"to", from.String(),
		"amount", utils.FormatInt(unDelegationAmount),
		"totalDelegatedAmount", utils.FormatInt(gs.store.GetTotalDelegatedAmount()),
	)

	return unDelegationAmount
}

// Redelegate redelegates xGNS from an existing delegate to another.
//
// Atomic operation to change delegation target.
// Maintains voting power continuity without unstaking.
// Useful for vote delegation services and DAO coordination.
//
// Parameters:
//
//   - _: Noncrossing implementation-call discriminator; pass 0.
//
//   - rlm: Current realm context forwarded unchanged by the governance-staker proxy.
//
//   - delegatee: Current address delegated to
//
//   - newDelegatee: New address to delegate to
//
//   - amount: Amount of xGNS to redelegate
//
// Process:
//  1. Validates current delegation exists
//  2. Removes voting power from the old delegatee without a lockup
//  3. Assigns the same amount to the new delegatee
//  4. Updates delegation history and reward stake events
//
// Requirements:
//   - Must have active delegation to current delegatee
//   - Both addresses must be valid
//   - Amount must not exceed current delegation
//   - Cannot redelegate to same address
//
// No user-facing lockup period; reward accounting records one removal and one
// addition across the corresponding accrual epochs.
//
// Returns:
//   - redelegatedAmount: amount moved from the current delegatee to the new delegatee
func (gs *govStakerV1) Redelegate(
	_ int,
	rlm realm,
	delegatee,
	newDelegatee address,
	amount int64,
) int64 {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedGovStaker()

	prev := rlm.Previous()
	caller := prev.Address()
	access.AssertIsValidAddress(delegatee)
	access.AssertIsValidAddress(newDelegatee)

	assertIsValidDelegateAmount(amount)
	assertNoSameDelegatee(delegatee, newDelegatee)

	currentHeight := runtime.ChainHeight()
	currentTimestamp := time.Now().Unix()
	delegator := caller

	emission.MintAndDistributeGns(cross(rlm))

	unDelegationAmount, err := gs.unDelegateWithoutLockup(
		0,
		rlm,
		delegator,
		delegatee,
		amount,
		currentHeight,
		currentTimestamp,
	)
	if err != nil {
		panic(err)
	}

	delegation, err := gs.delegate(
		0,
		rlm,
		delegator,
		newDelegatee,
		unDelegationAmount,
		currentHeight,
		currentTimestamp,
	)
	if err != nil {
		panic(err)
	}

	resolver := NewDelegationResolver(delegation)
	chain.Emit(
		"Redelegate",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
		"from", delegator.String(),
		"previousDelegatee", delegatee.String(),
		"newDelegatee", newDelegatee.String(),
		"amount", utils.FormatInt(resolver.DelegatedAmount()),
	)

	return amount
}

// CollectUndelegatedGns collects undelegated GNS tokens.
// Allows users to collect GNS tokens that completed undelegation lockup period.
// Burns xGNS and returns GNS tokens.
//
// Parameters:
//   - _: Noncrossing implementation-call discriminator; pass 0.
//   - rlm: Current realm context forwarded unchanged by the governance-staker proxy.
//
// Returns:
//   - collectedAmount: amount of undelegated GNS released to the caller after lockup expiry
func (gs *govStakerV1) CollectUndelegatedGns(_ int, rlm realm) int64 {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	prev := rlm.Previous()
	caller := prev.Address()
	currentTime := time.Now().Unix()

	emission.MintAndDistributeGns(cross(rlm))

	collectedAmount, err := gs.collectDelegations(0, rlm, caller, currentTime)
	if err != nil {
		panic(err)
	}

	if collectedAmount == 0 {
		return 0
	}

	if err := gs.decreaseTotalLockedAmount(0, rlm, collectedAmount); err != nil {
		panic(err)
	}

	xgns.Burn(cross(rlm), caller, collectedAmount)
	gns.Transfer(cross(rlm), caller, collectedAmount)

	chain.Emit(
		"CollectUndelegatedGns",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
		"from", prev.Address().String(),
		"to", caller.String(),
		"collectedAmount", utils.FormatInt(collectedAmount),
	)

	return collectedAmount
}

// delegate processes delegation operations.
// Validates delegation amount, creates delegation records, and updates reward tracking.
// Parameters:
//   - _: leading realm-call discriminator for the internal helper; callers pass 0.
//   - rlm: forwarded realm context used by delegation and reward storage; downstream domain methods validate the current context.
//   - from: address whose tokens are being delegated.
//   - to: address receiving the delegated voting power.
//   - amount: GNS amount to record in the smallest token unit.
//   - currentHeight: block height recorded on the delegation.
//   - currentTimestamp: Unix timestamp in seconds recorded on the delegation and reward entries.
//
// Returns:
//   - *staker.Delegation: newly created delegation record.
//   - error: nil on success; otherwise a negative-amount or delegation/reward storage error.
func (gs *govStakerV1) delegate(
	_ int,
	rlm realm,
	from address,
	to address,
	amount,
	currentHeight,
	currentTimestamp int64,
) (*staker.Delegation, error) {
	delegationID := gs.nextDelegationID()
	delegation := staker.NewDelegation(
		delegationID,
		from,
		to,
		amount,
		currentHeight,
		currentTimestamp,
	)
	delegationResolver := NewDelegationResolver(delegation)
	delegatedAmount := delegationResolver.DelegatedAmount()
	if delegatedAmount < 0 {
		return nil, errors.New(errDelegatedAmountNegative)
	}

	if err := gs.addDelegation(0, rlm, delegationID, delegation); err != nil {
		return nil, err
	}
	gs.addDelegationRecord(0, rlm, to, delegatedAmount, currentTimestamp)
	if err := gs.addStakeEmissionReward(0, rlm, from.String(), amount, currentTimestamp); err != nil {
		return nil, err
	}
	if err := gs.addStakeProtocolFeeReward(0, rlm, from.String(), amount, currentTimestamp); err != nil {
		return nil, err
	}

	return delegation, nil
}

// unDelegate processes undelegation operations with lockup.
// Validates undelegation amount, processes withdrawals, and updates reward tracking.
// Parameters:
//   - _: leading realm-call discriminator for the internal helper; callers pass 0.
//   - rlm: forwarded realm context used by delegation and reward storage; downstream domain methods validate the current context.
//   - delegator: address whose delegation is being reduced.
//   - delegatee: address whose voting power is being reduced.
//   - amount: GNS amount to move into lockup, in the smallest token unit.
//   - currentHeight: block height recorded on withdrawal entries.
//   - currentTimestamp: Unix timestamp in seconds used to start each lockup.
//
// Returns:
//   - int64: requested amount accepted for undelegation, or zero when no delegation IDs exist.
//   - error: nil on success; otherwise insufficient delegation, invalid amount, or storage/reward update error.
func (gs *govStakerV1) unDelegate(
	_ int,
	rlm realm,
	delegator,
	delegatee address,
	amount,
	currentHeight,
	currentTimestamp int64,
) (int64, error) {
	delegationIDs := gs.getUserDelegationIDsWithDelegatee(delegator, delegatee)
	if len(delegationIDs) == 0 {
		return 0, nil
	}

	unDelegationAmount := amount
	lockupPeriod := gs.store.GetUnDelegationLockupPeriod()
	totalDelegated := int64(0)
	delegations := make([]*staker.Delegation, 0, len(delegationIDs))

	for _, id := range delegationIDs {
		delegation, exists := gs.store.GetDelegation(id)
		if !exists {
			continue
		}

		totalDelegated = gnsmath.SafeAddInt64(totalDelegated, NewDelegationResolver(delegation).DelegatedAmount())
		delegations = append(delegations, delegation)
	}

	if amount > totalDelegated {
		return 0, errors.New(errNotEnoughDelegated)
	}

	// Process undelegation across multiple delegation records if necessary
	for _, delegation := range delegations {
		resolver := NewDelegationResolver(delegation)
		if resolver.IsEmpty() {
			if err := gs.removeDelegation(0, rlm, delegation.ID()); err != nil {
				return 0, err
			}
			continue
		}

		currentUnDelegationAmount := unDelegationAmount

		if currentUnDelegationAmount > resolver.DelegatedAmount() {
			currentUnDelegationAmount = resolver.DelegatedAmount()
		}

		if currentUnDelegationAmount < 0 {
			return 0, errors.New(errUndelegationAmountNegative)
		}

		if currentUnDelegationAmount == 0 {
			continue
		}

		resolver.UnDelegate(
			currentUnDelegationAmount,
			currentHeight,
			currentTimestamp,
			lockupPeriod,
		)

		if err := gs.setDelegation(0, rlm, delegation.ID(), delegation); err != nil {
			return 0, err
		}
		gs.addDelegationRecord(0, rlm, delegatee, -currentUnDelegationAmount, currentTimestamp)
		if err := gs.removeStakeEmissionReward(0, rlm, delegator.String(), currentUnDelegationAmount, currentTimestamp); err != nil {
			return 0, err
		}
		if err := gs.removeStakeProtocolFeeReward(0, rlm, delegator.String(), currentUnDelegationAmount, currentTimestamp); err != nil {
			return 0, err
		}

		unDelegationAmount = gnsmath.SafeSubInt64(unDelegationAmount, currentUnDelegationAmount)
		if unDelegationAmount <= 0 {
			break
		}
	}

	return amount, nil
}

// unDelegateWithoutLockup processes undelegation without lockup.
// Used for redelegation where tokens are immediately available.
// Parameters:
//   - _: leading realm-call discriminator for the internal helper; callers pass 0.
//   - rlm: forwarded realm context used by delegation and reward storage; downstream domain methods validate the current context.
//   - delegator: address whose delegation is being reduced.
//   - delegatee: address whose voting power is being reduced.
//   - amount: GNS amount to remove immediately, in the smallest token unit.
//   - currentHeight: block height recorded on the delegation update.
//   - currentTime: Unix timestamp in seconds used for reward and delegation history updates.
//
// Returns:
//   - int64: requested amount accepted for immediate undelegation.
//   - error: nil on success; otherwise insufficient delegation or storage/reward update error.
func (gs *govStakerV1) unDelegateWithoutLockup(
	_ int,
	rlm realm,
	delegator,
	delegatee address,
	amount,
	currentHeight,
	currentTime int64,
) (int64, error) {
	delegationIDs := gs.getUserDelegationIDsWithDelegatee(delegator, delegatee)
	if len(delegationIDs) == 0 {
		return 0, errors.New(errNotEnoughDelegated)
	}

	unDelegationAmount := amount
	totalDelegated := int64(0)
	delegations := make([]*staker.Delegation, 0, len(delegationIDs))

	for _, id := range delegationIDs {
		delegation, exists := gs.store.GetDelegation(id)
		if !exists {
			continue
		}

		totalDelegated = gnsmath.SafeAddInt64(totalDelegated, NewDelegationResolver(delegation).DelegatedAmount())
		delegations = append(delegations, delegation)
	}

	if amount > totalDelegated {
		return 0, errors.New(errNotEnoughDelegated)
	}

	// Process undelegation across multiple delegation records if necessary
	for _, delegation := range delegations {
		resolver := NewDelegationResolver(delegation)
		if resolver.IsEmpty() {
			if err := gs.removeDelegation(0, rlm, delegation.ID()); err != nil {
				return 0, err
			}
			continue
		}

		currentUnDelegationAmount := unDelegationAmount

		if currentUnDelegationAmount > resolver.DelegatedAmount() {
			currentUnDelegationAmount = resolver.DelegatedAmount()
		}

		if currentUnDelegationAmount == 0 {
			continue
		}

		resolver.UnDelegateWithoutLockup(
			currentUnDelegationAmount,
			currentHeight,
			currentTime,
		)

		if resolver.IsEmpty() {
			if err := gs.removeDelegation(0, rlm, delegation.ID()); err != nil {
				return 0, err
			}
		} else if err := gs.setDelegation(0, rlm, delegation.ID(), delegation); err != nil {
			return 0, err
		}
		gs.addDelegationRecord(0, rlm, delegatee, -currentUnDelegationAmount, currentTime)
		if err := gs.removeStakeEmissionReward(0, rlm, delegator.String(), currentUnDelegationAmount, currentTime); err != nil {
			return 0, err
		}
		if err := gs.removeStakeProtocolFeeReward(0, rlm, delegator.String(), currentUnDelegationAmount, currentTime); err != nil {
			return 0, err
		}

		unDelegationAmount = gnsmath.SafeSubInt64(unDelegationAmount, currentUnDelegationAmount)
		if unDelegationAmount <= 0 {
			break
		}
	}

	return amount, nil
}

// increaseTotalDelegatedAmount adds an amount to the persisted active-delegation total.
//
// Parameters:
//   - _: leading realm-call discriminator for the internal helper; callers pass 0.
//   - rlm: forwarded realm context for the total-delegation store update; the store validates the current context.
//   - amount: delegation amount to add, in the smallest token unit.
//
// Returns:
//   - error: nil when the total is stored; otherwise the underlying store update error.
func (gs *govStakerV1) increaseTotalDelegatedAmount(_ int, rlm realm, amount int64) error {
	currentDelegated := gs.store.GetTotalDelegatedAmount()

	if err := gs.store.SetTotalDelegatedAmount(0, rlm, gnsmath.SafeAddInt64(currentDelegated, amount)); err != nil {
		return err
	}

	return nil
}

// decreaseTotalDelegatedAmount subtracts an amount and clamps the stored total at zero.
//
// Parameters:
//   - _: leading realm-call discriminator for the internal helper; callers pass 0.
//   - rlm: forwarded realm context for the total-delegation store update; the store validates the current context.
//   - amount: delegation amount to subtract, in the smallest token unit.
//
// Returns:
//   - error: nil when the clamped total is stored; otherwise the underlying store update error.
func (gs *govStakerV1) decreaseTotalDelegatedAmount(_ int, rlm realm, amount int64) error {
	currentDelegated := gs.store.GetTotalDelegatedAmount()

	newDelegated := gnsmath.SafeSubInt64(currentDelegated, amount)
	if newDelegated < 0 {
		newDelegated = 0
	}
	if err := gs.store.SetTotalDelegatedAmount(0, rlm, newDelegated); err != nil {
		return err
	}

	return nil
}

// increaseTotalLockedAmount adds an amount to the persisted locked-total value.
//
// Parameters:
//   - _: leading realm-call discriminator for the internal helper; callers pass 0.
//   - rlm: forwarded realm context for the total-locked store update; the store validates the current context.
//   - amount: locked amount to add, in the smallest token unit.
//
// Returns:
//   - error: nil when the total is stored; otherwise the underlying store update error.
func (gs *govStakerV1) increaseTotalLockedAmount(_ int, rlm realm, amount int64) error {
	currentLocked := gs.store.GetTotalLockedAmount()

	if err := gs.store.SetTotalLockedAmount(0, rlm, gnsmath.SafeAddInt64(currentLocked, amount)); err != nil {
		return err
	}

	return nil
}

// decreaseTotalLockedAmount subtracts an amount and clamps the stored total at zero.
//
// Parameters:
//   - _: leading realm-call discriminator for the internal helper; callers pass 0.
//   - rlm: forwarded realm context for the total-locked store update; the store validates the current context.
//   - amount: locked amount to subtract, in the smallest token unit.
//
// Returns:
//   - error: nil when the clamped total is stored; otherwise the underlying store update error.
func (gs *govStakerV1) decreaseTotalLockedAmount(_ int, rlm realm, amount int64) error {
	currentLocked := gs.store.GetTotalLockedAmount()

	newLocked := gnsmath.SafeSubInt64(currentLocked, amount)
	if newLocked < 0 {
		newLocked = 0
	}
	if err := gs.store.SetTotalLockedAmount(0, rlm, newLocked); err != nil {
		return err
	}

	return nil
}

// collectDelegations processes collection of undelegated tokens.
// Iterates through user delegations and collects available amounts.
// Parameters:
//   - _: leading realm-call discriminator for the internal helper; callers pass 0.
//   - rlm: forwarded realm context used while persisting collected delegation records; downstream storage validates the current context.
//   - user: address whose matured delegation withdrawals are collected.
//   - currentTime: Unix timestamp in seconds used to determine which withdrawals have matured.
//
// Returns:
//   - int64: total GNS amount collected from all matured withdrawals.
//   - error: nil on success; otherwise an invalid-amount or delegation storage error.
func (gs *govStakerV1) collectDelegations(_ int, rlm realm, user address, currentTime int64) (int64, error) {
	totalCollectedAmount := int64(0)

	delegationTree := gs.getUserDelegations(user)

	var err error
	var idsToRemove []int64
	allDelegations := gs.store.GetAllDelegations()

	// Collect from all available delegations
	delegationTree.Iterate("", "", func(delegatee string, value any) bool {
		delegationIDs, ok := value.([]int64)
		if !ok {
			return false
		}

		if len(delegationIDs) == 0 {
			return false
		}
		for _, id := range delegationIDs {
			delegationRaw := allDelegations.Get(utils.FormatInt(id))
			if delegationRaw == nil {
				continue
			}
			delegation, ok := delegationRaw.(*staker.Delegation)
			if !ok {
				continue
			}

			resolver := NewDelegationResolver(delegation)

			collectedAmount, iErr := resolver.processCollection(currentTime)
			if iErr != nil {
				err = iErr
				return true
			}

			// Simple addition since addToCollectedAmount was removed
			totalCollectedAmount = gnsmath.SafeAddInt64(totalCollectedAmount, collectedAmount)

			// Save updated delegation state after collection
			if resolver.IsEmpty() {
				idsToRemove = append(idsToRemove, delegation.ID())
			} else {
				if iErr := gs.setDelegation(0, rlm, delegation.ID(), delegation); iErr != nil {
					err = iErr
					return true
				}
			}
		}

		return false
	})

	if err != nil {
		return totalCollectedAmount, makeErrorWithDetails(errInvalidAmount, err.Error())
	}

	for _, id := range idsToRemove {
		if err := gs.removeDelegation(0, rlm, id); err != nil {
			return totalCollectedAmount, err
		}
	}

	return totalCollectedAmount, nil
}
