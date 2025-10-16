package version_manager

import (
	"chain"
	"chain/runtime"
	"errors"
	"strings"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

type versionManager struct {
	initializers            *avl.Tree
	domainKVStore           store.KVStore
	initializeDomainStoreFn func(kvStore store.KVStore) any

	domainPath            string
	currentPackagePath    string
	currentImplementation any
}

func (vm *versionManager) RegisterInitializer(initializer func(store any) any) error {
	// Ensure the caller is within the domain path (e.g., protocol_fee/v1, protocol_fee/v2)
	if !vm.isContainDomainPath() {
		return errors.New("version_manager: caller is not in the domain path")
	}

	previousRealm := runtime.PreviousRealm()
	targetPackagePath := previousRealm.PkgPath()

	// Check if this package path has already been registered
	if vm.initializers.Has(targetPackagePath) {
		return errors.New("version_manager: initializer already registered")
	}

	// Register the initializer function for this package path
	vm.initializers.Set(targetPackagePath, initializer)

	initialized := vm.currentImplementation != nil
	if initialized {
		return vm.domainKVStore.AddAuthorizedCaller(previousRealm.Address(), store.ReadOnly)
	}

	vm.currentPackagePath = targetPackagePath
	vm.currentImplementation = initializer(vm.initializeDomainStoreFn(vm.domainKVStore))

	return vm.domainKVStore.AddAuthorizedCaller(previousRealm.Address(), store.Write)
}

func (vm *versionManager) ChangeImplementation(packagePath string) error {
	// Verify the target implementation has been registered
	if !vm.initializers.Has(packagePath) {
		return errors.New("version_manager: initializer not found for package path:" + packagePath)
	}

	// Switch to the new implementation
	result, ok := vm.initializers.Get(packagePath)
	if !ok {
		return errors.New("version_manager: initializer not found for package path:" + packagePath)
	}

	initializer, ok := result.(func(store any) any)
	if !ok {
		return errors.New("version_manager: initializer is not a function")
	}

	vm.currentImplementation = initializer(vm.initializeDomainStoreFn(vm.domainKVStore))
	packageAddress := chain.PackageAddress(vm.currentPackagePath)

	// Update storage permissions for all registered implementations
	storeAuthorizedCallers, err := vm.domainKVStore.GetAuthorizedCallers()
	if err != nil {
		return err
	}

	// Set all implementations to read-only except the new active one
	for caller, _ := range storeAuthorizedCallers {
		updatedPermission := store.ReadOnly

		// Only the new active implementation gets write permissions
		isCurrentPackageAddress := caller == packageAddress
		if isCurrentPackageAddress {
			updatedPermission = store.Write
		}

		err := vm.domainKVStore.UpdateAuthorizedCaller(caller, updatedPermission)
		if err != nil {
			return err
		}
	}

	return nil
}

func (vm *versionManager) GetDomainPath() string {
	return vm.domainPath
}

func (vm *versionManager) GetInitializers() *avl.Tree {
	return vm.initializers
}

func (vm *versionManager) GetCurrentPackagePath() string {
	return vm.currentPackagePath
}

func (vm *versionManager) GetCurrentImplementation() any {
	return vm.currentImplementation
}

// isContainDomainPath checks if the calling contract is within the domain path.
// This ensures that only contracts like protocol_fee/v1, protocol_fee/v2 can register initializers,
// preventing external contracts from registering unauthorized implementations.
func (vm *versionManager) isContainDomainPath() bool {
	previousRealm := runtime.PreviousRealm()
	if previousRealm.IsUser() {
		return false
	}

	prefix := ufmt.Sprintf("%s/", vm.domainPath)

	return strings.HasPrefix(runtime.PreviousRealm().PkgPath(), prefix)
}

func NewVersionManager(
	domainPath string,
	kvStore store.KVStore,
	initializeDomainStoreFn func(kvStore store.KVStore) any,
) VersionManager {
	return &versionManager{
		domainPath:              domainPath,
		domainKVStore:           kvStore,
		initializeDomainStoreFn: initializeDomainStoreFn,
		initializers:            avl.NewTree(),
		currentPackagePath:      "",
		currentImplementation:   nil,
	}
}
