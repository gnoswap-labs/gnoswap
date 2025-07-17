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
// This function transfers GNS tokens from the caller to the staker contract,
// mints corresponding xGNS tokens, and starts earning rewards.
//
// The delegation process involves:
// 1. Validating the delegatee address
// 2. Minting and distributing GNS rewards
// 3. Creating a delegation record
// 4. Transferring GNS tokens to the contract
// 5. Minting xGNS tokens to the delegator
// 6. Registering referrer if applicable
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - to: address to delegate tokens to
//   - amount: amount of GNS tokens to delegate
//   - referrer: referrer address for referral rewards
//
// Returns:
//   - int64: amount of tokens delegated
//
// Panics:
//   - if delegatee address is invalid
//   - if delegation amount is invalid
//   - if GNS transfer fails
//
// Reference: https://docs.gnoswap.io/contracts/governance/staker.gno#delegate
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
// This function initiates the undelegation process with a lockup period,
// during which the tokens cannot be withdrawn. After the lockup period,
// tokens can be collected using CollectUndelegatedGns.
//
// The undelegation process involves:
// 1. Validating the delegatee address
// 2. Minting and distributing GNS rewards
// 3. Processing the undelegation with lockup period
// 4. Creating withdrawal records for tracking
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - from: address to undelegate tokens from
//   - amount: amount of xGNS tokens to undelegate
//
// Returns:
//   - int64: amount of tokens undelegated
//
// Panics:
//   - if delegatee address is invalid
//   - if undelegation amount is invalid
//   - if insufficient delegated amount
//
// Reference: https://docs.gnoswap.io/contracts/governance/staker.gno#undelegate
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
// This function allows changing delegation target without going through
// the undelegation lockup period. The redelegation is processed immediately.
//
// The redelegation process involves:
// 1. Validating both delegatee addresses
// 2. Minting and distributing GNS rewards
// 3. Undelegating from the current delegatee without lockup
// 4. Immediately delegating to the new delegatee
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - delegatee: current delegatee address to move tokens from
//   - newDelegatee: new delegatee address to move tokens to
//   - amount: amount of xGNS tokens to redelegate
//
// Returns:
//   - int64: amount of tokens redelegated
//
// Panics:
//   - if either delegatee address is invalid
//   - if redelegation amount is invalid
//   - if insufficient delegated amount
//
// Reference: https://docs.gnoswap.io/contracts/governance/staker.gno#redelegate
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
// This function allows users to collect GNS tokens that have completed
// their undelegation lockup period. It burns xGNS and returns GNS tokens.
//
// The collection process involves:
// 1. Checking system halt status
// 2. Minting and distributing GNS rewards
// 3. Collecting available undelegated amounts
// 4. Burning xGNS tokens
// 5. Transferring GNS tokens to the user
//
// Parameters:
//   - cur: realm context for cross-realm calls
//
// Returns:
//   - int64: amount of GNS tokens collected
//
// Panics:
//   - if system is halted for withdrawals
//   - if no undelegated tokens are available for collection
//
// Reference: https://docs.gnoswap.io/contracts/governance/staker.gno#collectundelegatedgns
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

// delegate is the internal function that processes delegation operations.
// This function validates the delegation amount, creates delegation records,
// and updates reward tracking systems.
//
// Parameters:
//   - from: delegator's address
//   - to: delegatee's address
//   - amount: amount to delegate
//   - currentTime: current timestamp
//   - currentHeight: current block height
//
// Returns:
//   - *Delegation: created delegation instance
//   - error: nil on success, error if delegation fails
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

// unDelegate is the internal function that processes undelegation operations with lockup.
// This function validates the undelegation amount, processes withdrawals,
// and updates reward tracking systems.
//
// Parameters:
//   - delegator: delegator's address
//   - delegatee: delegatee's address
//   - amount: amount to undelegate
//   - currentTime: current timestamp
//   - currentHeight: current block height
//
// Returns:
//   - int64: amount undelegated
//   - error: nil on success, error if undelegation fails
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

// unDelegateWithoutLockup is the internal function that processes undelegation without lockup.
// This function is used for redelegation where tokens are immediately available.
//
// Parameters:
//   - delegator: delegator's address
//   - delegatee: delegatee's address
//   - amount: amount to undelegate
//   - currentTime: current timestamp
//
// Returns:
//   - int64: amount undelegated
//   - error: nil on success, error if undelegation fails
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
			currentTime,
		)

		unDelegationAmount -= currentUnDelegationAmount
		if unDelegationAmount <= 0 {
			break
		}
	}

	return amount, nil
}

// collectDelegations is the internal function that processes collection of undelegated tokens.
// This function iterates through user delegations and collects any available amounts.
//
// Parameters:
//   - user: user's address
//   - currentTime: current timestamp
//
// Returns:
//   - int64: total amount collected
//   - error: nil on success, error if collection fails
func collectDelegations(user std.Address, currentTime int64) (int64, error) {
	collectedAmount := int64(0)

	delegations := getUserDelegations(user)
	if len(delegations) == 0 {
		return 0, nil
	}

	// Collect from all available delegations
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

		// Remove empty delegations to keep storage clean
		if delegation.IsEmpty() {
			removeDelegation(delegation.ID())
		}
	}

	return collectedAmount, nil
}

// registerReferrer registers or validates a referrer for the delegation.
// This function handles referral system integration for delegation operations.
//
// Parameters:
//   - caller: address of the user making the delegation
//   - referrer: referrer identifier
//
// Returns:
//   - string: actual referrer used (may differ from input if validation fails)
func registerReferrer(caller std.Address, referrer string) string {
	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer

	if !success {
		actualReferrer = referral.GetReferral(referrer)
	}

	return actualReferrer
}

// validateDelegateAmount validates that the delegation amount meets system requirements.
// This function checks minimum amount and multiple requirements.
//
// Parameters:
//   - amount: amount to validate
//
// Returns:
//   - error: nil if valid, error describing validation failure
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
