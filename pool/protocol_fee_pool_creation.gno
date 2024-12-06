package pool

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
)

// poolCreationFee is the fee that is charged when a user creates a pool.
// The fee is denominated in GNS tokens.
var (
	poolCreationFee = uint64(100_000_000) // 100_GNS
)

// GetPoolCreationFee returns the poolCreationFee
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_pool_creation.gno#getpoolcreationfee
func GetPoolCreationFee() uint64 {
	return poolCreationFee
}

// SetPoolCreationFee sets the poolCreationFee.
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_pool_creation.gno#setpoolcreationfee
func SetPoolCreationFee(fee uint64) {
	// TODO:
	// 1. IsHalted name chnage to assertIsHalted
	common.IsHalted()
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err.Error())
	}
	setPoolCreationFee(fee)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"SetPoolCreationFee",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

// SetPoolCreationFeeByAdmin sets the poolCreationFee by Admin.
// Only admin can execute this function.
func SetPoolCreationFeeByAdmin(fee uint64) {
	// TODO:
	// 1. IsHalted name chnage to assertIsHalted
	common.IsHalted()

	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err.Error())
	}
	setPoolCreationFee(fee)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"SetPoolCreationFeeByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

// setPoolCreationFee this function is internal function called by SetPoolCreationFee
// And SetPoolCreationFeeByAdmin
func setPoolCreationFee(fee uint64) {
	poolCreationFee = fee
}
