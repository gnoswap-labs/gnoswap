package staker

import (
	"std"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
	"gno.land/r/gnoswap/v1/gov/xgns"
)

// Delegate delegates GNS tokens to an address.
func Delegate(
	cur realm,
	to std.Address,
	amount int64,
	referrer string,
) int64 {
	halt.AssertIsNotHaltedGovStaker()

	prevRealm := std.PreviousRealm()
	access.AssertIsUser(prevRealm)
	access.AssertIsValidAddress(to)

	assertIsValidDelegateAmount(amount)

	caller := prevRealm.Address()
	from := caller
	currentRealm := std.CurrentRealm()
	currentHeight := std.ChainHeight()
	currentTimestamp := time.Now().Unix()

	emission.MintAndDistributeGns(cross)

	delegation, err := delegate(
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

	std.Emit(
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
func Undelegate(
	cur realm,
	from std.Address,
	amount int64,
) int64 {
	halt.AssertIsNotHaltedGovStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsValidAddress(from)

	assertIsValidDelegateAmount(amount)

	currentHeight := std.ChainHeight()
	currentTimestamp := time.Now().Unix()

	emission.MintAndDistributeGns(cross)

	unDelegationAmount, err := unDelegate(
		caller,
		from,
		amount,
		currentHeight,
		currentTimestamp,
	)
	if err != nil {
		panic(err)
	}

	prevRealm := std.PreviousRealm()
	std.Emit(
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
func Redelegate(
	cur realm,
	delegatee,
	newDelegatee std.Address,
	amount int64,
) int64 {
	halt.AssertIsNotHaltedGovStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsValidAddress(delegatee)
	access.AssertIsValidAddress(newDelegatee)

	assertIsValidDelegateAmount(amount)

	currentHeight := std.ChainHeight()
	currentTimestamp := time.Now().Unix()
	delegator := caller

	emission.MintAndDistributeGns(cross)

	unDelegationAmount, err := unDelegateWithoutLockup(
		delegator,
		delegatee,
		amount,
		currentHeight,
		currentTimestamp,
	)
	if err != nil {
		panic(err)
	}

	delegation, err := delegate(
		delegator,
		newDelegatee,
		unDelegationAmount,
		currentHeight,
		currentTimestamp,
	)

	prevRealm := std.PreviousRealm()
	std.Emit(
		"Undelegate",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"from", delegation.DelegateFrom().String(),
		"to", delegation.DelegateTo().String(),
		"amount", formatInt(delegation.DelegatedAmount()),
	)

	std.Emit(
		"Redelegate",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"from", delegation.DelegateFrom().String(),
		"to", delegation.DelegateTo().String(),
		"amount", formatInt(delegation.DelegatedAmount()),
	)

	return amount
}

// CollectUndelegatedGns collects undelegated GNS tokens.
// Allows users to collect GNS tokens that completed undelegation lockup period.
// Burns xGNS and returns GNS tokens.
func CollectUndelegatedGns(cur realm) int64 {
	halt.AssertIsNotHaltedGovStaker()
	halt.AssertIsNotHaltedWithdraw()

	prevRealm := std.PreviousRealm()
	caller := prevRealm.Address()
	currentTime := time.Now().Unix()

	emission.MintAndDistributeGns(cross)

	collectedAmount, err := collectDelegations(caller, currentTime)
	if err != nil {
		panic(err)
	}

	if collectedAmount == 0 {
		return 0
	}

	xgns.Burn(cross, caller, collectedAmount)
	gns.Transfer(cross, caller, collectedAmount)

	totalLockedAmount -= collectedAmount
	if totalLockedAmount < 0 {
		totalLockedAmount = 0
	}

	std.Emit(
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
func delegate(
	from std.Address,
	to std.Address,
	amount,
	currentHeight,
	currentTimestamp int64,
) (*Delegation, error) {
	delegationID := nextDelegationID()
	delegation := NewDelegation(
		delegationID,
		from,
		to,
		amount,
		currentHeight,
		currentTimestamp,
	)
	delegationRecord := NewDelegationDelegateRecordBy(delegation)

	addDelegation(delegationID, delegation)
	addDelegationRecord(delegationRecord)
	addStakeEmissionReward(from.String(), amount, currentTimestamp)
	addStakeProtocolFeeReward(from.String(), amount, time.Now().Unix())

	totalDelegatedAmount += amount
	totalLockedAmount += amount

	return delegation, nil
}

// unDelegate processes undelegation operations with lockup.
// Validates undelegation amount, processes withdrawals, and updates reward tracking.
func unDelegate(
	delegator,
	delegatee std.Address,
	amount,
	currentHeight,
	currentTimestamp int64,
) (int64, error) {
	delegations := getUserDelegationsWithDelegatee(delegator, delegatee)
	if len(delegations) == 0 {
		return 0, nil
	}

	unDelegationAmount := amount

	// Process undelegation across multiple delegation records if necessary
	for _, delegation := range delegations {
		if delegation.IsEmpty() {
			removeDelegation(delegation.ID())
			continue
		}

		currentUnDelegationAmount := unDelegationAmount

		if currentUnDelegationAmount > delegation.DelegatedAmount() {
			currentUnDelegationAmount = delegation.DelegatedAmount()
		}

		delegation.unDelegate(
			currentUnDelegationAmount,
			currentHeight,
			currentTimestamp,
			unDelegationLockupPeriod,
		)

		delegationRecord := NewDelegationWithdrawRecordBy(delegation, currentUnDelegationAmount, currentTimestamp)

		setDelegation(delegation.ID(), delegation)
		addDelegationRecord(delegationRecord)
		removeStakeEmissionReward(delegator.String(), currentUnDelegationAmount, currentTimestamp)
		removeStakeProtocolFeeReward(delegator.String(), currentUnDelegationAmount, currentTimestamp)

		unDelegationAmount -= currentUnDelegationAmount
		if unDelegationAmount <= 0 {
			break
		}
	}

	totalDelegatedAmount -= amount

	if totalDelegatedAmount < 0 {
		totalDelegatedAmount = 0
	}

	return amount, nil
}

// unDelegateWithoutLockup processes undelegation without lockup.
// Used for redelegation where tokens are immediately available.
func unDelegateWithoutLockup(
	delegator,
	delegatee std.Address,
	amount,
	currentHeight,
	currentTime int64,
) (int64, error) {
	delegations := getUserDelegationsWithDelegatee(delegator, delegatee)
	if len(delegations) == 0 {
		return 0, nil
	}

	unDelegationAmount := amount

	// Process undelegation across multiple delegation records if necessary
	for _, delegation := range delegations {
		if delegation.IsEmpty() {
			removeDelegation(delegation.ID())
			continue
		}

		currentUnDelegationAmount := unDelegationAmount

		if currentUnDelegationAmount > delegation.DelegatedAmount() {
			currentUnDelegationAmount = delegation.DelegatedAmount()
		}

		delegation.unDelegateWithoutLockup(
			currentUnDelegationAmount,
			currentHeight,
			currentTime,
		)

		unDelegationAmount -= currentUnDelegationAmount
		if unDelegationAmount <= 0 {
			break
		}
	}

	totalDelegatedAmount -= amount

	if totalDelegatedAmount < 0 {
		totalDelegatedAmount = 0
	}

	return amount, nil
}

// collectDelegations processes collection of undelegated tokens.
// Iterates through user delegations and collects available amounts.
func collectDelegations(user std.Address, currentTime int64) (int64, error) {
	collectedAmount := int64(0)

	delegations := getUserDelegations(user)
	if len(delegations) == 0 {
		return collectedAmount, nil
	}

	// Collect from all available delegations
	for _, delegation := range delegations {
		collectableAmount := delegation.CollectableAmount(currentTime)

		if collectableAmount == 0 {
			continue
		}

		err := delegation.collect(collectableAmount, currentTime)
		if err != nil {
			return collectedAmount, err
		}

		collectedAmount += collectableAmount

		// Remove empty delegations to keep storage clean
		if delegation.IsEmpty() {
			removeDelegation(delegation.ID())
		}
	}

	return collectedAmount, nil
}

// registerReferrer registers or validates referrer for delegation.
// Handles referral system integration for delegation operations.
func registerReferrer(caller std.Address, referrer string) string {
	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer

	if !success {
		actualReferrer = referral.GetReferral(referrer)
	}

	return actualReferrer
}
