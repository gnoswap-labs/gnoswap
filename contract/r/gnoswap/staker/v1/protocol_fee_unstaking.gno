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
//
// Returns:
//   - uint64: Current fee rate in basis points; 100 basis points equals 1%.
func (s *stakerV1) GetUnstakingFee() uint64 { return s.store.GetUnstakingFee() }

// handleStakingRewardFee calculates the unstaking fee and settles it for the reward token.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context used to settle the fee through token and protocol-fee realms.
//   - tokenPath: Reward-token path; replaced with GNS_TOKEN_KEY when internal is true.
//   - amount: Reward amount before the unstaking fee, in token units.
//   - internal: True when amount is an internal GNS reward; false for an external reward token.
//   - unstakingFee: Fee rate in basis points used by the 10,000-basis-point calculation.
//
// Returns:
//   - int64: Reward amount remaining after the fee.
//   - int64: Fee amount sent or recorded as pending for the protocol-fee realm.
//   - error: Non-nil if fee calculation produces a negative fee amount; nil otherwise.
func (s *stakerV1) handleStakingRewardFee(
	_ int,
	rlm realm,
	tokenPath string,
	amount int64,
	internal bool,
	unstakingFee uint64,
) (int64, int64, error) {
	if internal {
		tokenPath = GNS_TOKEN_KEY
	}

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

// GetPendingProtocolFees returns pending protocol fee amounts keyed by reward-token path.
//
// Returns:
//   - map[string]int64: Pending fee amount per token path awaiting a later settlement.
func (s *stakerV1) GetPendingProtocolFees() map[string]int64 {
	return s.store.GetPendingProtocolFees()
}

// addPendingProtocolFee adds a positive amount to the pending protocol fee for tokenPath.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context used to persist the updated pending amount.
//   - tokenPath: Reward-token path whose pending fee entry is updated.
//   - amount: Fee amount to add; zero or a negative amount is ignored.
func (s *stakerV1) addPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if amount <= 0 {
		return
	}

	pendingAmount := gnsmath.SafeAddInt64(s.store.GetPendingProtocolFee(tokenPath), amount)
	if err := s.store.SetPendingProtocolFee(0, rlm, tokenPath, pendingAmount); err != nil {
		panic(err)
	}
}

// settleProtocolFee forwards amount and any existing pending fee for tokenPath to the protocol-fee
// realm. When collection is halted or forwarding fails, the amount remains pending for a later call.
// Every fee path invokes this helper even when amount is zero, so an older pending balance can settle.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context used for token approval, transfer, and pending-state updates.
//   - tokenPath: Reward-token path whose current and pending fee amounts are settled.
//   - amount: Newly accrued fee amount to add to the pending balance before forwarding.
func (s *stakerV1) settleProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if halt.IsHaltedProtocolFee() {
		s.addPendingProtocolFee(0, rlm, tokenPath, amount)
		return
	}

	pendingAmount := s.store.GetPendingProtocolFee(tokenPath)
	totalAmount := gnsmath.SafeAddInt64(pendingAmount, amount)

	if totalAmount > 0 {
		protocolFeeAddr := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
		common.SafeGRC20Approve(0, rlm, tokenPath, protocolFeeAddr, totalAmount)

		// AddToProtocolFee only reports an error for a halted realm, which is handled
		// above. The branch keeps the amount pending should that ever change, and
		// withdraws the approval so no unspent allowance outlives the call.
		if err := pf.AddToProtocolFee(cross(rlm), tokenPath, totalAmount); err != nil {
			common.SafeGRC20Approve(0, rlm, tokenPath, protocolFeeAddr, 0)
			s.addPendingProtocolFee(0, rlm, tokenPath, amount)
			return
		}
	}

	if err := s.store.RemovePendingProtocolFee(0, rlm, tokenPath); err != nil {
		panic(err)
	}
}

// SetUnStakingFee sets the unstaking fee rate in basis points.
// Only admin or governance can call this function.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context; it must be current before changing the stored fee.
//   - fee: New unstaking fee rate in basis points, validated against the configured maximum.
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

// setUnStakingFee persists the unstaking fee rate for the staker implementation.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context passed to the store update.
//   - fee: Unstaking fee rate in basis points to store.
//
// Returns:
//   - error: Store update error, or nil when the fee is persisted.
func (s *stakerV1) setUnStakingFee(_ int, rlm realm, fee uint64) error {
	return s.store.SetUnstakingFee(0, rlm, fee)
}
