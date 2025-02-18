package staker

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/protocol_fee"
)

// EmissionI defines the interface for emission realm interactions
type EmissionI struct {
	MintAndDistributeGns        func() uint64
	GetDistributedToGovStaker   func() uint64
	ClearDistributedToGovStaker func()
}

// ProtocolFeeI defines the interface for protocol_fee realm interactions
type ProtocolFeeI struct {
	DistributeProtocolFee        func()
	GetAccuTransferToGovStaker   func() *avl.Tree
	ClearAccuTransferToGovStaker func()
}

// en is the emission interface instance
var en EmissionI = EmissionI{
	MintAndDistributeGns:        emission.MintAndDistributeGns,
	GetDistributedToGovStaker:   emission.GetDistributedToGovStaker,
	ClearDistributedToGovStaker: emission.ClearDistributedToGovStaker,
}

// pf is the protocol_fee interface instance
var pf ProtocolFeeI = ProtocolFeeI{
	DistributeProtocolFee:        protocol_fee.DistributeProtocolFee,
	GetAccuTransferToGovStaker:   protocol_fee.GetAccuTransferToGovStaker,
	ClearAccuTransferToGovStaker: protocol_fee.ClearAccuTransferToGovStaker,
}

// SetEmissionRealm replaces the emission interface implementation
func SetEmissionRealm(newEn EmissionI) {
	// caller := std.PrevRealm().Addr()
	// if !governance.IsPermittedSetter(caller) {
	// 	panic("caller not permitted to set realm implementation")
	// }
	en = newEn
}

// SetProtocolFeeRealm replaces the protocol fee interface implementation
func SetProtocolFeeRealm(newPf ProtocolFeeI) {
	// caller := std.PrevRealm().Addr()
	// if !governance.IsPermittedSetter(caller) {
	// 	panic("caller not permitted to set realm implementation")
	// }
	pf = newPf
}
