package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/xgns"
	"gno.land/r/gnoswap/v1/referral"
)

// Delegate delegates GNS tokens to a specified address.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#delegate
func Delegate(
	cur realm,
	to std.Address,
	amount int64,
	referrer string,
) int64 {
	prevRealm := std.PreviousRealm()
	caller := prevRealm.Address()
	from := caller
	currentTime := time.Now().Unix()
	currentRealm := std.CurrentRealm()
	currentHeight := std.ChainHeight()

	assertValidAddress(to)

	emission.MintAndDistributeGns(cross)

	delegation, err := delegate(
		from,
		to,
		amount,
		currentTime,
		currentHeight,
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
		"amount", formatInt(delegation.TotalDelegatedAmount()),
		"referrer", registeredReferrer,
	)

	return amount
}

// Undelegate undelegates xGNS from the existing delegate.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#undelegate
func Undelegate(
	cur realm,
	from std.Address,
	amount int64,
) int64 {
	prevRealm := std.PreviousRealm()
	caller := prevRealm.Address()
	currentTime := time.Now().Unix()
	currentHeight := std.ChainHeight()

	assertValidAddress(from)

	emission.MintAndDistributeGns(cross)

	unDelegationAmount, err := unDelegate(
		caller,
		from, 
		amount, 
		currentTime,
		currentHeight,
	)
	if err != nil {
		panic(err)
	}

	std.Emit(
		"Undelegate",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"from", from.String(),
		"amount", formatInt(unDelegationAmount),
	)

	return unDelegationAmount
}

// Redelegate redelegates xGNS from existing delegate to another.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#redelegate
func Redelegate(
	cur realm,
	delegatee,
	newDelegatee std.Address,
	amount int64,
) int64 {
	prevRealm := std.PreviousRealm()
	currentTime := time.Now().Unix()
	currentHeight := std.ChainHeight()
	caller := prevRealm.Address()
	delegator := caller

	assertValidAddress(delegatee)
	assertValidAddress(newDelegatee)

	emission.MintAndDistributeGns(cross)

	unDelegationAmount, err := unDelegateWithoutLockup(
		delegator,
		delegatee,
		amount,
		currentTime,
	)
	if err != nil {
		panic(err)
	}

	delegation, err := delegate(
		delegator,
		newDelegatee,
		unDelegationAmount,
		currentTime,
		currentHeight,
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

// CollectUndelegatedGns collects the amount of the undelegated GNS.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#collectundelegatedgns
func CollectUndelegatedGns(cur realm) int64 {
	assertIsNotHaltedWithdraw()

	prevRealm := std.PreviousRealm()
	caller := prevRealm.Address()
	currentTime := time.Now().Unix()

	emission.MintAndDistributeGns(cross)

	collectedAmount, err := collectDelegations(caller, currentTime)
	if err != nil {
		panic(err)
	}

	xgns.Burn(cross, caller, collectedAmount)
	gns.Transfer(cross, caller, collectedAmount)

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

func delegate(
	from std.Address,
	to std.Address,
	amount,
	currentTime,
	currentHeight int64,
) (*Delegation, error) {
	err := validateDelegateAmount(amount)
	if err != nil {
		return nil, err
	}

	delegationID := nextDelegationID()
	delegation := NewDelegation(
		delegationID,
		from,
		to,
		amount,
		currentTime,
	)
	delegationRecord := NewDelegationDelegateRecordBy(delegation)

	addDelegation(delegationID, delegation)
	addDelegationRecord(delegationRecord)
	addStakeEmissionReward(from.String(), amount, currentHeight)
	addStakeProtocolFeeReward(from.String(), amount, currentHeight)

	return delegation, nil
}

func unDelegate(
	delegator,
	delegatee std.Address,
	amount,
	currentTime,
	currentHeight int64,
) (int64, error) {
	err := validateDelegateAmount(amount)
	if err != nil {
		return 0, err
	}

	delegations := getUserDelegationsWithDelegatee(delegator, delegatee)
	if len(delegations) == 0 {
		return 0, nil
	}

	unDelegationAmount := amount

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
			currentTime,
			unDelegationLockupPeriod,
		)

		delegationRecord := NewDelegationWithdrawRecordBy(delegation, currentUnDelegationAmount, currentTime)

		setDelegation(delegation.ID(), delegation)
		addDelegationRecord(delegationRecord)
		removeStakeEmissionReward(delegator.String(), currentUnDelegationAmount, currentHeight)
		removeStakeProtocolFeeReward(delegator.String(), currentUnDelegationAmount, currentHeight)

		unDelegationAmount -= currentUnDelegationAmount
		if unDelegationAmount <= 0 {
			break
		}
	}

	return amount, nil
}

func unDelegateWithoutLockup(
	delegator,
	delegatee std.Address,
	amount,
	currentTime int64,
) (int64, error) {
	err := validateDelegateAmount(amount)
	if err != nil {
		return 0, err
	}

	delegations := getUserDelegationsWithDelegatee(delegator, delegatee)
	if len(delegations) == 0 {
		return 0, nil
	}

	unDelegationAmount := amount

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
			currentTime,
		)

		unDelegationAmount -= currentUnDelegationAmount
		if unDelegationAmount <= 0 {
			break
		}
	}

	return amount, nil
}

func collectDelegations(user std.Address, currentTime int64) (int64, error) {
	collectedAmount := int64(0)

	delegations := getUserDelegations(user)
	if len(delegations) == 0 {
		return 0, nil
	}

	for _, delegation := range delegations {
		collectableAmount := delegation.CollectableAmount(currentTime)

		if collectableAmount == 0 {
			continue
		}

		err := delegation.collect(collectableAmount, currentTime)
		if err != nil {
			return 0, err
		}

		collectedAmount += collectableAmount

		if delegation.IsEmpty() {
			removeDelegation(delegation.ID())
		}
	}

	return collectedAmount, nil
}

func registerReferrer(caller std.Address, referrer string) string {
	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer

	if !success {
		actualReferrer = referral.GetReferral(referrer)
	}

	return actualReferrer
}

func validateDelegateAmount(amount int64) error {
	if amount < minimumAmount {
		return makeErrorWithDetail(
			errLessThanMinimum,
			ufmt.Sprintf("minimum amount to delegate is %d (requested:%d)", minimumAmount, amount),
		)
	}

	if amount%minimumAmount != 0 {
		return makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("amount must be multiple of %d", minimumAmount),
		)
	}

	return nil
}
