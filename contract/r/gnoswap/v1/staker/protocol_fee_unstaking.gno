package staker

import (
	"std"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"

	pf "gno.land/r/gnoswap/v1/protocol_fee"
)

const FEE_PRECISION = 10000

// unstakingFee is the fee charged when unstaking positions.
// This parameter can be modified through governance.
var unstakingFee = int64(100) // 1%

// GetUnstakingFee returns the current unstaking fee rate in basis points.
func GetUnstakingFee() int64 { return unstakingFee }

// handleUnStakingFee calculates and applies the unstaking fee.
func handleUnStakingFee(
	tokenPath string,
	amount int64,
	internal bool,
	positionId uint64,
	poolPath string,
) (int64, int64, error) {
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
	common.Transfer(cross, tokenPath, protocolFeeAddr, feeAmount)
	pf.AddToProtocolFee(cross, tokenPath, feeAmount)

	return amount - feeAmount, feeAmount, nil
}

// SetUnStakingFee sets the unstaking fee rate in basis points.
// Only admin or governance can call this function.
func SetUnStakingFee(cur realm, fee int64) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidFeeRate(fee)

	prevUnStakingFee := GetUnstakingFee()

	setUnStakingFee(fee)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetUnStakingFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatAnyInt(prevUnStakingFee),
		"newFee", formatAnyInt(fee),
	)
}

// setUnStakingFee internally updates the unstaking fee.
func setUnStakingFee(fee int64) {
	unstakingFee = fee
}
