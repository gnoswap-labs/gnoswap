package dependency

import (
	"std"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

var (
	// dependencies stores all registered dependencies
	// Key: "contract:version" (e.g., "pool:1")
	// Value: DependencySet
	dependencies *avl.Tree

	// contractVersions tracks realm information for each contract version
	// Key: "contract:version" (e.g., "pool:1")
	// Value: ContractVersionInfo
	contractVersions *avl.Tree

	// realmToContract reverse mapping for fast lookup
	// Key: realm address (e.g., "g1...")
	// Value: ContractVersionInfo
	realmToContract *avl.Tree

	// versionsByContract tracks all registered versions per contract
	// Key: "contract" (e.g., "pool")
	// Value: comma-separated version list (e.g., "1,2,3")
	versionsByContract *avl.Tree

	// functionHandlers stores registered function handlers
	// Key: "contract:version:function" (e.g., "pool:1:Mint")
	// Value: FunctionRegistration
	functionHandlers *avl.Tree

	// ADMIN is the admin address
	ADMIN std.Address = "g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c"
)

func init() {
	dependencies = avl.NewTree()
	contractVersions = avl.NewTree()
	realmToContract = avl.NewTree()
	versionsByContract = avl.NewTree()
	functionHandlers = avl.NewTree()
}

// makeKey creates a unique key for storing dependencies.
func makeKey(contract RealmPath, version Version) string {
	return ufmt.Sprintf("%s:%d", contract.String(), version)
}

// storeDependencySet stores a dependency set.
func storeDependencySet(depSet DependencySet) {
	key := makeKey(depSet.RealmPath, depSet.Version)
	dependencies.Set(key, depSet)
}

// storeVersionInfo stores contract version information.
func storeVersionInfo(info ContractVersionInfo) {
	key := makeKey(info.RealmPath, info.Version)
	contractVersions.Set(key, info)

	// Store reverse mapping
	realmToContract.Set(info.Realm.Addr().String(), info)

	// Update versions list
	updateVersionsList(info.RealmPath, info.Version)
}

// storeFunctionHandler stores a function handler.
func storeFunctionHandler(registration FunctionRegistration) {
	key := registration.MakeKey()
	functionHandlers.Set(key, registration)
}

// GetDependencies returns the dependencies for a specific contract version.
func GetDependencies(contract RealmPath, version Version) (DependencySet, bool) {
	key := makeKey(contract, version)
	value, exists := dependencies.Get(key)
	if !exists {
		return DependencySet{}, false
	}

	depSet, ok := value.(DependencySet)
	return depSet, ok
}

// HasDependencies returns true if dependencies are registered for the given contract version.
func HasDependencies(contract RealmPath, version Version) bool {
	key := makeKey(contract, version)
	return dependencies.Has(key)
}

// GetContractVersionInfo returns the version info for a specific contract version.
func GetContractVersionInfo(contract RealmPath, version Version) (ContractVersionInfo, bool) {
	key := makeKey(contract, version)
	value, exists := contractVersions.Get(key)
	if !exists {
		return ContractVersionInfo{}, false
	}

	versionInfo, ok := value.(ContractVersionInfo)
	return versionInfo, ok
}

// GetContractByRealm returns the contract name and version for a given realm address.
// This is used to identify the caller's contract version from previousRealm.
func GetContractByRealm(realmAddr std.Address) (RealmPath, Version, bool) {
	value, exists := realmToContract.Get(realmAddr.String())
	if !exists {
		return "", 0, false
	}

	info, ok := value.(ContractVersionInfo)
	if !ok {
		return "", 0, false
	}

	return info.RealmPath, info.Version, true
}

// GetFunctionHandler returns the function handler for a specific contract version and function.
func GetFunctionHandler(contract RealmPath, version Version, function FunctionName) (FunctionRegistration, bool) {
	key := ufmt.Sprintf("%s:%d:%s", contract.String(), version, function.String())
	value, exists := functionHandlers.Get(key)
	if !exists {
		return FunctionRegistration{}, false
	}

	handler, ok := value.(FunctionRegistration)
	return handler, ok
}

// GetContractVersions returns all registered versions for a contract.
func GetContractVersions(contract RealmPath) []Version {
	value, exists := versionsByContract.Get(contract.String())
	if !exists {
		return []Version{}
	}

	versionsStr, ok := value.(string)
	if !ok {
		return []Version{}
	}

	return parseVersions(versionsStr)
}

// GetLatestVersion returns the latest version of a contract.
func GetLatestVersion(contract RealmPath) (Version, bool) {
	versions := GetContractVersions(contract)
	if len(versions) == 0 {
		return 0, false
	}

	maxVersion := versions[0]
	for _, v := range versions {
		if v > maxVersion {
			maxVersion = v
		}
	}

	return maxVersion, true
}

// updateVersionsList adds a version to the contract's version list.
func updateVersionsList(contract RealmPath, version Version) {
	versions := GetContractVersions(contract)

	// Check if version already exists
	for _, v := range versions {
		if v == version {
			return
		}
	}

	versions = append(versions, version)
	versionsByContract.Set(contract.String(), formatVersions(versions))
}
