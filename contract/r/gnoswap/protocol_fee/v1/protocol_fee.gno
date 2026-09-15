package protocol_fee

import (
	"chain"
	"errors"
	"strconv"

	ufmt "gno.land/p/nt/ufmt/v0"

	gnsmath "gno.land/p/gnoswap/gnsmath"
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
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0
//   - rlm: propagated protocol_fee realm context; it must match the current crossing frame
func (pf *protocolFeeV1) DistributeProtocolFee(_ int, rlm realm) {
	access.AssertIsRlmCurrent(0, rlm)

	prev := rlm.Previous()
	assertIsAdminOrGovStaker(prev.Address())

	if halt.IsHaltedWithdraw() {
		return
	}

	protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	pfs := pf.getProtocolFeeState()

	reservedTokens := pfs.ReservedTokens()

	for _, token := range reservedTokens {
		pf.distributeProtocolFeeForToken(
			0,
			rlm,
			pfs,
			protocolFeeAddr,
			token,
		)
	}
}

// DistributeProtocolFeeByTokenPath distributes collected protocol fees for one token path.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0
//   - rlm: propagated protocol_fee realm context; it must match the current crossing frame
//   - tokenPath: token contract path whose reserved fee is eligible for distribution
func (pf *protocolFeeV1) DistributeProtocolFeeByTokenPath(_ int, rlm realm, tokenPath string) {
	access.AssertIsRlmCurrent(0, rlm)

	prev := rlm.Previous()
	assertIsAdminOrGovStaker(prev.Address())

	if halt.IsHaltedWithdraw() {
		return
	}

	protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	pfs := pf.getProtocolFeeState()

	if !pfs.store.HasReservedToken(tokenPath) {
		return
	}

	pf.distributeProtocolFeeForToken(
		0,
		rlm,
		pfs,
		protocolFeeAddr,
		tokenPath,
	)
}

// distributeProtocolFeeForToken validates and distributes one reserved token's pending fees.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0
//   - rlm: propagated protocol_fee realm context used for store writes and token transfers
//   - pfs: protocol fee state wrapper providing allocation and distribution history for the token
//   - protocolFeeAddr: protocol fee holding address whose token balance is checked before transfer
//   - tokenPath: token contract path whose pending DevOps and GovStaker fees are distributed
func (pf *protocolFeeV1) distributeProtocolFeeForToken(_ int, rlm realm, pfs *protocolFeeState, protocolFeeAddr address, tokenPath string) {
	toDevOpsAmount := gnsmath.SafeSubInt64(
		pfs.GetAccuTransferToDevOpsByTokenPath(tokenPath),
		pfs.GetActualDistributedToDevOpsByTokenPath(tokenPath),
	)
	toGovStakerAmount := gnsmath.SafeSubInt64(
		pfs.GetAccuTransferToGovStakerByTokenPath(tokenPath),
		pfs.GetActualDistributedToGovStakerByTokenPath(tokenPath),
	)

	amount := gnsmath.SafeAddInt64(toDevOpsAmount, toGovStakerAmount)
	balance := common.BalanceOf(tokenPath, protocolFeeAddr)

	// amount should be less than or equal to balance
	if amount > balance {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("amount: %d should be less than or equal to balance: %d", amount, balance),
		))
	}

	if err := pfs.removeReservedToken(0, rlm, tokenPath); err != nil {
		panic(err)
	}

	if amount <= 0 {
		return
	}

	// distributeToDevOps and distributeToGovStaker record history before transferring.
	if err := pfs.distributeToDevOps(0, rlm, tokenPath, toDevOpsAmount); err != nil {
		panic(err)
	}
	if err := pfs.distributeToGovStaker(0, rlm, tokenPath, toGovStakerAmount); err != nil {
		panic(err)
	}

	prev := rlm.Previous()

	chain.Emit(
		"TransferProtocolFee",
		"prevAddr", prev.Address().String(),
		"prevRealm", prev.PkgPath(),
		"tokenPath", tokenPath,
		"toDevOpsAmount", strconv.FormatInt(toDevOpsAmount, 10),
		"toGovStakerAmount", strconv.FormatInt(toGovStakerAmount, 10),
		"amount", strconv.FormatInt(amount, 10),
	)
}

