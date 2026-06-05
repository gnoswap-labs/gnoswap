package v1

import (
	"chain"
	"strconv"

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
func (pf *protocolFeeV1) DistributeProtocolFee(_ int, rlm realm) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	prev := rlm.Previous()
	assertIsAdminOrGovStaker(prev.Address())

	if halt.IsHaltedWithdraw() {
		return
	}

	protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	pfs := pf.getProtocolFeeState()

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
		if err := pfs.distributeToDevOps(0, rlm, token, toDevOpsAmount); err != nil {
			panic(err)
		}

		// Distribute to Gov/Staker
		if err := pfs.distributeToGovStaker(0, rlm, token, toGovStakerAmount); err != nil {
			panic(err)
		}
	}
	if err := pfs.clearReservedTokens(0, rlm); err != nil {
		panic(err)
	}

	chain.Emit(
		"TransferProtocolFee",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
	)
}

// SetDevOpsPct sets the devOpsPct.
//
// Parameters:
//   - pct: percentage for devOps (0-10000, where 10000 = 100%)
//
// Only callable by admin or governance.
// Note: GovStaker percentage is automatically adjusted to (10000 - devOpsPct).
func (pf *protocolFeeV1) SetDevOpsPct(_ int, rlm realm, pct int64) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedProtocolFee()

	prev := rlm.Previous()
	access.AssertIsAdminOrGovernance(prev.Address())

	assertIsValidPercent(pct)

	prevDevOpsPct := pf.getProtocolFeeState().DevOpsPct()
	prevGovStakerPct := pf.getProtocolFeeState().GovStakerPct()

	newDevOpsPct, err := pf.getProtocolFeeState().setDevOpsPct(0, rlm, pct)
	if err != nil {
		panic(err)
	}
	newGovStakerPct := pf.getProtocolFeeState().GovStakerPct()

	chain.Emit(
		"SetDevOpsPct",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
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
func (pf *protocolFeeV1) SetGovStakerPct(_ int, rlm realm, pct int64) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedProtocolFee()

	prev := rlm.Previous()
	access.AssertIsAdminOrGovernance(prev.Address())

	assertIsValidPercent(pct)

	prevDevOpsPct := pf.getProtocolFeeState().DevOpsPct()
	prevGovStakerPct := pf.getProtocolFeeState().GovStakerPct()

	newGovStakerPct, err := pf.getProtocolFeeState().setGovStakerPct(0, rlm, pct)
	if err != nil {
		panic(err)
	}
	newDevOpsPct := pf.getProtocolFeeState().DevOpsPct()

	chain.Emit(
		"SetGovStakerPct",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
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
func (pf *protocolFeeV1) AddToProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errSpoofedRealm
	}

	if halt.IsHaltedProtocolFee() {
		return errProtocolFeeHalted
	}

	prev := rlm.Previous()
	caller := prev.Address()
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

	pf.reserveCollectedProtocolFee(0, rlm, tokenPath, amount)
	protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	common.SafeGRC20TransferFrom(cross(rlm), tokenPath, caller, protocolFeeAddr, amount)

	chain.Emit(
		"AddToProtocolFee",
		"prevAddr", caller.String(),
		"prevRealm", prev.PkgPath(),
		"tokenPath", tokenPath,
		"amount", strconv.FormatInt(amount, 10),
	)

	return nil
}

func (pf *protocolFeeV1) reserveCollectedProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	pfs := pf.getProtocolFeeState()

	toDevOpsAmount := safeMulDiv(amount, pfs.DevOpsPct(), 10000)
	toGovStakerAmount := safeSubInt64(amount, toDevOpsAmount)

	if err := pfs.addAccuToDevOps(0, rlm, tokenPath, toDevOpsAmount); err != nil {
		panic(err)
	}
	if err := pfs.addAccuToGovStaker(0, rlm, tokenPath, toGovStakerAmount); err != nil {
		panic(err)
	}

	if err := pfs.store.AddReservedToken(0, rlm, tokenPath); err != nil {
		panic(err)
	}
}
