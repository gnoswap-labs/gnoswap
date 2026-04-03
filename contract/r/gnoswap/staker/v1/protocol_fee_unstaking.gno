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
func (s *stakerV1) handleStakingRewardFee(
	tokenPath string,
	amount int64,
	internal bool,
) (int64, int64, error) {
	return s.handleStakingFee(tokenPath, amount, internal, false)
}

func (s *stakerV1) handleStakingFee(
	tokenPath string,
	amount int64,
	internal bool,
	recovery bool,
) (int64, int64, error) {
	unstakingFee := s.GetUnstakingFee()
	if unstakingFee == 0 {
		return amount, 0, nil
	}

	// Do not change the order of the operation.
	feeAmount := safeMulDivInt64(amount, unstakingFee, 10000)
	if feeAmount < 0 {
		return 0, 0, errors.New("fee amount cannot be negative")
	}

	if feeAmount == 0 {
		return amount, 0, nil
	}

	if internal {
		tokenPath = GNS_PATH
	}

	// Emergency keeps unstake recovery available, so recovery=true bypasses the
	// protocol_fee halt check but still transfers and records the accrued fee.
	if !recovery {
		halt.AssertIsNotHaltedProtocolFee()
	}

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
