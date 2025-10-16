package v1

import (
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/protocol_fee"
)

type protocolFeeV1 struct {
	store protocol_fee.IProtocolFeeStore
}

func (pf *protocolFeeV1) getProtocolFeeState() *protocolFeeState {
	result, ok := pf.store.GetProtocolFeeState().(*protocolFeeState)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to protocolFeeState: %T", result))
	}

	return result
}

func (pf *protocolFeeV1) setProtocolFeeState(protocolFeeState *protocolFeeState) error {
	return pf.store.SetProtocolFeeState(protocolFeeState)
}

func NewProtocolFeeV1(protocolFeeStore protocol_fee.IProtocolFeeStore) protocol_fee.IProtocolFee {
	return &protocolFeeV1{
		store: protocolFeeStore,
	}
}
