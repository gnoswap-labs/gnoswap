package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
	"gno.land/r/gnoswap/gov/staker"
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

	chain.Emit(
		"Delegate",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"from", delegation.DelegateFrom().String(),
		"to", delegation.DelegateTo().String(),
		"amount", formatInt(delegation.DelegatedAmount()),
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

	caller := runtime.PreviousRealm().Address()
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

	prevRealm := runtime.PreviousRealm()
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

	caller := runtime.PreviousRealm().Address()
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

	prevRealm := runtime.PreviousRealm()
	chain.Emit(
		"Redelegate",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"from", delegator.String(),
		"previousDelegatee", delegatee.String(),
		"newDelegatee", newDelegatee.String(),
		"amount", formatInt(delegation.DelegatedAmount()),
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
	newLocked := currentLocked - collectedAmount
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
	delegationRecord := staker.NewDelegationRecord(
		staker.DelegateType,
		amount, // delegationAmount
		from,
		to,
		currentTimestamp,
	)

	gs.addDelegation(delegationID, delegation)
	gs.addDelegationRecord(delegationRecord)
	gs.addStakeEmissionReward(from.String(), amount, currentTimestamp)
	gs.addStakeProtocolFeeReward(from.String(), amount, time.Now().Unix())

	// Update total amounts directly in store
	currentDelegated := gs.store.GetTotalDelegatedAmount()
	if err := gs.store.SetTotalDelegatedAmount(currentDelegated + amount); err != nil {
		panic(err)
	}
	
	currentLocked := gs.store.GetTotalLockedAmount()
	if err := gs.store.SetTotalLockedAmount(currentLocked + amount); err != nil {
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
	delegations := gs.getUserDelegationsWithDelegatee(delegator, delegatee)
	if len(delegations) == 0 {
		return 0, nil
	}

	unDelegationAmount := amount

	// Process undelegation across multiple delegation records if necessary
	for _, delegation := range delegations {
		if delegation.IsEmpty() {
			gs.removeDelegation(delegation.ID())
			continue
		}

		currentUnDelegationAmount := unDelegationAmount

		if currentUnDelegationAmount > delegation.DelegatedAmount() {
			currentUnDelegationAmount = delegation.DelegatedAmount()
		}

		// Get lockup period from store
		lockupPeriod, err := gs.store.GetUnDelegationLockupPeriod()
		if err != nil {
			panic(err)
		}
		
		delegation.UnDelegate(
			currentUnDelegationAmount,
			currentHeight,
			currentTimestamp,
			lockupPeriod,
		)

		delegationRecord := staker.NewDelegationWithdrawRecordBy(delegation, currentUnDelegationAmount, currentTimestamp)

		gs.setDelegation(delegation.ID(), delegation)
		gs.addDelegationRecord(delegationRecord)
		gs.removeStakeEmissionReward(delegator.String(), currentUnDelegationAmount, currentTimestamp)
		gs.removeStakeProtocolFeeReward(delegator.String(), currentUnDelegationAmount, currentTimestamp)

		unDelegationAmount -= currentUnDelegationAmount
		if unDelegationAmount <= 0 {
			break
		}
	}

	// Update total delegated amount directly in store
	currentDelegated := gs.store.GetTotalDelegatedAmount()
	newDelegated := currentDelegated - amount
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
	delegations := gs.getUserDelegationsWithDelegatee(delegator, delegatee)
	if len(delegations) == 0 {
		return 0, nil
	}

	unDelegationAmount := amount

	// Process undelegation across multiple delegation records if necessary
	for _, delegation := range delegations {
		if delegation.IsEmpty() {
			gs.removeDelegation(delegation.ID())
			continue
		}

		currentUnDelegationAmount := unDelegationAmount

		if currentUnDelegationAmount > delegation.DelegatedAmount() {
			currentUnDelegationAmount = delegation.DelegatedAmount()
		}

		delegation.UnDelegateWithoutLockup(
			currentUnDelegationAmount,
			currentHeight,
			currentTime,
		)

		unDelegationAmount -= currentUnDelegationAmount
		if unDelegationAmount <= 0 {
			break
		}
	}

	// Update total delegated amount directly in store
	currentDelegated := gs.store.GetTotalDelegatedAmount()
	newDelegated := currentDelegated - amount
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
func (gs *govStakerV1) collectDelegations(user address, currentTime int64) (int64, error) {
	collectedAmount := int64(0)

	delegations := gs.getUserDelegations(user)
	if len(delegations) == 0 {
		return collectedAmount, nil
	}

	// Collect from all available delegations
	for _, delegation := range delegations {
		collectableAmount := delegation.CollectableAmount(currentTime)

		if collectableAmount == 0 {
			continue
		}

		err := delegation.Collect(collectableAmount, currentTime)
		if err != nil {
			return collectedAmount, err
		}

		// Simple addition since addToCollectedAmount was removed
		collectedAmount += collectableAmount
		if err != nil {
			return collectedAmount, err
		}

		// Remove empty delegations to keep storage clean
		if delegation.IsEmpty() {
			gs.removeDelegation(delegation.ID())
		}
	}

	return collectedAmount, nil
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
