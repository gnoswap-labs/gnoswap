package staker

import (
	"errors"
	"std"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gns"
)

// RegisterInitializer registers an implementation
// This function is called by each implementation version during init
func RegisterInitializer(packagePath string, initializer func() IGovStaker) {
	// Register with version manager
	registered := vm.RegisterInitializer(packagePath, func() interface{} {
		return initializer()
	})

	// If this is the first registration, set it as active implementation
	if registered && instance == nil {
		impl, ok := vm.GetCurrentImplementation().(IGovStaker)
		if ok {
			setImplementation(impl)
		}
	}
}

// UpgradeImpl upgrades the implementation to a new version
// Only admin can call this function
func UpgradeImpl(packagePath string) error {
	// Check admin permission
	caller := std.PrevRealm().Addr()
	if err := common.AddrAssertForAdmin(caller); err != nil {
		return err
	}

	// Validate package path
	if packagePath == "" {
		return errors.New("package path cannot be empty")
	}

	// Upgrade through version manager
	err := vm.Upgrade(packagePath)
	if err != nil {
		return err
	}

	// Update active implementation
	impl, ok := vm.GetCurrentImplementation().(IGovStaker)
	if !ok {
		return errors.New("failed to cast implementation to IGovStaker")
	}

	setImplementation(impl)
	return nil
}

// GetImplementationPath returns the current implementation package path
func GetImplementationPath() string {
	return vm.GetCurrentPackagePath()
}

// GetRegisteredImplementations returns all registered implementation paths
func GetRegisteredImplementations() []string {
	return vm.GetRegisteredPackages()
}
