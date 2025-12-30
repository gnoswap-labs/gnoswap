package v1

import (
	"chain"
	"chain/runtime"
	"errors"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
)

// Delegate delegates GNS tokens to an address.
//
// Converts GNS to xGNS and assigns voting power.
// Primary mechanism for participating in governance.
// Can delegate to self or any other address.
//
// Parameters:
//   - to: Address to receive voting power (can be self)
//   - amount: Amount of GNS to stake and delegate
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
// Returns delegated amount.
func (gs *govStakerV1) Delegate(
	to address,
	amount int64,
	referrer string,
) int64 {
	halt.AssertIsNotHaltedGovStaker()

	prevRealm := runtime.PreviousRealm()
	access.AssertIsUser(prevRealm)
	access.AssertIsValidAddress(to)

	assertIsValidDelegateAmount(amount)

	caller := prevRealm.Address()
	from := caller
	currentRealm := runtime.CurrentRealm()
	currentHeight := runtime.ChainHeight()
	currentTimestamp := time.Now().Unix()

	emission.MintAndDistributeGns(cross)

	delegation, err := gs.delegate(
		from,
		to,
		amount,
		currentHeight,
		currentTimestamp,
	)
	if err != nil {
		panic(err)
	}

	gns.TransferFrom(cross, from, currentRealm.Address(), amount)
	xgns.Mint(cross, from, amount)

	registeredReferrer := registerReferrer(caller, referrer)

	resolver := NewDelegationResolver(delegation)

	chain.Emit(
		"Delegate",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"from", resolver.delegation.DelegateFrom().String(),
		"to", resolver.delegation.DelegateTo().String(),
		"amount", formatInt(resolver.DelegatedAmount()),
		"referrer", registeredReferrer,
	)

	return amount
}

// Undelegate undelegates xGNS from the existing delegate.
//
// Initiates withdrawal of staked GNS with lockup period.
// Voting power removed immediately, tokens locked for 7 days.
// Prevents governance attacks through time delay.
//
// Parameters:
//   - from: Address currently delegated to
//   - amount: Amount of xGNS to undelegate
//
// Process:
//  1. Removes voting power immediately
//  2. Burns xGNS tokens
//  3. Creates withdrawal request with timestamp
//  4. Locks GNS for 7-day cooldown period
//
// Requirements:
//   - Must have delegated to target address
//   - Sufficient delegated amount
//   - Cannot undelegate during active votes
//
// After 7 days, use Collect() to claim GNS.
// Returns undelegated amount.
func (gs *govStakerV1) Undelegate(
	from address,
	amount int64,
) int64 {
	halt.AssertIsNotHaltedGovStaker()

	prevRealm := runtime.PreviousRealm()
	caller := prevRealm.Address()
	access.AssertIsValidAddress(from)

	assertIsValidDelegateAmount(amount)

	currentHeight := runtime.ChainHeight()
	currentTimestamp := time.Now().Unix()

	emission.MintAndDistributeGns(cross)

	unDelegationAmount, err := gs.unDelegate(
		caller,
		from,
		amount,
		currentHeight,
		currentTimestamp,
	)
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"Undelegate",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"from", caller.String(),
		"to", from.String(),
		"amount", formatInt(unDelegationAmount),
	)

	return unDelegationAmount
}

// Redelegate redelegates xGNS from existing delegate to another.
//
// Atomic operation to change delegation target.
// Maintains voting power continuity without unstaking.
// Useful for vote delegation services and dao coordination.
//
// Parameters:
//   - delegatee: Current address delegated to
//   - newDelegatee: New address to delegate to
//   - amount: Amount of xGNS to redelegate
//
// Process:
//  1. Validates current delegation exists
//  2. Removes voting power from old delegatee
//  3. Assigns voting power to new delegatee
//  4. Updates delegation snapshots
//
// Requirements:
//   - Must have active delegation to current delegatee
//   - Both addresses must be valid
//   - Amount must not exceed current delegation
//   - Cannot redelegate to same address
//
// No lockup period - instant redelegation.
// Returns redelegated amount.
func (gs *govStakerV1) Redelegate(
	delegatee,
	newDelegatee address,
	amount int64,
) int64 {
	halt.AssertIsNotHaltedGovStaker()

	prevRealm := runtime.PreviousRealm()
	caller := prevRealm.Address()
	access.AssertIsValidAddress(delegatee)
	access.AssertIsValidAddress(newDelegatee)

	assertIsValidDelegateAmount(amount)

	currentHeight := runtime.ChainHeight()
	currentTimestamp := time.Now().Unix()
	delegator := caller

	emission.MintAndDistributeGns(cross)

	unDelegationAmount, err := gs.unDelegateWithoutLockup(
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
		delegator,
		newDelegatee,
		unDelegationAmount,
		currentHeight,
		currentTimestamp,
	)

	resolver := NewDelegationResolver(delegation)
	chain.Emit(
		"Redelegate",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"from", delegator.String(),
		"previousDelegatee", delegatee.String(),
		"newDelegatee", newDelegatee.String(),
		"amount", formatInt(resolver.DelegatedAmount()),
	)

	return amount
}

