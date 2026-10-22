package protocol_fee

import (
	"gno.land/r/gnoswap/protocol_fee"
)

type protocolFeeV1 struct {
	store protocol_fee.IProtocolFeeStore
}

func (pf *protocolFeeV1) getProtocolFeeState() *protocolFeeState {
	return NewProtocolFeeStateBy(pf.store)
}

// NewProtocolFeeV1 creates the protocol-fee v1 implementation backed by protocolFeeStore.
//
// Parameters:
//   - protocolFeeStore: Store implementation containing the protocol-fee state for this version.
//
// Returns:
//   - implementation: An IProtocolFee implementation that exposes v1 behavior through protocolFeeStore.
func NewProtocolFeeV1(protocolFeeStore protocol_fee.IProtocolFeeStore) protocol_fee.IProtocolFee {
	return &protocolFeeV1{
		store: protocolFeeStore,
	}
}
