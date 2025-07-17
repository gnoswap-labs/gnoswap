package halt

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/access"
)

var govAddr, _ = access.GetAddress(access.ROLE_GOVERNANCE)
var adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)

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
	if err := access.AdminOnly(caller); err == nil {
		return true
	}
	if err := access.GovernanceOnly(caller); err == nil {
		return true
	}
	return false
}

func isGovernance(caller std.Address) bool {
	// Use only access module check like old module
	if err := access.GovernanceOnly(caller); err == nil {
		return true
	}
	return false
}

func isAdmin(caller std.Address) bool {
	// Use only access module check like old module
	if err := access.AdminOnly(caller); err == nil {
		return true
	}
	return false
}

func getPrevAddr() std.Address {
	return std.PreviousRealm().Address()
}

/** Core public API **/

// SetHaltLevel sets the global halt level
// Only admin or governance can call this function
func SetHaltLevel(cur realm, level HaltLevel) error {
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

/** Override system functions **/

// SetOperationStatus enables or disables a specific operation, overriding the level default
// Only governance can call this function
func SetOperationStatus(cur realm, op OpType, enabled bool) error {
	caller := getPrevAddr()
	if err := access.GovernanceOnly(caller); err != nil {
		return ufmt.Errorf("only governance(%s) can set operation status, called from %s", govAddr, caller)
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
func SetOperationStatusByAdmin(cur realm, op OpType, enabled bool) error {
	caller := getPrevAddr()
	if err := access.AdminOnly(caller); err != nil {
		return ufmt.Errorf("only admin(%s) can set operation status, called from %s", adminAddr, caller)
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
func ClearOperationOverride(cur realm, op OpType) error {
	caller := getPrevAddr()
	if err := access.GovernanceOnly(caller); err != nil {
		return ufmt.Errorf("only governance(%s) can clear operation override, called from %s", govAddr, caller)
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
func ClearAllOverrides(cur realm) error {
	caller := getPrevAddr()
	if err := access.GovernanceOnly(caller); err != nil {
		return ufmt.Errorf("only governance(%s) can clear all overrides, called from %s", govAddr, caller)
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

/** 
IMPORTANT: Backward compatibility functions will be deprecated.
**/

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

// Additional backward compatibility functions for old API

// SetHaltLevelByAdmin allows an admin to set the halt level using LevelID (backward compatibility)
func SetHaltLevelByAdmin(cur realm, haltLevel LevelID) error {
	caller := getPrevAddr()
	if !isAdmin(caller) {
		return ufmt.Errorf("only admin can set halt level, called from %s", caller)
	}
	return setHaltLevel(levelIDToHaltLevel(haltLevel))
}

// SetHaltByAdmin maintains backward compatibility with the old API
func SetHaltByAdmin(cur realm, halt bool) error {
	caller := getPrevAddr()
	if !isAdmin(caller) {
		return ufmt.Errorf("only admin can set halt, called from %s", caller)
	}

	if halt {
		return setHaltLevel(HaltLevelComplete)
	}
	return setHaltLevel(HaltLevelNone)
}

// SetHalt allows both admin and governance to set the halt status (backward compatibility)
func SetHalt(cur realm, halt bool, level ...LevelID) error {
	caller := getPrevAddr()
	if !isAdminOrGovernance(caller) {
		return ufmt.Errorf("only admin or governance can set halt, called from %s", caller)
	}

	// If no level specified, use defaults
	if len(level) == 0 {
		if !halt {
			return setHaltLevel(HaltLevelNone)
		}
		return setHaltLevel(HaltLevelComplete)
	}

	// Validate the specified level
	haltLevel := level[0]
	switch haltLevel {
	case LvNoHalt, LvEmergencyHalt, LvCompleteHalt:
		return setHaltLevel(levelIDToHaltLevel(haltLevel))
	default:
		return ufmt.Errorf("only NoHalt, EmergencyHalt and CompleteHalt levels are allowed")
	}
}

// SetHaltLevel with LevelID for backward compatibility
func SetHaltLevelWithID(cur realm, haltLevel LevelID) error {
	caller := getPrevAddr()
	if !isAdminOrGovernance(caller) {
		return ufmt.Errorf("only admin or governance can set halt level, called from %s", caller)
	}
	return setHaltLevel(levelIDToHaltLevel(haltLevel))
}

// EnableWithdrawalsForTestnet enables withdrawals in MainnetSafeMode (backward compatibility)
func EnableWithdrawalsForTestnet(cur realm) error {
	caller := getPrevAddr()
	if !isAdmin(caller) {
		return ufmt.Errorf("only admin can enable withdrawals, called from %s", caller)
	}

	// Only proceed if we're in SafeMode (equivalent to MainnetSafeMode)
	if currentLevel != HaltLevelSafeMode {
		return nil
	}

	customOverrides[OpTypeWithdraw] = true

	// Emit event
	std.Emit(
		"enableWithdrawals",
		"caller", caller.String(),
	)

	return nil
}

// EnableContractOperations allows enabling contract-specific operations (backward compatibility)
func EnableContractOperations(cur realm, contract OpType) error {
	caller := getPrevAddr()
	if !isAdmin(caller) {
		return ufmt.Errorf("only admin can enable contract operations, called from %s", caller)
	}

	if !contract.IsValid() {
		return ufmt.Errorf("invalid operation type: %s", contract)
	}

	customOverrides[contract] = true

	// Emit event
	std.Emit(
		"enableContract",
		"contract", string(contract),
		"caller", caller.String(),
	)

	return nil
}

// DisableContractOperations allows disabling contract-specific operations (backward compatibility)
func DisableContractOperations(cur realm, contract OpType) error {
	caller := getPrevAddr()
	if !isAdmin(caller) {
		return ufmt.Errorf("only admin can disable contract operations, called from %s", caller)
	}

	if !contract.IsValid() {
		return ufmt.Errorf("invalid operation type: %s", contract)
	}

	customOverrides[contract] = false

	// Emit event
	std.Emit(
		"disableContract",
		"contract", string(contract),
		"caller", caller.String(),
	)

	return nil
}

// GetHaltManager returns a minimal manager instance for backward compatibility
func GetHaltManager() *Manager {
	return &Manager{} // Empty manager struct for compatibility
}

// GetCurrentHaltLevelID returns LevelID for exact backward compatibility with old API
func GetCurrentHaltLevelID() LevelID {
	return haltLevelToLevelID(currentLevel)
}

// Helper function to get previous address and package path as strings (backward compatibility)
func getPrevAsString() (string, string) {
	prev := std.PreviousRealm()
	return prev.Address().String(), prev.PkgPath()
}
