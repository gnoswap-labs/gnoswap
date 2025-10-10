package dependency

import (
	"std"

	"gno.land/p/nt/ufmt"
)

// Call dispatches a function call to the appropriate contract version based on the caller's dependencies.
// This is the main entry point for cross-contract calls through the dependency system.
//
// How it works:
//  1. Gets the caller's realm from previousRealm
//  2. Identifies the caller's contract name and version
//  3. Looks up the caller's dependencies
//  4. Finds the required version of the target contract
//  5. Finds and executes the registered function handler
//  6. Returns the result
//
// Parameters:
//   - targetContract: the contract to call
//   - functionName: the function to call on the target contract
//   - args: arguments to pass to the function
//
// Returns:
//   - result from the function call (type depends on the function)
//
// Panics if:
//   - Caller is not registered
//   - Dependency not found
//   - Function not registered
//
// Example:
//
//	// In position contract, calling pool's Mint function
//	result := dependency.Call(
//	    dependency.ContractPool,
//	    "Mint",
//	    poolId,
//	    amount,
//	)
func Call(targetContract RealmPath, functionName FunctionName, args ...interface{}) interface{} {
	// Get the caller's realm (the contract calling this function)
	caller := std.PrevRealm()

	// Identify the caller's contract and version
	callerContract, callerVersion, found := GetContractByRealm(caller.Addr())
	if !found {
		panic(makeErrorWithDetails(
			errContractNotRegistered,
			ufmt.Sprintf("caller realm: %s not registered", caller.Addr().String()),
		))
	}

	// Get the caller's dependencies
	depSet, exists := GetDependencies(callerContract, callerVersion)
	if !exists {
		panic(makeErrorWithDetails(
			errVersionNotFound,
			ufmt.Sprintf("dependencies for %s:v%d not found", callerContract.String(), callerVersion),
		))
	}

	// Find the required version of the target contract
	targetVersion := depSet.GetDependencyVersion(targetContract)
	if targetVersion == 0 {
		panic(makeErrorWithDetails(
			errDependencyNotFound,
			ufmt.Sprintf("%s:v%d does not depend on %s", callerContract.String(), callerVersion, targetContract.String()),
		))
	}

	// Get the function handler
	handler, exists := GetFunctionHandler(targetContract, targetVersion, functionName)
	if !exists {
		panic(makeErrorWithDetails(
			errFunctionNotFound,
			ufmt.Sprintf("function %s not found for %s:v%d", functionName.String(), targetContract.String(), targetVersion),
		))
	}

	// Execute the function handler with the original caller realm
	return handler.Handler(caller, args...)
}
