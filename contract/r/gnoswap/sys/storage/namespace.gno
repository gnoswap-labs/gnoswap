package storage

import (
	"chain/runtime"
	"strings"

	sys_storage "gno.land/p/gnoswap/sys/storage"
	"gno.land/r/gnoswap/access"
)

func GetNamespaceKeys() ([]string, error) {
	return systemStorage.GetNamespaceKeys()
}

func HasNamespace(namespace string) bool {
	return systemStorage.HasStore(namespace)
}

func GetNamespace() (sys_storage.KVStore, error) {
	previousRealm := runtime.PreviousRealm()
	if previousRealm.IsUser() {
		return nil, errOnlyAccessibleFromGnoswapRealm
	}

	namespace := previousRealm.PkgPath()

	namespaceStore, err := systemStorage.GetStore(namespace)
	if err != nil {
		return nil, err
	}

	caller := previousRealm.Address()
	if !namespaceStore.IsReadAuthorized(caller) {
		return nil, sys_storage.ErrReadPermissionDenied
	}

	return namespaceStore, nil
}

func RegisterNamespace() {
	originCaller := runtime.OriginCaller()
	access.AssertIsAdmin(originCaller)

	if !isAllowedToRegisterNamespace() {
		panic(sys_storage.ErrReadPermissionDenied)
	}

	namespace := runtime.PreviousRealm().PkgPath()
	AssertIsValidNamespace(namespace)

	err := systemStorage.RegisterStore(namespace)
	if err != nil {
		panic(err)
	}
}

func RemoveNamespace(namespace string) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdmin(caller)

	err := systemStorage.RemoveStore(namespace)
	if err != nil {
		panic(err)
	}
}

func getNamespaceStore(namespace string) (sys_storage.KVStore, error) {
	namespaceStore, err := systemStorage.GetStore(namespace)
	if err != nil {
		return nil, err
	}

	return namespaceStore, nil
}

func isAllowedToRegisterNamespace() bool {
	previousRealm := runtime.PreviousRealm()
	if previousRealm.IsUser() {
		return false
	}

	return strings.HasPrefix(previousRealm.PkgPath(), gnoswapNamespacePrefix)
}
