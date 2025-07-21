package halt

// GetHaltConfig returns a deep copy of the current halt configuration
// This ensures that external modifications cannot affect the internal state
func GetHaltConfig() HaltConfig {
	return haltConfig.Clone()
}

// IsHalted checks if any of the specified operation types are halted (access denied)
// Returns errHalted if any operation is not allowed access, nil otherwise
// XXX: Handle backward compatibility to cause error. This function should be changed to return a bool.
func IsHalted(opTypes ...OpType) error {
	if isHalted(opTypes...) {
		return errHalted
	}

	return nil
}

// IsAllowedAccess checks if access operations are allowed for the specified operation type
// Returns true if the operation type is allowed to perform access operations
func IsAllowedAccess(op OpType) bool {
	return haltConfig.IsEnabledAccess(op)
}

// IsAllowedWithdraw checks if withdrawal operations are allowed for the specified operation type
// Returns true if the operation type is allowed to perform withdrawal operations
func IsAllowedWithdraw(op OpType) bool {
	return haltConfig.IsEnabledWithdraw(op)
}

// isHalted is an internal helper function that checks if any operation types are halted
// Returns true if any of the specified operation types has access denied
// Used internally to support the public IsHalted function
func isHalted(opTypes ...OpType) bool {
	// Check each operation type for access permission
	for _, op := range opTypes {
		if !haltConfig.IsEnabledAccess(op) {
			return true // Return true immediately if any operation is halted
		}
	}

	// All operations are allowed if we reach here
	return false
}