package bridge

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/access"
)

var (
	callbackTree *avl.Tree
	adminAddr    std.Address
	govAddr      std.Address
	err          error
)

func init() {
	callbackTree = avl.NewTree()

	adminAddr, err = access.GetAddress(access.ROLE_ADMIN)
	if err != nil {
		panic(err)
	}
	govAddr, err = access.GetAddress(access.ROLE_GOVERNANCE)
	if err != nil {
		panic(err)
	}
}

const (
	MINT_AND_DISTRIBUTE_GNS_KEY = "gno.land/r/gnoswap/v1/emission/MintAndDistributeGns"
)

// RegisterCallback registers a callback function with the given key
func RegisterCallback(key string, callback any) {
	if callbackTree.Has(key) {
		panic("callback already registered for key: " + key)
	}
	callbackTree.Set(key, callback)
}

func RegisterCallback2(caller std.Address, namespace, fname string, callback any) error {
	if !caller.IsValid() {
		return ufmt.Errorf("invalid caller address: %s", caller)
	}

	// TODO: governance?
	if err := common.AdminOnly(caller); err != nil {
		return err
	}

	key := createKey(namespace, fname)
	if callbackTree.Has(key) {
		return ufmt.Errorf("callback already registered for key: %s", key)
	}
	callbackTree.Set(key, callback)
	return nil
}

// GetCallback retrieves a callback function by key
func GetCallback(key string) (any, bool) {
	return callbackTree.Get(key)
}

func GetCallback2(namespace, fname string) (any, bool) {
	key := createKey(namespace, fname)
	return callbackTree.Get(key)
}

func UpdateCallback(caller std.Address, namespace, fname string, newCallback any) error {
	if !caller.IsValid() {
		return ufmt.Errorf("invalid caller address: %s", caller)
	}

	// allow only admin and governance
	if caller != adminAddr && caller != govAddr {
		return ufmt.Errorf("unauthorized caller: %s", caller)
	}

	key := createKey(namespace, fname)
	if !callbackTree.Has(key) {
		return ufmt.Errorf("callback not found for key: %s", key)
	}
	callbackTree.Set(key, newCallback)
	return nil
}

func createKey(namespace, fname string) string {
	return ufmt.Sprintf("%s/%s", namespace, fname)
}
