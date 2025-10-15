package protocol_fee

import (
	"chain/runtime"

	"gno.land/p/gnoswap/store"
)

var (
	kvStore store.KVStore

	protocolFeeImpl IProtocolFee

	initializers map[string]func(protocolFeeStore IProtocolFeeStore) IProtocolFee
)

func init() {
	// Create a new KV store instance for this domain
	kvStore = store.NewKVStore(runtime.CurrentRealm().Address())

	// Initialize the initializers map to store implementation registration functions
	initializers = make(map[string]func(protocolFeeStore IProtocolFeeStore) IProtocolFee)
}
