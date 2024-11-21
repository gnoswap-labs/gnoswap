package pool

import (
	"std"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/p/demo/ufmt"
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

// SetPoolCreationFeeByAdmin sets the poolCreationFee.
func SetPoolCreationFeeByAdmin(fee uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	setPoolCreationFee(fee)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetPoolCreationFeeByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

// SetPoolCreationFee sets the poolCreationFee.
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_pool_creation.gno#setpoolcreationfee
func SetPoolCreationFee(fee uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	setPoolCreationFee(fee)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetPoolCreationFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

func setPoolCreationFee(fee uint64) {
	common.IsHalted()

	poolCreationFee = fee
}
