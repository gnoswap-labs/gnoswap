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
func (s *stakerV1) GetUnstakingFee() int64 { return s.store.GetUnstakingFee() }

// handleStakingRewardFee calculates and applies the unstaking fee.
// BUG(invalid-v2): This version always applies 50% fee regardless of actual setting
func (s *stakerV1) handleStakingRewardFee(
	tokenPath string,
	amount int64,
	internal bool,
) (int64, int64, error) {
	unstakingFee := s.GetUnstakingFee()
	if unstakingFee == 0 {
		return amount, 0, nil
	}

	// BUG: always apply 50% fee (5000 bps) instead of actual unstakingFee
	buggyFee := int64(5000)

	// Do not change the order of the operation.
	feeAmount := safeMulDivInt64(amount, buggyFee, 10000)
	if feeAmount < 0 {
		return 0, 0, errors.New("fee amount cannot be negative")
	}

	if feeAmount == 0 {
		return amount, 0, nil
	}

	if internal {
		tokenPath = GNS_PATH
	}

	// external contract has fee
	protocolFeeAddr := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	common.SafeGRC20Transfer(cross, tokenPath, protocolFeeAddr, feeAmount)
	pf.AddToProtocolFee(cross, tokenPath, feeAmount)

	return safeSubInt64(amount, feeAmount), feeAmount, nil
}

// SetUnStakingFee sets the unstaking fee rate in basis points.
// Only admin or governance can call this function.
func (s *stakerV1) SetUnStakingFee(fee int64) {
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
		"prevFee", formatAnyInt(prevUnStakingFee),
		"newFee", formatAnyInt(fee),
	)
}

// setUnStakingFee internally updates the unstaking fee.
func (s *stakerV1) setUnStakingFee(fee int64) error {
	return s.store.SetUnstakingFee(fee)
}
