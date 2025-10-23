package governance

import (
	"chain"
	"chain/runtime"
	"errors"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"

	"gno.land/r/gnoswap/access"
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
	govStakerAddress := access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	kvStore.AddAuthorizedCaller(govStakerAddress, store.ReadOnly)

	adminAddress := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	kvStore.AddAuthorizedCaller(adminAddress, store.ReadOnly)

	// Allow test package to read governance state
	testPackageAddress := chain.PackageAddress("gno.land/r/gnoswap/v1/main")
	kvStore.AddAuthorizedCaller(testPackageAddress, store.ReadOnly)
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