// CollectUndelegatedGns collects undelegated GNS tokens.
// Allows users to collect GNS tokens that completed undelegation lockup period.
// Burns xGNS and returns GNS tokens.
func (gs *govStakerV1) CollectUndelegatedGns() int64 {
	halt.AssertIsNotHaltedGovStaker()
	halt.AssertIsNotHaltedWithdraw()

	prevRealm := runtime.PreviousRealm()
	caller := prevRealm.Address()
	currentTime := time.Now().Unix()

	emission.MintAndDistributeGns(cross)

	collectedAmount, err := gs.collectDelegations(caller, currentTime)
	if err != nil {
		panic(err)
	}

	if collectedAmount == 0 {
		return 0
	}

	xgns.Burn(cross, caller, collectedAmount)
	gns.Transfer(cross, caller, collectedAmount)

	// Update total locked amount directly in store
	currentLocked := gs.store.GetTotalLockedAmount()

	newLocked := safeSubInt64(currentLocked, collectedAmount)
	if newLocked < 0 {
		newLocked = 0
	}
	if err := gs.store.SetTotalLockedAmount(newLocked); err != nil {
		panic(err)
	}

	chain.Emit(
		"CollectUndelegatedGns",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"from", prevRealm.Address().String(),
		"to", caller.String(),
		"collectedAmount", formatInt(collectedAmount),
	)

	return collectedAmount
}

// delegate processes delegation operations.
// Validates delegation amount, creates delegation records, and updates reward tracking.
func (gs *govStakerV1) delegate(
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
		return nil, errors.New("delegated amount cannot be negative")
	}

	gs.addDelegation(delegationID, delegation)
	gs.addDelegationRecord(to, delegatedAmount, currentTimestamp)
	gs.addStakeEmissionReward(from.String(), amount, currentTimestamp)
	gs.addStakeProtocolFeeReward(from.String(), amount, currentTimestamp)

	// Update total amounts directly in store
	currentDelegated := gs.store.GetTotalDelegatedAmount()

	if err := gs.store.SetTotalDelegatedAmount(safeAddInt64(currentDelegated, amount)); err != nil {
		panic(err)
	}

	currentLocked := gs.store.GetTotalLockedAmount()

	if err := gs.store.SetTotalLockedAmount(safeAddInt64(currentLocked, amount)); err != nil {
		panic(err)
	}

	return delegation, nil
}

// unDelegate processes undelegation operations with lockup.
// Validates undelegation amount, processes withdrawals, and updates reward tracking.
func (gs *govStakerV1) unDelegate(
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
	allDelegations := gs.store.GetAllDelegations()

	// Process undelegation across multiple delegation records if necessary
	for _, id := range delegationIDs {
		delegationRaw, exists := allDelegations.Get(formatInt(id))
		if !exists {
			continue
		}
		delegation, ok := delegationRaw.(*staker.Delegation)
		if !ok {
			continue
		}

		resolver := NewDelegationResolver(delegation)
		if resolver.IsEmpty() {
			gs.removeDelegation(delegation.ID())
			continue
		}

		currentUnDelegationAmount := unDelegationAmount

		if currentUnDelegationAmount > resolver.DelegatedAmount() {
			currentUnDelegationAmount = resolver.DelegatedAmount()
		}

		if currentUnDelegationAmount < 0 {
			return 0, errors.New("undelegation amount cannot be negative")
		}

		resolver.UnDelegate(
			currentUnDelegationAmount,
			currentHeight,
			currentTimestamp,
			lockupPeriod,
		)

		gs.setDelegation(delegation.ID(), delegation)
		gs.addDelegationRecord(delegatee, -currentUnDelegationAmount, currentTimestamp)
		gs.removeStakeEmissionReward(delegator.String(), currentUnDelegationAmount, currentTimestamp)
		gs.removeStakeProtocolFeeReward(delegator.String(), currentUnDelegationAmount, currentTimestamp)

		unDelegationAmount = safeSubInt64(unDelegationAmount, currentUnDelegationAmount)
		if unDelegationAmount <= 0 {
			break
		}
	}

	// Update total delegated amount directly in store
	currentDelegated := gs.store.GetTotalDelegatedAmount()

	newDelegated := safeSubInt64(currentDelegated, amount)
	if newDelegated < 0 {
		newDelegated = 0
	}
	if err := gs.store.SetTotalDelegatedAmount(newDelegated); err != nil {
		panic(err)
	}

	return amount, nil
}

