package v1

import (
	"chain"
	"chain/runtime"
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
)

// DistributeProtocolFee distributes collected protocol fees.
//
// Splits fees between devOps and gov/staker based on configured percentages.
// This function processes all accumulated fees since last distribution.
//
// Returns:
//   - map[string]int64: Token paths to amounts distributed to gov/staker
//
// Only callable by admin or gov/staker contract.
// Note: Default split is 0% devOps, 100% gov/staker.
func (pf *protocolFeeV1) DistributeProtocolFee() map[string]int64 {
	halt.AssertIsNotHaltedProtocolFee()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	assertIsAdminOrGovStaker(caller)

	sentToDevOpsForEvent := make([]string, 0)
	sentToGovStakerForEvent := make([]string, 0)
	toReturnDistributedToGovStaker := make(map[string]int64)

	state := pf.getProtocolFeeState()
	devOpsPct := state.DevOpsPct()

	for token, amount := range pf.store.GetTokenListWithAmounts() {
		if amount <= 0 {
			continue
		}

		balance := common.BalanceOf(token, protocolFeeAddr)

		// amount should be less than or equal to balance
		if amount > balance {
			panic(makeErrorWithDetail(
				errInvalidAmount,
				ufmt.Sprintf("amount: %d should be less than or equal to balance: %d", amount, balance),
			))
		}

		distributeAmount := amount

		toDevOpsAmount := safeMulDiv(distributeAmount, devOpsPct, 10000)    // default 0%
		toGovStakerAmount := safeSubInt64(distributeAmount, toDevOpsAmount) // default 100%

		// Distribute to DevOps
		if err := state.distributeToDevOps(token, toDevOpsAmount); err != nil {
			panic(err)
		}
		if toDevOpsAmount > 0 {
			sentToDevOpsForEvent = append(sentToDevOpsForEvent, makeEventString(token, toDevOpsAmount))
		}

		// Distribute to Gov/Staker
		if err := state.distributeToGovStaker(token, toGovStakerAmount); err != nil {
			panic(err)
		}
		if toGovStakerAmount > 0 {
			sentToGovStakerForEvent = append(sentToGovStakerForEvent, makeEventString(token, toGovStakerAmount))
			toReturnDistributedToGovStaker[token] = toGovStakerAmount
		}
	}

	if err := state.clearTokenListWithAmount(); err != nil {
		panic(err)
	}

	chain.Emit(
		"TransferProtocolFee",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"toDevOps", strings.Join(sentToDevOpsForEvent, ","),
		"toGovStaker", strings.Join(sentToGovStakerForEvent, ","),
	)

	return toReturnDistributedToGovStaker
}

// SetDevOpsPct sets the devOpsPct.
//
// Parameters:
//   - pct: percentage for devOps (0-10000, where 10000 = 100%)
//
// Only callable by admin or governance.
// Note: GovStaker percentage is automatically adjusted to (10000 - devOpsPct).
func (pf *protocolFeeV1) SetDevOpsPct(pct int64) {
	halt.AssertIsNotHaltedProtocolFee()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidPercent(pct)

	prevState := pf.getProtocolFeeState()

	newDevOpsPct, err := pf.getProtocolFeeState().setDevOpsPct(pct)
	if err != nil {
		panic(err)
	}
	newGovStakerPct := pf.getProtocolFeeState().GovStakerPct()

	chain.Emit(
		"SetDevOpsPct",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"newDevOpsPct", strconv.FormatInt(newDevOpsPct, 10),
		"prevDevOpsPct", strconv.FormatInt(prevState.DevOpsPct(), 10),
		"newGovStakerPct", strconv.FormatInt(newGovStakerPct, 10),
		"prevGovStakerPct", strconv.FormatInt(prevState.GovStakerPct(), 10),
	)
}

// SetGovStakerPct sets the stakerPct.
//
// Parameters:
//   - pct: percentage for gov/staker (0-10000, where 10000 = 100%)
//
// Only callable by admin or governance.
// Note: DevOps percentage is automatically adjusted to (10000 - govStakerPct).
func (pf *protocolFeeV1) SetGovStakerPct(pct int64) {
	halt.AssertIsNotHaltedProtocolFee()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidPercent(pct)


	prevState := pf.getProtocolFeeState()

	newGovStakerPct, err := pf.getProtocolFeeState().setGovStakerPct(pct)
	if err != nil {
		panic(err)
	}
	newDevOpsPct := pf.getProtocolFeeState().DevOpsPct()

	chain.Emit(
		"SetGovStakerPct",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"newDevOpsPct", strconv.FormatInt(newDevOpsPct, 10),
		"prevDevOpsPct", strconv.FormatInt(prevState.DevOpsPct(), 10),
		"newGovStakerPct", strconv.FormatInt(newGovStakerPct, 10),
		"prevGovStakerPct", strconv.FormatInt(prevState.GovStakerPct(), 10),
	)
}

// AddToProtocolFee adds the amount to the tokenListWithAmount.
//
// Parameters:
//   - tokenPath: token contract path
//   - amount: fee amount to add
//
// Only callable by pool, router or staker contracts.
// Note: Accumulated fees are distributed when DistributeProtocolFee is called.
func (pf *protocolFeeV1) AddToProtocolFee(tokenPath string, amount int64) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	assertIsPoolOrPositionOrRouterOrStaker(caller)

	if amount < 0 {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("amount(%d) should not be negative", amount),
		))
	}

	currentAmount, exists := pf.store.GetTokenListWithAmountItem(tokenPath)
	if !exists {
		currentAmount = 0
	}
	pf.store.SetTokenListWithAmountItem(tokenPath, safeAddInt64(currentAmount, amount))
}

// ClearTokenListWithAmount clears the tokenListWithAmount.
//
// Resets all accumulated token amounts to zero.
// Only callable by gov/staker contract.
// Note: Should be called after successful distribution.
func (pf *protocolFeeV1) ClearTokenListWithAmount() {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)

	if err := pf.getProtocolFeeState().clearTokenListWithAmount(); err != nil {
		panic(err)
	}
}

// ClearAccuTransferToGovStaker clears the accuToGovStaker.
//
// Resets accumulated transfer tracking for gov/staker.
// This allows gov/staker to track distributions between calls.
//
// Only callable by gov/staker contract.
// Note: Should be called after reading accumulated amounts.
func (pf *protocolFeeV1) ClearAccuTransferToGovStaker() {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)

	pf.store.InitializeAccuToGovStaker()
}

func makeEventString(tokenPath string, amount int64) string {
	return tokenPath + "*FEE*" + strconv.FormatInt(amount, 10)
}
