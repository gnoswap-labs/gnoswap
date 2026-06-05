package v1

import (
	"chain"
	"errors"

	prbac "gno.land/p/gnoswap/rbac"
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
	unstakingFee := s.GetUnstakingFee()
	if unstakingFee == 0 {
		s.addToProtocolFee(0, rlm)
		return amount, 0, nil
	}

	// Do not change the order of the operation.
	feeAmount := safeMulDivInt64(amount, safeUint64ToInt64(unstakingFee), 10000)
	if feeAmount < 0 {
		return 0, 0, errors.New("fee amount cannot be negative")
	}

	if feeAmount == 0 {
		s.addToProtocolFee(0, rlm)
		return amount, 0, nil
	}

	if internal {
		tokenPath = GNS_PATH
	}

	s.addPendingProtocolFee(0, rlm, tokenPath, feeAmount)
	s.addToProtocolFee(0, rlm)

	return safeSubInt64(amount, feeAmount), feeAmount, nil
}

func (s *stakerV1) addPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if amount <= 0 {
		return
	}

	existingProtocolFees := s.store.GetPendingProtocolFees()
	pendingProtocolFees := make(map[string]int64)
	for pendingTokenPath, pendingAmount := range existingProtocolFees {
		pendingProtocolFees[pendingTokenPath] = pendingAmount
	}
	pendingProtocolFees[tokenPath] = safeAddInt64(pendingProtocolFees[tokenPath], amount)
	if err := s.store.SetPendingProtocolFees(0, rlm, pendingProtocolFees); err != nil {
		panic(err)
	}
}

// addToProtocolFee sends pending staker protocol fees to the protocol fee realm.
// It is best-effort: when protocol fee collection is halted, it keeps pending
// storage unchanged; otherwise it rebuilds pending storage with only entries
// that could not be added, removing successful and non-positive entries.
func (s *stakerV1) addToProtocolFee(_ int, rlm realm) {
	pendingProtocolFees := s.store.GetPendingProtocolFees()
	if len(pendingProtocolFees) == 0 || halt.IsHaltedProtocolFee() {
		return
	}

	protocolFeeAddr := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	remainingProtocolFees := make(map[string]int64)
	for tokenPath, amount := range pendingProtocolFees {
		if amount <= 0 {
			continue
		}

		common.SafeGRC20Approve(cross(rlm), tokenPath, protocolFeeAddr, amount)
		if err := pf.AddToProtocolFee(cross(rlm), tokenPath, amount); err != nil {
			remainingProtocolFees[tokenPath] = amount
			continue
		}
	}

	if err := s.store.SetPendingProtocolFees(0, rlm, remainingProtocolFees); err != nil {
		panic(err)
	}
}

// SetUnStakingFee sets the unstaking fee rate in basis points.
// Only admin or governance can call this function.
func (s *stakerV1) SetUnStakingFee(_ int, rlm realm, fee uint64) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

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
		"prevFee", formatUint(prevUnStakingFee),
		"newFee", formatUint(fee),
	)
}

// setUnStakingFee internally updates the unstaking fee.
func (s *stakerV1) setUnStakingFee(_ int, rlm realm, fee uint64) error {
	return s.store.SetUnstakingFee(0, rlm, fee)
}
