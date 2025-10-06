package storage

import (
	"chain/runtime"

	sys_storage "gno.land/p/gnoswap/sys/storage"
	"gno.land/r/gnoswap/access"
)

func IsReadAuthorized(namespace string, caller address) bool {
	namespaceStore, err := getNamespaceStore(namespace)
	if err != nil {
		return false
	}

	return namespaceStore.IsReadAuthorized(caller)
}

func IsWriteAuthorized(namespace string, caller address) bool {
	namespaceStore, err := getNamespaceStore(namespace)
	if err != nil {
		return false
	}

	return namespaceStore.IsWriteAuthorized(caller)
}

func AddAuthorizedCaller(namespace string, authorizedCaller address, permission sys_storage.Permission) error {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	namespaceStore, err := getNamespaceStore(namespace)
	if err != nil {
		return err
	}

	return namespaceStore.AddAuthorizedCaller(authorizedCaller, permission)
}

func UpdateAuthorizedCaller(namespace string, authorizedCaller address, permission sys_storage.Permission) error {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	namespaceStore, err := getNamespaceStore(namespace)
	if err != nil {
		return err
	}

	return namespaceStore.UpdateAuthorizedCaller(authorizedCaller, permission)
}

func RemoveAuthorizedCaller(namespace string, authorizedCaller address) error {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	namespaceStore, err := getNamespaceStore(namespace)
	if err != nil {
		return err
	}

	return namespaceStore.RemoveAuthorizedCaller(authorizedCaller)
}
