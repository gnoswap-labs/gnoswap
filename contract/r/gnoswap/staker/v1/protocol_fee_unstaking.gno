package staker

import (
	"chain"
	"errors"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/utils"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"

	pf "gno.land/r/gnoswap/protocol_fee"
)

// GetUnstakingFee returns the current unstaking fee rate in basis points.
func (s *stakerV1) GetUnstakingFee() uint64 { return s.store.GetUnstakingFee() }

// handleStakingRewardFee calculates and applies the unstaking fee.
func (s *stakerV1) handleStakingRewardFee(
	_ int,
	rlm realm,
	tokenPath string,
	amount int64,
	internal bool,
) (int64, int64, error) {
	if internal {
		tokenPath = GNS_TOKEN_KEY
	}

	unstakingFee := s.GetUnstakingFee()
	if unstakingFee == 0 {
		s.settleProtocolFee(0, rlm, tokenPath, 0)
		return amount, 0, nil
	}

	// Do not change the order of the operation.
	feeAmount := gnsmath.SafeMulDivInt64(amount, gnsmath.SafeUint64ToInt64(unstakingFee), 10000)
	if feeAmount < 0 {
		return 0, 0, errors.New("fee amount cannot be negative")
	}

	if feeAmount == 0 {
		s.settleProtocolFee(0, rlm, tokenPath, 0)
		return amount, 0, nil
	}

	s.settleProtocolFee(0, rlm, tokenPath, feeAmount)

	return gnsmath.SafeSubInt64(amount, feeAmount), feeAmount, nil
}

// GetPendingProtocolFees returns the pending protocol fee amount per token path.
func (s *stakerV1) GetPendingProtocolFees() map[string]int64 {
	return s.store.GetPendingProtocolFees()
}

func (s *stakerV1) addPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if amount <= 0 {
		return
	}

	// The stored map is readonly tainted here, so it is copied before being updated.
	existingProtocolFees := s.store.GetPendingProtocolFees()
	pendingProtocolFees := make(map[string]int64)
	for pendingTokenPath, pendingAmount := range existingProtocolFees {
		pendingProtocolFees[pendingTokenPath] = pendingAmount
	}
	pendingProtocolFees[tokenPath] = gnsmath.SafeAddInt64(pendingProtocolFees[tokenPath], amount)
	if err := s.store.SetPendingProtocolFees(0, rlm, pendingProtocolFees); err != nil {
		panic(err)
	}
}

// settleProtocolFee forwards amount, plus anything already pending for tokenPath, to
// the protocol fee realm. When collection is halted or the transfer fails, the amount
// is recorded as pending instead and settled by a later call for the same token, which
// every fee path makes even when the fee is zero.
//
// Only tokenPath is touched, so an unrelated token can never block settlement. The
// pending entry is written only when the fee cannot be forwarded, so the common path
// performs no store write at all.
func (s *stakerV1) settleProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if halt.IsHaltedProtocolFee() {
		s.addPendingProtocolFee(0, rlm, tokenPath, amount)
		return
	}

	pendingProtocolFees := s.store.GetPendingProtocolFees()
	pendingAmount, hasPending := pendingProtocolFees[tokenPath]
	totalAmount := gnsmath.SafeAddInt64(pendingAmount, amount)

	if totalAmount > 0 {
		protocolFeeAddr := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
		common.SafeGRC20Approve(0, rlm, tokenPath, protocolFeeAddr, totalAmount)

		// AddToProtocolFee only reports an error for a halted realm, which is handled
		// above. The branch keeps the amount pending should that ever change, and
		// withdraws the approval so no unspent allowance outlives the call.
		if err := pf.AddToProtocolFee(cross(rlm), tokenPath, totalAmount); err != nil {
			common.SafeGRC20Approve(cross(rlm), tokenPath, protocolFeeAddr, 0)
			s.addPendingProtocolFee(0, rlm, tokenPath, amount)
			return
		}
	}

	if !hasPending {
		return
	}

	remainingProtocolFees := make(map[string]int64)
	for pendingTokenPath, pending := range pendingProtocolFees {
		if pendingTokenPath == tokenPath {
			continue
		}

		remainingProtocolFees[pendingTokenPath] = pending
	}

	if err := s.store.SetPendingProtocolFees(0, rlm, remainingProtocolFees); err != nil {
		panic(err)
	}
}

// SetUnStakingFee sets the unstaking fee rate in basis points.
// Only admin or governance can call this function.
func (s *stakerV1) SetUnStakingFee(_ int, rlm realm, fee uint64) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedStaker()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidFeeRate(fee)

	prevUnStakingFee := s.GetUnstakingFee()

	err := s.setUnStakingFee(0, rlm, fee)
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"SetUnStakingFee",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", utils.FormatUint(prevUnStakingFee),
		"newFee", utils.FormatUint(fee),
	)
}

// setUnStakingFee internally updates the unstaking fee.
func (s *stakerV1) setUnStakingFee(_ int, rlm realm, fee uint64) error {
	return s.store.SetUnstakingFee(0, rlm, fee)
}
