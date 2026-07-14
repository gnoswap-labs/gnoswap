package v1

import (
	"gno.land/r/gnoswap/protocol_fee"
)

func init(cur realm) {
	registerProtocolFeeV1(cur)
}

func registerProtocolFeeV1(cur realm) {
	protocol_fee.RegisterInitializer(cross(cur), func(_ int, rlm realm, protocolFeeStore protocol_fee.IProtocolFeeStore) protocol_fee.IProtocolFee {
		// `rlm` here is the protocol_fee proxy realm threaded in by
		// protocol_fee.RegisterInitializer. Per-version store bootstrap
		// writes therefore pass the proxy's KV-store ACL.
		err := initStoreData(0, rlm, protocolFeeStore)
		if err != nil {
			panic(err)
		}

		return NewProtocolFeeV1(protocolFeeStore)
	})
}

func initStoreData(_ int, rlm realm, protocolFeeStore protocol_fee.IProtocolFeeStore) error {
	if !protocolFeeStore.HasDevOpsPctStoreKey() {
		err := protocolFeeStore.InitializeDevOpsPct(0, rlm)
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasAccuToGovStakerStoreKey() {
		err := protocolFeeStore.InitializeAccuToGovStaker(0, rlm)
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasAccuToDevOpsStoreKey() {
		err := protocolFeeStore.InitializeAccuToDevOps(0, rlm)
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasDistributedToGovStakerHistoryStoreKey() {
		err := protocolFeeStore.InitializeDistributedToGovStakerHistory(0, rlm)
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasDistributedToDevOpsHistoryStoreKey() {
		err := protocolFeeStore.InitializeDistributedToDevOpsHistory(0, rlm)
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasReservedTokensStoreKey() {
		err := protocolFeeStore.InitializeReservedTokens(0, rlm)
		if err != nil {
			return err
		}
	}

	return nil
}
