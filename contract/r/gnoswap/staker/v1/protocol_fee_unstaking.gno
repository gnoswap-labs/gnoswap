package v1

import (
	"chain"
	"chain/runtime"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"

	pf "gno.land/r/gnoswap/protocol_fee"
)

const FEE_PRECISION = 10000

// GetUnstakingFee returns the current unstaking fee rate in basis points.
func (s *stakerV1) GetUnstakingFee() int64 { return s.store.GetUnstakingFee() }

// handleStakingRewardFee calculates and applies the unstaking fee.
func (s *stakerV1) handleStakingRewardFee(
	tokenPath string,
	amount int64,
	internal bool,
) (int64, int64, error) {
	unstakingFee := s.GetUnstakingFee()
	if unstakingFee == 0 {
		return amount, 0, nil
	}

	// Do not change the order of the operation.
	feeAmount := (amount * unstakingFee) / FEE_PRECISION
	if feeAmount < 0 {
		return 0, 0, ufmt.Errorf("fee amount cannot be negative")
	}

	if feeAmount == 0 {
		return amount, 0, nil
	}

	if internal {
		tokenPath = GNS_PATH
	}

	// external contract has fee
	common.SafeGRC20Transfer(cross, tokenPath, protocolFeeAddr, feeAmount)
	pf.AddToProtocolFee(cross, tokenPath, feeAmount)

	return amount - feeAmount, feeAmount, nil
}

// SetUnStakingFee sets the unstaking fee rate in basis points.
// Only admin or governance can call this function.
func (s *stakerV1) SetUnStakingFee(fee int64) {
	halt.AssertIsNotHaltedStaker()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidFeeRate(fee)

	prevUnStakingFee := s.GetUnstakingFee()

	err := s.setUnStakingFee(fee)
	if err != nil {
		panic(err)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetUnStakingFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatAnyInt(prevUnStakingFee),
		"newFee", formatAnyInt(fee),
	)
}

// setUnStakingFee internally updates the unstaking fee.
func (s *stakerV1) setUnStakingFee(fee int64) error {
	return s.store.SetUnstakingFee(fee)
}
