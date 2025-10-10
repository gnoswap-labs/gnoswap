package dependency

import (
	"std"

	"gno.land/p/nt/ufmt"
)

// RegisterContractVersion registers a contract version with its realm information.
// This must be called when deploying a new contract version.
//
// Parameters:
//   - contract: name of the contract
//   - version: version of the contract
//   - realm: realm of the deployed contract
//   - deps: list of dependencies
//
// Only callable by admin or governance.
func RegisterContractVersion(contract RealmPath, version Version, realm std.Realm, deps []Dependency) {
	caller := std.GetCallerAt(1)
	assertIsAdmin(caller)

	// Validate inputs
	if !contract.IsValid() {
		panic(makeErrorWithDetails(
			errInvalidContractName,
			ufmt.Sprintf("contract: %s", contract.String()),
		))
	}

	if !version.IsValid() {
		panic(makeErrorWithDetails(
			errInvalidVersion,
			ufmt.Sprintf("version: %d", version),
		))
	}

	if !realm.Addr().IsValid() {
		panic(makeErrorWithDetails(
			errInvalidAddress,
			ufmt.Sprintf("realm address: %s", realm.Addr().String()),
		))
	}

	key := makeKey(contract, version)

	// Check if already registered
	if HasDependencies(contract, version) {
		panic(makeErrorWithDetails(
			errDependencyAlreadyExists,
			ufmt.Sprintf("contract version %s already registered", key),
		))
	}

	// Validate dependencies
	validateDependencyList(contract, deps)

	// Check for circular dependencies
	if hasCircularDependency(contract, version, deps) {
		panic(makeErrorWithDetails(
			errCircularDependency,
			ufmt.Sprintf("contract: %s:v%d", contract.String(), version),
		))
	}

	// Store contract version info
	versionInfo := ContractVersionInfo{
		RealmPath: contract,
		Version:   version,
		Realm:     realm,
	}
	storeVersionInfo(versionInfo)

	// Store dependency set
	depSet := DependencySet{
		RealmPath:    contract,
		Version:      version,
		Dependencies: deps,
	}
	storeDependencySet(depSet)
}

// UpdateContractVersion updates an existing contract version registration.
// This can be used to update realm or dependencies.
//
// Parameters:
//   - contract: name of the contract
//   - version: version of the contract
//   - realm: new realm address (can be same as before)
//   - deps: new list of dependencies
//
// Only callable by admin or governance.
func UpdateContractVersion(contract RealmPath, version Version, realm std.Realm, deps []Dependency) {
	caller := std.GetCallerAt(1)
	assertIsAdmin(caller)

	// Validate inputs
	if !contract.IsValid() {
		panic(makeErrorWithDetails(
			errInvalidContractName,
			ufmt.Sprintf("contract: %s", contract.String()),
		))
	}

	if !version.IsValid() {
		panic(makeErrorWithDetails(
			errInvalidVersion,
			ufmt.Sprintf("version: %d", version),
		))
	}

	key := makeKey(contract, version)

	// Check if exists
	if !HasDependencies(contract, version) {
		panic(makeErrorWithDetails(
			errVersionNotFound,
			ufmt.Sprintf("contract version %s not found", key),
		))
	}

	// Validate dependencies
	validateDependencyList(contract, deps)

	// Check for circular dependencies
	if hasCircularDependency(contract, version, deps) {
		panic(makeErrorWithDetails(
			errCircularDependency,
			ufmt.Sprintf("contract: %s:v%d", contract.String(), version),
		))
	}

	// Update contract version info
	versionInfo := ContractVersionInfo{
		RealmPath: contract,
		Version:   version,
		Realm:     realm,
	}
	storeVersionInfo(versionInfo)

	// Update dependency set
	depSet := DependencySet{
		RealmPath:    contract,
		Version:      version,
		Dependencies: deps,
	}
	storeDependencySet(depSet)
}

// RegisterFunction registers a function handler for a specific contract version.
// This should be called when deploying a contract to register its callable functions.
//
// Parameters:
//   - registration: function registration containing contract, version, function name, and handler
//
// Only callable by the contract itself during initialization.
func RegisterFunction(registration FunctionRegistration) {
	// Validate the registration
	if !registration.IsValid() {
		panic(makeErrorWithDetails(
			errInvalidDependency,
			ufmt.Sprintf("invalid function registration: %s", registration.String()),
		))
	}

	// Get caller to verify it's the contract itself
	caller := std.PrevRealm()

	// Verify this contract version is registered
	versionInfo, exists := GetContractVersionInfo(registration.RealmPath, registration.Version)
	if !exists {
		panic(makeErrorWithDetails(
			errVersionNotFound,
			ufmt.Sprintf("contract version %s:v%d not registered", registration.RealmPath.String(), registration.Version),
		))
	}

	// Verify caller is the contract itself
	if caller.Addr() != versionInfo.Realm.Addr() {
		panic(makeErrorWithDetails(
			errCallerIsNotAuthorized,
			ufmt.Sprintf("caller %s is not the registered contract %s", caller.Addr().String(), versionInfo.Realm.Addr().String()),
		))
	}

	// Check if already registered
	key := registration.MakeKey()
	handler, exists := GetFunctionHandler(registration.RealmPath, registration.Version, registration.Function)
	if exists && handler.Handler != nil {
		panic(makeErrorWithDetails(
			errDependencyAlreadyExists,
			ufmt.Sprintf("function %s already registered", key),
		))
	}

	// Store the function handler
	storeFunctionHandler(registration)
}

// validateDependencyList validates a list of dependencies.
func validateDependencyList(contract RealmPath, deps []Dependency) {
	for _, dep := range deps {
		if !dep.IsValid() {
			panic(makeErrorWithDetails(
				errInvalidDependency,
				ufmt.Sprintf("dependency: %s", dep.String()),
			))
		}

		// Check for self-dependency
		if dep.RealmPath == contract {
			panic(makeErrorWithDetails(
				errCannotRegisterSelfDep,
				ufmt.Sprintf("contract: %s cannot depend on itself", contract.String()),
			))
		}

		// Check if dependent contract and version are registered
		depInfo, exists := GetContractVersionInfo(dep.RealmPath, dep.Version)
		if !exists {
			// Allow if this is version 1 or if dependency is a core service
			if dep.Version != 1 {
				panic(makeErrorWithDetails(
					errDependencyNotFound,
					ufmt.Sprintf("dependency %s not registered", dep.String()),
				))
			}
		} else {
			// Verify the realm is valid
			if !depInfo.Realm.Addr().IsValid() {
				panic(makeErrorWithDetails(
					errInvalidAddress,
					ufmt.Sprintf("dependency %s has invalid realm", dep.String()),
				))
			}
		}
	}
}
