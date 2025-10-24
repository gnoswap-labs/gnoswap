package governance

import (
	"chain"
	"chain/runtime"
	"errors"

	_ "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"

	_ "gno.land/r/gnoswap/access"
)

var (
	currentAddress = runtime.CurrentRealm().Address()
	domainPath     = runtime.CurrentRealm().PkgPath()

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IGovernance
)

func init() {
	kvStore = store.NewKVStore(currentAddress)
	initRegisterReadableContract()
	versionManager = version_manager.NewVersionManager(domainPath, kvStore, initializeDomainStore)

	implementation = nil
}

func initRegisterReadableContract() {
	/* Allow test package to read governance state (workaround for testing) */

	testPackageAddress := chain.PackageAddress("gno.land/r/gnoswap/v1/main")
	kvStore.AddAuthorizedCaller(testPackageAddress, store.ReadOnly)

	mainAddress := chain.PackageAddress("main")
	kvStore.AddAuthorizedCaller(mainAddress, store.ReadOnly)
}

func initializeDomainStore(kvStore store.KVStore) any {
	return NewGovernanceStore(kvStore)
}

func getImplementation() IGovernance {
	if implementation == nil {
		panic("implementation is not initialized")
	}

	return implementation
}

func updateImplementation() error {
	result := versionManager.GetCurrentImplementation()
	if result == nil {
		return errors.New("implementation is not initialized")
	}

	impl, ok := result.(IGovernance)
	if !ok {
		return errors.New("impl is not an IGovernance")
	}

	implementation = impl

	return nil
}
