package v1

import (
	"gno.land/r/gnoswap/protocol_fee"
)

type protocolFeeV1 struct {
	store protocol_fee.IProtocolFeeStore
}

func (pf *protocolFeeV1) getProtocolFeeState() *protocolFeeState {
	return NewProtocolFeeStateBy(pf.store)
}

func NewProtocolFeeV1(protocolFeeStore protocol_fee.IProtocolFeeStore) protocol_fee.IProtocolFee {
	return &protocolFeeV1{
		store: protocolFeeStore,
	}
}
