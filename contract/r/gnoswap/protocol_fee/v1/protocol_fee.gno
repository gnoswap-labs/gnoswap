package v1

import (
	"chain"
	"chain/runtime"
	"strconv"
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
)

// DistributeProtocolFee distributes collected protocol fees.
//
// Splits fees between devOps and gov/staker based on configured percentages.
// This function processes all accumulated fees since last distribution.
//
// Only callable by admin or gov/staker contract.
// Note: Default split is 0% devOps, 100% gov/staker.
func (pf *protocolFeeV1) DistributeProtocolFee() {
	caller := runtime.PreviousRealm().Address()
	assertIsAdminOrGovStaker(caller)

	if halt.IsHaltedWithdraw() {
		return
	}

	protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	pfs := pf.getProtocolFeeState()

	sentToDevOpsForEvent := make([]string, 0)
	sentToGovStakerForEvent := make([]string, 0)
	reservedTokens := pfs.ReservedTokens()

	for _, token := range reservedTokens {
		toDevOpsAmount := safeSubInt64(
			pfs.GetAccuTransferToDevOpsByTokenPath(token),
			pfs.GetActualDistributedToDevOpsByTokenPath(token),
		)
		toGovStakerAmount := safeSubInt64(
			pfs.GetAccuTransferToGovStakerByTokenPath(token),
			pfs.GetActualDistributedToGovStakerByTokenPath(token),
		)

		amount := safeAddInt64(toDevOpsAmount, toGovStakerAmount)
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

		// Distribute to DevOps
		if err := pfs.distributeToDevOps(token, toDevOpsAmount); err != nil {
			panic(err)
		}
		if toDevOpsAmount > 0 {
			sentToDevOpsForEvent = append(sentToDevOpsForEvent, makeEventString(token, toDevOpsAmount))
		}

		// Distribute to Gov/Staker
		if err := pfs.distributeToGovStaker(token, toGovStakerAmount); err != nil {
			panic(err)
		}
		if toGovStakerAmount > 0 {
			sentToGovStakerForEvent = append(sentToGovStakerForEvent, makeEventString(token, toGovStakerAmount))
		}
	}
	if err := pfs.clearReservedTokens(); err != nil {
		panic(err)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"TransferProtocolFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"toDevOps", strings.Join(sentToDevOpsForEvent, ","),
		"toGovStaker", strings.Join(sentToGovStakerForEvent, ","),
	)
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

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

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
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

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

// AddToProtocolFee pulls the approved amount into protocol fee accounting.
//
// Parameters:
//   - tokenPath: token contract path
//   - amount: fee amount to add
//
// Only callable by pool, router or staker contracts.
// Caller must approve the protocol fee realm for at least amount before calling.
// Note: Accumulated fees are distributed when DistributeProtocolFee is called.
func (pf *protocolFeeV1) AddToProtocolFee(tokenPath string, amount int64) error {
	if halt.IsHaltedProtocolFee() {
		return errProtocolFeeHalted
	}

	caller := runtime.PreviousRealm().Address()
	assertIsPoolOrPositionOrRouterOrStaker(caller)

	if amount < 0 {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("amount(%d) should not be negative", amount),
		))
	}

	if amount == 0 {
		return nil
	}

	pf.reserveCollectedProtocolFee(tokenPath, amount)
	protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	common.SafeGRC20TransferFrom(cross, tokenPath, caller, protocolFeeAddr, amount)

	return nil
}

func makeEventString(tokenPath string, amount int64) string {
	return tokenPath + "*FEE*" + strconv.FormatInt(amount, 10)
}

func (pf *protocolFeeV1) reserveCollectedProtocolFee(tokenPath string, amount int64) {
	pfs := pf.getProtocolFeeState()

	toDevOpsAmount := safeMulDiv(amount, pfs.DevOpsPct(), 10000)
	toGovStakerAmount := safeSubInt64(amount, toDevOpsAmount)

	if err := pfs.addAccuToDevOps(tokenPath, toDevOpsAmount); err != nil {
		panic(err)
	}
	if err := pfs.addAccuToGovStaker(tokenPath, toGovStakerAmount); err != nil {
		panic(err)
	}

	if err := pfs.store.AddReservedToken(tokenPath); err != nil {
		panic(err)
	}
}
