package bridge

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
)

var (
	callbackTree       *avl.Tree
	err                error
)

func init() {
	callbackTree = avl.NewTree()
}

// RegisterCallback registers a callback function for a given namespace and function name.
// Only admin and governance addresses are allowed to register callbacks.
func RegisterCallback(cur realm, namespace, fname string, callback any) {
	originCaller := std.OriginCaller()
	access.AssertIsValidAddress(originCaller)
	access.AssertIsAdminOrGovernance(originCaller)

	key := createKey(namespace, fname)
	if callbackTree.Has(key) {
		panic(ufmt.Errorf("callback already registered for key: %s", key))
	}

	callbackTree.Set(key, callback)
}

// LookupCallback retrieves a callback function by namespace and function name.
// Returns the callback and a boolean indicating if the callback exists.
func LookupCallback(namespace, fname string) (any, bool) {
	key := createKey(namespace, fname)
	return callbackTree.Get(key)
}

// UpdateCallback updates an existing callback function for a given namespace and function name.
// Only admin and governance addresses are allowed to update callbacks.
func UpdateCallback(cur realm, namespace, fname string, newCallback any) {
	originCaller := std.OriginCaller()
	access.AssertIsValidAddress(originCaller)
	access.AssertIsAdminOrGovernance(originCaller)

	key := createKey(namespace, fname)
	if !callbackTree.Has(key) {
		panic(ufmt.Errorf("callback not found for key: %s", key))
	}

	callbackTree.Set(key, newCallback)
}

// createKey creates a unique key by combining namespace and function name.
func createKey(namespace, fname string) string {
	return ufmt.Sprintf("%s/%s", namespace, fname)
}

func getAdminAddress() std.Address {
	return getAccessAddress(prabc.ROLE_ADMIN.String())
}

func getGovernanceAddress() std.Address {
	return getAccessAddress(prabc.ROLE_GOVERNANCE.String())
}

func getAccessAddress(role string) std.Address {
	addr, ok := access.GetAddress(role)
	if !ok {
		panic(ufmt.Errorf("address not found for role: %s", role))
	}

	return addr
}