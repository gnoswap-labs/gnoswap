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
	_ int,
	rlm realm,
	to address,
	amount int64,
	referrer string,
) int64 {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

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
		"amount", formatInt(resolver.DelegatedAmount()),
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
//   - from: Address currently delegated to
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
// Returns undelegated amount.
func (gs *govStakerV1) Undelegate(
	_ int,
	rlm realm,
	from address,
	amount int64,
) int64 {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

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
	_ int,
	rlm realm,
	delegatee,
	newDelegatee address,
	amount int64,
) int64 {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

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
		"amount", formatInt(resolver.DelegatedAmount()),
	)

	return amount
}

// CollectUndelegatedGns collects undelegated GNS tokens.
// Allows users to collect GNS tokens that completed undelegation lockup period.
// Burns xGNS and returns GNS tokens.
func (gs *govStakerV1) CollectUndelegatedGns(_ int, rlm realm) int64 {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

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
		"collectedAmount", formatInt(collectedAmount),
	)

	return collectedAmount
}

// delegate processes delegation operations.
// Validates delegation amount, creates delegation records, and updates reward tracking.
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
		return nil, errors.New("delegated amount cannot be negative")
	}

	gs.addDelegation(0, rlm, delegationID, delegation)
	gs.addDelegationRecord(0, rlm, to, delegatedAmount, currentTimestamp)
	gs.addStakeEmissionReward(0, rlm, from.String(), amount, currentTimestamp)
	gs.addStakeProtocolFeeReward(0, rlm, from.String(), amount, currentTimestamp)

	return delegation, nil
}

// unDelegate processes undelegation operations with lockup.
// Validates undelegation amount, processes withdrawals, and updates reward tracking.
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

		totalDelegated = safeAddInt64(totalDelegated, NewDelegationResolver(delegation).DelegatedAmount())
		delegations = append(delegations, delegation)
	}

	if amount > totalDelegated {
		return 0, errNotEnoughDelegated
	}

	// Process undelegation across multiple delegation records if necessary
	for _, delegation := range delegations {
		resolver := NewDelegationResolver(delegation)
		if resolver.IsEmpty() {
			gs.removeDelegation(0, rlm, delegation.ID())
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

		gs.setDelegation(0, rlm, delegation.ID(), delegation)
		gs.addDelegationRecord(0, rlm, delegatee, -currentUnDelegationAmount, currentTimestamp)
		gs.removeStakeEmissionReward(0, rlm, delegator.String(), currentUnDelegationAmount, currentTimestamp)
		gs.removeStakeProtocolFeeReward(0, rlm, delegator.String(), currentUnDelegationAmount, currentTimestamp)

		unDelegationAmount = safeSubInt64(unDelegationAmount, currentUnDelegationAmount)
		if unDelegationAmount <= 0 {
			break
		}
	}

	return amount, nil
}

// unDelegateWithoutLockup processes undelegation without lockup.
// Used for redelegation where tokens are immediately available.
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
		return 0, errNotEnoughDelegated
	}

	unDelegationAmount := amount
	totalDelegated := int64(0)
	delegations := make([]*staker.Delegation, 0, len(delegationIDs))

	for _, id := range delegationIDs {
		delegation, exists := gs.store.GetDelegation(id)
		if !exists {
			continue
		}

		totalDelegated = safeAddInt64(totalDelegated, NewDelegationResolver(delegation).DelegatedAmount())
		delegations = append(delegations, delegation)
	}

	if amount > totalDelegated {
		return 0, errNotEnoughDelegated
	}

	// Process undelegation across multiple delegation records if necessary
	for _, delegation := range delegations {
		resolver := NewDelegationResolver(delegation)
		if resolver.IsEmpty() {
			gs.removeDelegation(0, rlm, delegation.ID())
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

		if resolver.IsEmpty() {
			gs.removeDelegation(0, rlm, delegation.ID())
		} else {
			gs.setDelegation(0, rlm, delegation.ID(), delegation)
		}
		gs.addDelegationRecord(0, rlm, delegatee, -currentUnDelegationAmount, currentTime)
		gs.removeStakeEmissionReward(0, rlm, delegator.String(), currentUnDelegationAmount, currentTime)
		gs.removeStakeProtocolFeeReward(0, rlm, delegator.String(), currentUnDelegationAmount, currentTime)

		unDelegationAmount = safeSubInt64(unDelegationAmount, currentUnDelegationAmount)
		if unDelegationAmount <= 0 {
			break
		}
	}

	return amount, nil
}

func (gs *govStakerV1) increaseTotalDelegatedAmount(_ int, rlm realm, amount int64) error {
	currentDelegated := gs.store.GetTotalDelegatedAmount()

	if err := gs.store.SetTotalDelegatedAmount(0, rlm, safeAddInt64(currentDelegated, amount)); err != nil {
		return err
	}

	return nil
}

func (gs *govStakerV1) decreaseTotalDelegatedAmount(_ int, rlm realm, amount int64) error {
	currentDelegated := gs.store.GetTotalDelegatedAmount()

	newDelegated := safeSubInt64(currentDelegated, amount)
	if newDelegated < 0 {
		newDelegated = 0
	}
	if err := gs.store.SetTotalDelegatedAmount(0, rlm, newDelegated); err != nil {
		return err
	}

	return nil
}

func (gs *govStakerV1) increaseTotalLockedAmount(_ int, rlm realm, amount int64) error {
	currentLocked := gs.store.GetTotalLockedAmount()

	if err := gs.store.SetTotalLockedAmount(0, rlm, safeAddInt64(currentLocked, amount)); err != nil {
		return err
	}

	return nil
}

func (gs *govStakerV1) decreaseTotalLockedAmount(_ int, rlm realm, amount int64) error {
	currentLocked := gs.store.GetTotalLockedAmount()

	newLocked := safeSubInt64(currentLocked, amount)
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
			delegationRaw, exists := allDelegations.Get(formatInt(id))
			if !exists {
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
			totalCollectedAmount = safeAddInt64(totalCollectedAmount, collectedAmount)

			// Save updated delegation state after collection
			if resolver.IsEmpty() {
				idsToRemove = append(idsToRemove, delegation.ID())
			} else {
				gs.setDelegation(0, rlm, delegation.ID(), delegation)
			}
		}

		return false
	})

	for _, id := range idsToRemove {
		gs.removeDelegation(0, rlm, id)
	}

	if err != nil {
		return totalCollectedAmount, makeErrorWithDetails(errInvalidAmount, err.Error())
	}

	return totalCollectedAmount, nil
}
