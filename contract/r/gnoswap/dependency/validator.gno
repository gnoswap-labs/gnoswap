package dependency

import (
	"gno.land/p/nt/ufmt"
)

// ValidateDependencies validates that all dependencies of a contract version are satisfied.
// Returns an error if any dependency is missing or incompatible.
//
// Parameters:
//   - contract: name of the contract to validate
//   - version: version of the contract to validate
func ValidateDependencies(contract RealmPath, version Version) error {
	depSet, exists := GetDependencies(contract, version)
	if !exists {
		return makeErrorWithDetails(
			errVersionNotFound,
			ufmt.Sprintf("contract: %s:v%d", contract.String(), version),
		)
	}

	// Validate each dependency
	for _, dep := range depSet.Dependencies {
		// Check if dependency version is registered
		_, exists := GetContractVersionInfo(dep.RealmPath, dep.Version)
		if !exists {
			return makeErrorWithDetails(
				errMissingDependency,
				ufmt.Sprintf("missing dependency: %s", dep.String()),
			)
		}

		// Recursively validate the dependency
		if err := ValidateDependencies(dep.RealmPath, dep.Version); err != nil {
			return makeErrorWithDetails(
				err,
				ufmt.Sprintf("from %s:v%d", contract.String(), version),
			)
		}
	}

	return nil
}

// ValidateContractUpgrade validates that a contract upgrade is safe.
// Checks that the new version's dependencies are compatible with existing contracts.
//
// Parameters:
//   - contract: name of the contract being upgraded
//   - fromVersion: current version
//   - toVersion: target version
func ValidateContractUpgrade(contract RealmPath, fromVersion Version, toVersion Version) error {
	// Check if target version exists
	_, exists := GetContractVersionInfo(contract, toVersion)
	if !exists {
		return makeErrorWithDetails(
			errVersionNotFound,
			ufmt.Sprintf("target version %s:v%d not found", contract.String(), toVersion),
		)
	}

	// Validate target version dependencies
	if err := ValidateDependencies(contract, toVersion); err != nil {
		return makeErrorWithDetails(
			err,
			ufmt.Sprintf("invalid dependencies for %s:v%d", contract.String(), toVersion),
		)
	}

	return nil
}

// hasCircularDependency checks if adding these dependencies would create a circular dependency.
func hasCircularDependency(contract RealmPath, version Version, deps []Dependency) bool {
	visited := make(map[string]bool)
	return checkCircular(contract, version, deps, visited)
}

// checkCircular recursively checks for circular dependencies.
func checkCircular(contract RealmPath, version Version, deps []Dependency, visited map[string]bool) bool {
	key := makeKey(contract, version)

	// If we've visited this node, we have a cycle
	if visited[key] {
		return true
	}

	visited[key] = true

	// Check each dependency
	for _, dep := range deps {
		depSet, exists := GetDependencies(dep.RealmPath, dep.Version)

		if exists {
			if checkCircular(dep.RealmPath, dep.Version, depSet.Dependencies, visited) {
				return true
			}
		}
	}

	// Remove from visited when backtracking
	delete(visited, key)
	return false
}
