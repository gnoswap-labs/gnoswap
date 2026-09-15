package protocol_fee

import (
	"gno.land/r/gnoswap/protocol_fee"
)

// init registers the protocol-fee v1 implementation with its parent protocol-fee realm.
//
// Parameters:
//   - cur: Current realm context supplied by the runtime; it is forwarded as cross(cur) when registering the initializer.
func init(cur realm) {
	registerProtocolFeeV1(cur)
}

// registerProtocolFeeV1 registers the v1 implementation initializer in the protocol_fee realm.
//
// Parameters:
//   - cur: Current realm context; this function crosses into protocol_fee.RegisterInitializer with cross(cur).
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

// initStoreData initializes every protocol-fee v1 store entry that is missing.
//
// Parameters:
//   - _: Initializer callback discriminator; pass 0.
//   - rlm: Propagated protocol_fee realm context used by each store write; store methods validate that it is current.
//   - protocolFeeStore: Store implementation whose missing percentage, allocation, distribution-history, reservation, and accrual keys are initialized.
//
// Returns:
//   - err: Nil after all missing entries are initialized or already present; the first initialization error otherwise.
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

	if !protocolFeeStore.HasAccrualEpochStoreKey() {
		err := protocolFeeStore.InitializeAccrualEpoch(0, rlm)
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasAccrualBucketsStoreKey() {
		err := protocolFeeStore.InitializeAccrualBuckets(0, rlm)
		if err != nil {
			return err
		}
	}

	if !protocolFeeStore.HasAccrualPendingTokensStoreKey() {
		err := protocolFeeStore.InitializeAccrualPendingTokens(0, rlm)
		if err != nil {
			return err
		}
	}

	return nil
}
