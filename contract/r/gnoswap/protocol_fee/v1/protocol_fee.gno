package v1

import (
	"chain"
	"chain/runtime"
	"strconv"
	"strings"

	"gno.land/p/nt/avl"
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
	halt.AssertIsNotHaltedProtocolFeeWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	assertIsAdminOrGovStaker(caller)

	sentToDevOpsForEvent := make([]string, 0)
	sentToGovStakerForEvent := make([]string, 0)
	toReturnDistributedToGovStaker := make(map[string]int64)

	for token, amount := range pf.getProtocolFeeState().tokenListWithAmount {
		balance := common.BalanceOf(token, protocolFeeAddr)

		// amount should be less than or equal to balance
		if amount > balance {
			panic(makeErrorWithDetail(
				errInvalidAmount,
				ufmt.Sprintf("amount: %d should be less than or equal to balance: %d", amount, balance),
			))
		}

		if amount <= 0 {
			continue
		}

		// Distribute only the recorded amount, not the entire balance
		distributeAmount := amount
		if distributeAmount > balance {
			// This should not happen due to the check above, but safeguard anyway
			distributeAmount = balance
		}

		toDevOpsAmount := distributeAmount * pf.getProtocolFeeState().DevOpsPct() / 10000 // default 0%
		toGovStakerAmount := distributeAmount - toDevOpsAmount                            // default 100%

		// Distribute to DevOps
		if err := pf.getProtocolFeeState().distributeToDevOps(token, toDevOpsAmount); err != nil {
			panic(err)
		}
		if toDevOpsAmount > 0 {
			sentToDevOpsForEvent = append(sentToDevOpsForEvent, makeEventString(token, toDevOpsAmount))
		}

		// Distribute to Gov/Staker
		if err := pf.getProtocolFeeState().distributeToGovStaker(token, toGovStakerAmount); err != nil {
			panic(err)
		}
		if toGovStakerAmount > 0 {
			sentToGovStakerForEvent = append(sentToGovStakerForEvent, makeEventString(token, toGovStakerAmount))
			toReturnDistributedToGovStaker[token] = toGovStakerAmount
		}
	}

	pf.getProtocolFeeState().clearTokenListWithAmount()

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"TransferProtocolFee",
		"prevAddr", previousRealm.Address().String(),
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
	halt.AssertIsNotHaltedProtocolFeeWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernanceWithVersion(1, caller)

	assertIsValidPercent(pct)

	prevDevOpsPct := pf.getProtocolFeeState().DevOpsPct()
	prevGovStakerPct := pf.getProtocolFeeState().GovStakerPct()

	newDevOpsPct, err := pf.getProtocolFeeState().setDevOpsPct(pct)
	if err != nil {
		panic(err)
	}
	newGovStakerPct := pf.getProtocolFeeState().GovStakerPct()

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetDevOpsPct",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"newDevOpsPct", strconv.FormatInt(newDevOpsPct, 10),
		"prevDevOpsPct", strconv.FormatInt(prevDevOpsPct, 10),
		"newGovStakerPct", strconv.FormatInt(newGovStakerPct, 10),
		"prevGovStakerPct", strconv.FormatInt(prevGovStakerPct, 10),
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
	halt.AssertIsNotHaltedProtocolFeeWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernanceWithVersion(1, caller)

	assertIsValidPercent(pct)

	prevDevOpsPct := pf.getProtocolFeeState().DevOpsPct()
	prevGovStakerPct := pf.getProtocolFeeState().GovStakerPct()

	newGovStakerPct, err := pf.getProtocolFeeState().setGovStakerPct(pct)
	if err != nil {
		panic(err)
	}
	newDevOpsPct := pf.getProtocolFeeState().DevOpsPct()

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetGovStakerPct",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"newDevOpsPct", strconv.FormatInt(newDevOpsPct, 10),
		"prevDevOpsPct", strconv.FormatInt(prevDevOpsPct, 10),
		"newGovStakerPct", strconv.FormatInt(newGovStakerPct, 10),
		"prevGovStakerPct", strconv.FormatInt(prevGovStakerPct, 10),
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
	halt.AssertIsNotHaltedProtocolFeeWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	assertIsPoolOrPositionOrRouterOrStaker(caller)

	if amount < 0 {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("amount(%d) should not be negative", amount),
		))
	}

	currentAmount := pf.getProtocolFeeState().tokenListWithAmount[tokenPath]

	// Check for overflow
	if amount > 0 && currentAmount > 0 && currentAmount > (9223372036854775807-amount) {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("overflow detected: current(%d) + amount(%d) would exceed int64 max", currentAmount, amount),
		))
	}

	pf.getProtocolFeeState().tokenListWithAmount[tokenPath] += amount
}

// ClearTokenListWithAmount clears the tokenListWithAmount.
//
// Resets all accumulated token amounts to zero.
// Only callable by gov/staker contract.
// Note: Should be called after successful distribution.
func (pf *protocolFeeV1) ClearTokenListWithAmount() {
	halt.AssertIsNotHaltedProtocolFeeWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsGovStakerWithVersion(1, caller)

	pf.getProtocolFeeState().clearTokenListWithAmount()
}

// ClearAccuTransferToGovStaker clears the accuToGovStaker.
//
// Resets accumulated transfer tracking for gov/staker.
// This allows gov/staker to track distributions between calls.
//
// Only callable by gov/staker contract.
// Note: Should be called after reading accumulated amounts.
func (pf *protocolFeeV1) ClearAccuTransferToGovStaker() {
	halt.AssertIsNotHaltedProtocolFeeWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsGovStakerWithVersion(1, caller)

	pf.getProtocolFeeState().accuToGovStaker = avl.NewTree()
}

func makeEventString(tokenPath string, amount int64) string {
	return tokenPath + "*FEE*" + strconv.FormatInt(amount, 10)
}