// SetDevOpsPct sets the devOpsPct.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0
//   - rlm: propagated protocol_fee realm context; it must match the current crossing frame
//   - pct: percentage for devOps (0-10000, where 10000 = 100%)
//
// Only callable by admin or governance.
// Note: GovStaker percentage is automatically adjusted to (10000 - devOpsPct).
func (pf *protocolFeeV1) SetDevOpsPct(_ int, rlm realm, pct int64) {
	access.AssertIsRlmCurrent(0, rlm)

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
//   - _: cross-call discriminator; callers pass 0
//   - rlm: propagated protocol_fee realm context; it must match the current crossing frame
//   - pct: percentage for gov/staker (0-10000, where 10000 = 100%)
//
// Only callable by admin or governance.
// Note: DevOps percentage is automatically adjusted to (10000 - govStakerPct).
func (pf *protocolFeeV1) SetGovStakerPct(_ int, rlm realm, pct int64) {
	access.AssertIsRlmCurrent(0, rlm)

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
//   - _: cross-call discriminator; callers pass 0
//   - rlm: propagated protocol_fee realm context; a non-current value returns errSpoofedRealm
//   - tokenPath: token contract path from which the approved fee is pulled
//   - amount: non-negative fee amount in token base units; zero returns nil without transferring
//
// Returns:
//   - err: nil on success; errSpoofedRealm for a spoofed-realm call; errProtocolFeeHalted when protocol-fee collection is halted
//
// Only callable by pool, position, router or staker contracts.
// Caller must approve the protocol fee realm for at least amount before calling.
// Note: Accumulated fees are distributed when DistributeProtocolFee is called.
func (pf *protocolFeeV1) AddToProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	if halt.IsHaltedProtocolFee() {
		return errors.New(errProtocolFeeHalted)
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
	common.SafeGRC20TransferFrom(0, rlm, tokenPath, caller, protocolFeeAddr, amount)

	chain.Emit(
		"AddToProtocolFee",
		"prevAddr", caller.String(),
		"prevRealm", prev.PkgPath(),
		"tokenPath", tokenPath,
		"amount", strconv.FormatInt(amount, 10),
	)

	return nil
}

// reserveCollectedProtocolFee allocates a collected fee between DevOps and GovStaker,
// records both allocation accumulators, and marks the token for later distribution.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0
//   - rlm: propagated protocol_fee realm context used for authorized store writes
//   - tokenPath: token contract path whose collected fee is being reserved
//   - amount: non-negative collected fee amount in token base units to split and record
func (pf *protocolFeeV1) reserveCollectedProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	pfs := pf.getProtocolFeeState()

	toDevOpsAmount := gnsmath.SafeMulDivInt64(amount, pfs.DevOpsPct(), 10000)
	toGovStakerAmount := gnsmath.SafeSubInt64(amount, toDevOpsAmount)

	if err := pfs.addAccuToDevOps(0, rlm, tokenPath, toDevOpsAmount); err != nil {
		panic(err)
	}
	if err := pfs.addAccuToGovStaker(0, rlm, tokenPath, toGovStakerAmount); err != nil {
		panic(err)
	}

	if err := pfs.store.AddReservedToken(0, rlm, tokenPath); err != nil {
		panic(err)
	}

	// Bucket the gov/staker share under the accrual epoch in force so that gov/staker
	// can later fold it against the stake distribution that was live when it arrived.
	// A split that leaves gov/staker nothing moves no accumulator, so it is not bucketed.
	if toGovStakerAmount > 0 {
		epoch := pfs.store.GetAccrualEpoch()
		if err := pfs.store.AddAccrualBucket(0, rlm, tokenPath, epoch, toGovStakerAmount); err != nil {
			panic(err)
		}
		if err := pfs.store.AddAccrualPendingToken(0, rlm, tokenPath); err != nil {
			panic(err)
		}
	}
}

// AdvanceAccrualEpoch closes the accrual epoch in force and returns the new one.
//
// gov/staker calls it on every stake change, before it records the new stake
// distribution, so every fee bucketed from now on is attributed to that distribution.
// Restricted to gov/staker: an epoch advanced by anyone else would fragment the buckets
// without a matching stake record on the gov/staker side.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0
//   - rlm: propagated protocol_fee realm context; it must be current and be called by GovStaker
//
// Returns:
//   - epoch: newly stored non-negative accrual epoch for fees collected after the stake change
func (pf *protocolFeeV1) AdvanceAccrualEpoch(_ int, rlm realm) int64 {
	if !rlm.IsCurrent() {
		panic(errors.New(errSpoofedRealm))
	}

	prev := rlm.Previous()
	access.AssertIsGovStaker(prev.Address())

	pfs := pf.getProtocolFeeState()
	epoch := gnsmath.SafeAddInt64(pfs.store.GetAccrualEpoch(), 1)
	if err := pfs.store.SetAccrualEpoch(0, rlm, epoch); err != nil {
		panic(err)
	}

	return epoch
}

// ConsumeAccrualBuckets returns and clears up to limit of the oldest pending buckets of
// tokenPath, as parallel epoch and amount slices in epoch order. A limit of zero or
// less consumes every pending bucket. Once no bucket remains the token leaves the
// pending set.
//
// Restricted to gov/staker: clearing a bucket without folding it into an accumulator
// would strand that fee share.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0
//   - rlm: propagated protocol_fee realm context; it must be current and be called by GovStaker
//   - tokenPath: token contract path whose pending accrual buckets are consumed
//   - limit: maximum number of oldest buckets to consume; zero or negative consumes all pending buckets
//
// Returns:
//   - epochs: consumed accrual epoch numbers in ascending epoch order
//   - amounts: fee amounts corresponding positionally to epochs, in token base units
func (pf *protocolFeeV1) ConsumeAccrualBuckets(_ int, rlm realm, tokenPath string, limit int) ([]int64, []int64) {
	if !rlm.IsCurrent() {
		panic(errors.New(errSpoofedRealm))
	}

	prev := rlm.Previous()
	access.AssertIsGovStaker(prev.Address())

	pfs := pf.getProtocolFeeState()
	epochs, amounts := pfs.store.GetAccrualBuckets(tokenPath, limit)
	if len(epochs) == 0 {
		return epochs, amounts
	}

	if err := pfs.store.RemoveAccrualBuckets(0, rlm, tokenPath, epochs); err != nil {
		panic(err)
	}

	remainingEpochs, _ := pfs.store.GetAccrualBuckets(tokenPath, 1)
	if len(remainingEpochs) == 0 {
		if err := pfs.store.RemoveAccrualPendingToken(0, rlm, tokenPath); err != nil {
			panic(err)
		}
	}

	return epochs, amounts
}
