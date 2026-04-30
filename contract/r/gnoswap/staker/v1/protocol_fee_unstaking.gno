package v1

import (
	"chain"
	"chain/runtime"
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
	tokenPath string,
	amount int64,
	internal bool,
) (int64, int64, error) {
	s.tryCollectPendingProtocolFees()

	unstakingFee := s.GetUnstakingFee()
	if unstakingFee == 0 {
		return amount, 0, nil
	}

	// Do not change the order of the operation.
	feeAmount := safeMulDivInt64(amount, safeUint64ToInt64(unstakingFee), 10000)
	if feeAmount < 0 {
		return 0, 0, errors.New("fee amount cannot be negative")
	}

	if feeAmount == 0 {
		return amount, 0, nil
	}

	if internal {
		tokenPath = GNS_PATH
	}

	s.addPendingProtocolFee(tokenPath, feeAmount)
	s.tryCollectPendingProtocolFees()

	return safeSubInt64(amount, feeAmount), feeAmount, nil
}

func (s *stakerV1) addPendingProtocolFee(tokenPath string, amount int64) {
	if amount <= 0 {
		return
	}

	pendingProtocolFees := clonePendingProtocolFees(s.store.GetPendingProtocolFees())
	pendingProtocolFees[tokenPath] = safeAddInt64(pendingProtocolFees[tokenPath], amount)
	if err := s.store.SetPendingProtocolFees(pendingProtocolFees); err != nil {
		panic(err)
	}
}

func (s *stakerV1) tryCollectPendingProtocolFees() {
	pendingProtocolFees := clonePendingProtocolFees(s.store.GetPendingProtocolFees())
	if len(pendingProtocolFees) == 0 || halt.IsHaltedProtocolFee() {
		return
	}

	protocolFeeAddr := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	for tokenPath, amount := range pendingProtocolFees {
		if amount <= 0 {
			delete(pendingProtocolFees, tokenPath)
			continue
		}

		common.SafeGRC20Approve(cross, tokenPath, protocolFeeAddr, amount)
		if err := pf.AddToProtocolFee(cross, tokenPath, amount); err != nil {
			return
		}
		delete(pendingProtocolFees, tokenPath)
	}

	if err := s.store.SetPendingProtocolFees(pendingProtocolFees); err != nil {
		panic(err)
	}
}

func clonePendingProtocolFees(src map[string]int64) map[string]int64 {
	clone := make(map[string]int64, len(src))
	for key, value := range src {
		clone[key] = value
	}
	return clone
}

// SetUnStakingFee sets the unstaking fee rate in basis points.
// Only admin or governance can call this function.
func (s *stakerV1) SetUnStakingFee(fee uint64) {
	halt.AssertIsNotHaltedStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidFeeRate(fee)

	prevUnStakingFee := s.GetUnstakingFee()

	err := s.setUnStakingFee(fee)
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
func (s *stakerV1) setUnStakingFee(fee uint64) error {
	return s.store.SetUnstakingFee(fee)
}
