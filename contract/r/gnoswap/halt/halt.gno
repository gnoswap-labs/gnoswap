package halt

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/access"
)

func init() {
	// Simple initialization - start in safe mode for beta mainnet
	currentLevel = HaltLevelSafeMode
}

// Global state (previously in Manager)
var (
	currentLevel    HaltLevel       = HaltLevelSafeMode
	customOverrides map[OpType]bool = make(map[OpType]bool)
)

// Helper functions for authorization
func isAdminOrGovernance(caller std.Address) bool {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
	return caller == adminAddr || caller == govAddr
}

func isGovernance(caller std.Address) bool {
	govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
	return caller == govAddr
}

func isAdmin(caller std.Address) bool {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	return caller == adminAddr
}

func getPrevAddr() std.Address {
	return std.PreviousRealm().Address()
}

// Core public API (consolidated from 8+ functions to 2)

// SetHaltLevel sets the global halt level
// Only admin or governance can call this function
func SetHaltLevel(level HaltLevel) error {
	caller := getPrevAddr()
	if !isAdminOrGovernance(caller) {
		return errUnauthorized
	}
	return setHaltLevel(level)
}

// IsHalted checks if the specified operations are halted
// Returns error with specific operation info if any operation is halted
func IsHalted(operations ...OpType) error {
	if len(operations) == 0 {
		// If no operations specified, check if system is completely halted
		if currentLevel == HaltLevelComplete {
			return ufmt.Errorf("system is completely halted")
		}
		return nil
	}

	// Check each operation
	for _, op := range operations {
		if !op.IsValid() {
			return ufmt.Errorf("invalid operation type: %s", op)
		}

		enabled, isOverride := GetOperationStatus(op)
		if !enabled {
			if isOverride {
				return ufmt.Errorf("operation '%s' is disabled by override", op)
			}
			return ufmt.Errorf("operation '%s' is disabled by halt level '%s'", op, currentLevel)
		}
	}

	return nil
}

// Override system functions

// SetOperationStatus enables or disables a specific operation, overriding the level default
// Only governance can call this function
func SetOperationStatus(cur realm, op OpType, enabled bool) error {
	caller := getPrevAddr()
	if !isGovernance(caller) {
		return errUnauthorized
	}

	if !op.IsValid() {
		return ufmt.Errorf("invalid operation type: %s", op)
	}

	customOverrides[op] = enabled

	// Emit event
	std.Emit(
		"SetOperationStatus",
		"operation", string(op),
		"enabled", strconv.FormatBool(enabled),
		"caller", caller.String(),
	)

	return nil
}

// SetOperationStatusByAdmin allows admin to override operation status (for emergency use)
func SetOperationStatusByAdmin(op OpType, enabled bool) error {
	caller := getPrevAddr()
	if !isAdmin(caller) {
		return errUnauthorized
	}

	if !op.IsValid() {
		return ufmt.Errorf("invalid operation type: %s", op)
	}

	customOverrides[op] = enabled

	// Emit event
	std.Emit(
		"SetOperationStatusByAdmin",
		"operation", string(op),
		"enabled", strconv.FormatBool(enabled),
		"caller", caller.String(),
	)

	return nil
}

// ClearOperationOverride removes the override for a specific operation
// Only governance can call this function
func ClearOperationOverride(op OpType) error {
	caller := getPrevAddr()
	if !isGovernance(caller) {
		return errUnauthorized
	}

	if !op.IsValid() {
		return ufmt.Errorf("invalid operation type: %s", op)
	}

	delete(customOverrides, op)

	// Emit event
	std.Emit(
		"ClearOperationOverride",
		"operation", string(op),
		"caller", caller.String(),
	)

	return nil
}

// GetOperationStatus returns the current status of an operation and whether it's overridden
// Returns (enabled, isOverride)
func GetOperationStatus(op OpType) (bool, bool) {
	if !op.IsValid() {
		return false, false
	}

	// Check for override first
	if override, exists := customOverrides[op]; exists {
		return override, true
	}

	// Fall back to level default
	return getOperationDefaultStatus(currentLevel, op), false
}

// ClearAllOverrides removes all operation overrides
// Only governance can call this function
func ClearAllOverrides() error {
	caller := getPrevAddr()
	if !isGovernance(caller) {
		return errUnauthorized
	}

	customOverrides = make(map[OpType]bool)

	// Emit event
	std.Emit(
		"ClearAllOverrides",
		"caller", caller.String(),
	)

	return nil
}

// Internal helper functions

func setHaltLevel(level HaltLevel) error {
	if !level.IsValid() {
		return errInvalidLevel
	}

	currentLevel = level

	// Emit event
	std.Emit(
		"SetHaltLevel",
		"level", string(level),
		"description", getLevelDescription(level),
		"caller", getPrevAddr().String(),
	)

	return nil
}

// Getter functions for external use

// GetCurrentHaltLevel returns the current halt level
func GetCurrentHaltLevel() HaltLevel {
	return currentLevel
}

// GetAllOverrides returns a copy of all current overrides
func GetAllOverrides() map[OpType]bool {
	result := make(map[OpType]bool)
	for op, status := range customOverrides {
		result[op] = status
	}
	return result
}

// GetHaltLevelDescription returns a description of the current halt level
func GetHaltLevelDescription() string {
	return getLevelDescription(currentLevel)
}

// Backward compatibility functions (will be deprecated)

// SetHalt maintains backward compatibility with the old API
// Maps true to CompleteHalt and false to NoHalt
func SetHalt(halt bool) error {
	caller := getPrevAddr()
	if !isAdminOrGovernance(caller) {
		return errUnauthorized
	}

	if halt {
		return setHaltLevel(HaltLevelComplete)
	}
	return setHaltLevel(HaltLevelNone)
}

// GetHalt returns true if system is completely halted (backward compatibility)
func GetHalt() bool {
	return currentLevel == HaltLevelComplete
}

// IsContractHalted checks if a specific contract operation is halted (backward compatibility)
func IsContractHalted(contract OpType) bool {
	err := IsHalted(contract)
	return err != nil
}

// GetContractStatus returns the current status for a specific contract (backward compatibility)
func GetContractStatus(contract OpType) bool {
	enabled, _ := GetOperationStatus(contract)
	return enabled
}