// unDelegateWithoutLockup processes undelegation without lockup.
// Used for redelegation where tokens are immediately available.
func (gs *govStakerV1) unDelegateWithoutLockup(
	delegator,
	delegatee address,
	amount,
	currentHeight,
	currentTime int64,
) (int64, error) {
	delegationIDs := gs.getUserDelegationIDsWithDelegatee(delegator, delegatee)
	if len(delegationIDs) == 0 {
		return 0, nil
	}

	unDelegationAmount := amount
	allDelegations := gs.store.GetAllDelegations()

	// Process undelegation across multiple delegation records if necessary
	for _, id := range delegationIDs {
		delegationRaw, exists := allDelegations.Get(formatInt(id))
		if !exists {
			continue
		}
		delegation, ok := delegationRaw.(*staker.Delegation)
		if !ok {
			continue
		}

		resolver := NewDelegationResolver(delegation)
		if resolver.IsEmpty() {
			gs.removeDelegation(delegation.ID())
			continue
		}

		currentUnDelegationAmount := unDelegationAmount

		if currentUnDelegationAmount > resolver.DelegatedAmount() {
			currentUnDelegationAmount = resolver.DelegatedAmount()
		}

		resolver.UnDelegateWithoutLockup(
			currentUnDelegationAmount,
			currentHeight,
			currentTime,
		)

		// Save updated delegation state after undelegation without lockup
		gs.setDelegation(delegation.ID(), delegation)
		gs.addDelegationRecord(delegatee, -currentUnDelegationAmount, currentTime)

		unDelegationAmount = safeSubInt64(unDelegationAmount, currentUnDelegationAmount)
		if unDelegationAmount <= 0 {
			break
		}
	}

	// Update total delegated amount directly in store
	currentDelegated := gs.store.GetTotalDelegatedAmount()

	newDelegated := safeSubInt64(currentDelegated, amount)
	if newDelegated < 0 {
		newDelegated = 0
	}
	if err := gs.store.SetTotalDelegatedAmount(newDelegated); err != nil {
		panic(err)
	}

	return amount, nil
}

// collectDelegations processes collection of undelegated tokens.
// Iterates through user delegations and collects available amounts.
func (gs *govStakerV1) collectDelegations(user address, currentTime int64) (int64, error) { // performance optimization
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
			delegationRaw, exists := allDelegations.Get(formatInt(id))
			if !exists {
				continue
			}
			delegation, ok := delegationRaw.(*staker.Delegation)
			if !ok {
				continue
			}

			resolver := NewDelegationResolver(delegation)

			collectedAmount, err := resolver.processCollection(currentTime)
			if err != nil {
				return true
			}

			// Simple addition since addToCollectedAmount was removed
			totalCollectedAmount = safeAddInt64(totalCollectedAmount, collectedAmount)

			// Save updated delegation state after collection
			if resolver.IsEmpty() {
				idsToRemove = append(idsToRemove, delegation.ID())
			} else {
				gs.setDelegation(delegation.ID(), delegation)
			}
		}

		return false
	})

	for _, id := range idsToRemove {
		gs.removeDelegation(id)
	}

	if err != nil {
		return totalCollectedAmount, makeErrorWithDetails(errInvalidAmount, err.Error())
	}

	return totalCollectedAmount, nil
}

// registerReferrer registers or validates referrer for delegation.
// Handles referral system integration for delegation operations.
func registerReferrer(caller address, referrer string) string {
	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer

	if !success {
		actualReferrer = referral.GetReferral(referrer)
	}

	return actualReferrer
}
