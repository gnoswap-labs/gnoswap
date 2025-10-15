package v1

import (
	"gno.land/r/gnoswap/protocol_fee"
)

func init() {
	registerProtocolFeeV1()
}

func registerProtocolFeeV1() {
	protocol_fee.RegisterInitializer(cross, func(protocolFeeStore protocol_fee.IProtocolFeeStore) protocol_fee.IProtocolFee {
		return NewProtocolFeeV1(protocolFeeStore)
	})
}
