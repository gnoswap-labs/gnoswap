package v2

import (
	"gno.land/r/gnoswap/protocol_fee"
)

func init() {
	registerProtocolFeeV1()
}

func registerProtocolFeeV1() {
	protocol_fee.RegisterInitializer(cross, func(protocolFeeStore protocol_fee.IProtocolFeeStore) protocol_fee.IProtocolFee {
		err := initStoreData(protocolFeeStore)
		if err != nil {
			panic(err)
		}

		return NewProtocolFeeV1(protocolFeeStore)
	})
}

func initStoreData(protocolFeeStore protocol_fee.IProtocolFeeStore) error {
	if !protocolFeeStore.HasDevOpsPctStoreKey() {
		err := protocolFeeStore.InitializeDevOpsPct()
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasAccuToGovStakerStoreKey() {
		err := protocolFeeStore.InitializeAccuToGovStaker()
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasAccuToDevOpsStoreKey() {
		err := protocolFeeStore.InitializeAccuToDevOps()
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasDistributedToGovStakerHistoryStoreKey() {
		err := protocolFeeStore.InitializeDistributedToGovStakerHistory()
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasDistributedToDevOpsHistoryStoreKey() {
		err := protocolFeeStore.InitializeDistributedToDevOpsHistory()
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasTokenListWithAmountsStoreKey() {
		err := protocolFeeStore.InitializeTokenListWithAmount()
		if err != nil {
			return err
		}
	}

	return nil
}
