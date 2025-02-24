package halt

import (
	"errors"
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"
	phalt "gno.land/p/gnoswap/halt"

	"gno.land/r/gnoswap/v1/access"
)

var errHalted = errors.New("halted")

var govAddr, _ = access.GetAddress(access.ROLE_GOVERNANCE)

// OperationType defines the structure for operation configuration
type OperationType struct {
	Type        phalt.OpType
	Name        string
	Description string
	IsContract  bool
}

// Operation types table
var operationTypes = []OperationType{
	// Contract operations
	{Type: "pool", Name: "Pool", Description: "Pool contract operations", IsContract: true},
	{Type: "position", Name: "Position", Description: "Position contract operations", IsContract: true},
	{Type: "protocol_fee", Name: "ProtocolFee", Description: "Protocol fee contract operations", IsContract: true},
	{Type: "router", Name: "Router", Description: "Router contract operations", IsContract: true},
	{Type: "staker", Name: "Staker", Description: "Staker contract operations", IsContract: true},
	{Type: "launchpad", Name: "Launchpad", Description: "Launchpad contract operations", IsContract: true},
	{Type: "governance", Name: "Governance", Description: "Governance contract operations", IsContract: true},

	// Global actions
	{Type: "withdraw", Name: "Withdraw", Description: "Withdrawal operations", IsContract: false},
	{Type: "deposit", Name: "Deposit", Description: "Deposit operations", IsContract: false},
	{Type: "swap", Name: "Swap", Description: "Swap operations", IsContract: false},
	{Type: "liquidity", Name: "Liquidity", Description: "Liquidity operations", IsContract: false},
}

// Contract-specific operation types
const (
	OpTypePool       phalt.OpType = "pool"
	OpTypePosition   phalt.OpType = "position" 
	OpTypeProtocolFee phalt.OpType = "protocol_fee"
	OpTypeRouter     phalt.OpType = "router"
	OpTypeStaker     phalt.OpType = "staker"
	OpTypeLaunchpad  phalt.OpType = "launchpad"
	OpTypeGovernance phalt.OpType = "governance"

	// Contract actions
	OpTypeWithdraw   phalt.OpType = "withdraw"   // Global withdraw operation
	OpTypeDeposit    phalt.OpType = "deposit"    // Global deposit operation
	OpTypeSwap       phalt.OpType = "swap"       // Global swap operation
	OpTypeLiquidity  phalt.OpType = "liquidity"  // Global liquidity operation
)

const (
	// Special mode for beta mainnet (no withdrawals)
	// Issue: https://github.com/gnoswap-labs/gnoswap/issues/517
	LvMainnetSafeMode phalt.LevelID = 10

	// Halt handler for contract-specific operations
	LvContractSafeMode phalt.LevelID = 20
)

var haltManager *phalt.Manager

const (
	enabled  = true
	disabled = false
)

func init() {
	// Create a default manager first
	haltManager = phalt.DefaultManager()

	// Register GnoSwap-specific operations
	haltManager.RegisterOperation(phalt.NewOperation(OpTypePool, "Pool", "Pool management operations"))
	haltManager.RegisterOperation(phalt.NewOperation(OpTypeGovernance, "Governance", "Governance operations"))

	// Create custom MainnetSafeMode level that disables withdrawals for beta mainnet
	mainnetSafeMode := phalt.NewHaltLevel(
		LvMainnetSafeMode,
		"MainnetSafeMode",
		"Safe mode for post-mainnet (no withdrawals)",
		map[phalt.OpType]bool{
			phalt.OpTypeSwap:      enabled,
			phalt.OpTypeLiquidity: enabled,
			phalt.OpTypeWithdraw:  disabled,
			phalt.OpTypePool:      enabled,
		},
	)

	haltManager.RegisterHaltLevel(mainnetSafeMode)

	// Set initial level to MainnetSafeMode for right after mainnet
	if err := haltManager.SetCurrentLevel(LvMainnetSafeMode); err != nil {
		panic(ufmt.Sprintf("Failed to set initial halt level: %v", err))
	}

	for _, op := range operationTypes {
		haltManager.RegisterOperation(phalt.NewOperation(op.Type, op.Name, op.Description))

		// Create ContractSafeMode level with all contracts enabled by default
		contractSafeMode := phalt.NewHaltLevel(
			LvContractSafeMode,
			"ContractSafeMode",
			"Safe mode with contract-specific controls, all enabled by default",
			map[phalt.OpType]bool{
				// Contract states - all enabled by default
				phalt.OpTypePool:        true,
				phalt.OpTypePosition:    true,
				phalt.OpTypeProtocolFee: true,
				phalt.OpTypeRouter:      true,
				phalt.OpTypeStaker:      true,
				phalt.OpTypeLaunchpad:   true,
				phalt.OpTypeGovernance:  true,

				// Global actions - also enabled by default
				phalt.OpTypeWithdraw:   true, // Must be enabled
				phalt.OpTypeDeposit:    true,
				phalt.OpTypeSwap:       true,
				phalt.OpTypeLiquidity:  true,
			},
		)

		haltManager.RegisterHaltLevel(contractSafeMode)
	}
}

// GetHalt returns the current halt status.
func GetHalt() bool {
	currentLevel := haltManager.Level().Level()
	return currentLevel == phalt.LvCompleteHalt || currentLevel == LvMainnetSafeMode
}

// IsHalted checks if the requested operations are allowed in the current halt level.
// If not allowed, it returns an error.
//
// Example Usage:
//
// For checking if only one operation is halted:
//
//	err := halt.IsHalted(halt.OpTypeSwap)
//
// For checking if multiple operations are halted:
//
//	err := halt.IsHalted(halt.OpTypeSwap, halt.OpTypeLiquidity /* and more */)
//
// Parameters:
// - opType (halt.OpType): Optional operation type to check. If not provided, checks if system is completely halted.
func IsHalted(opType ...phalt.OpType) error {
	// if no operation specified, check if system is completely halted
	if len(opType) == 0 {
		if GetHalt() {
			return errHalted
		}
		return nil
	}

	// check each operation(s)
	for _, oo := range opType {
		op := phalt.NewOperation(oo, string(oo), string(oo)+" operation")
		if !haltManager.Level().IsOperationAllowed(op) {
			return ufmt.Errorf("Operation '%s' is currently disabled in halt level: %s", oo, haltManager.Status(oo))
		}
	}

	return nil
}

// SetHaltByAdmin allows an admin to set the halt level of GnoSwap.
// Only an admin can execute this function.
//
// Parameters:
// - haltLevel (halt.LevelID): The new halt level to set.
//
// Returns:
// - error: nil if successful, otherwise an error.
func SetHaltLevelByAdmin(haltLevel phalt.LevelID) error {
	caller := std.PreviousRealm().Address()
	if err := access.AdminOnly(caller); err != nil {
		return ufmt.Errorf("only admin can set halt level, called from %s", caller)
	}
	return setHaltLevel(haltLevel)
}

// SetHaltByAdmin maintains backward compatibility with the old API.
// It maps true to CompleteHalt and false to NoHalt.
//
// While the halt mechanism should fundamentally be controlled by governance,
// there needs to be functionality that allows admin intervention
// in special cases such as emergencies.
//
// Parameters:
// - halt (bool): true to halt, false to unhalt.
//
// Returns:
// - error: nil if successful, otherwise an error.
//
// TODO: Should we only allow EmergencyHalt or CompleteHalt?
func SetHaltByAdmin(halt bool) error {
	caller := getPrevAddr()
	if err := access.AdminOnly(caller); err != nil {
		return ufmt.Errorf("only admin can set halt, called from %s", caller)
	}

	if halt {
		return setHaltLevel(phalt.LvCompleteHalt)
	}
	return setHaltLevel(phalt.LvNoHalt)
}

// SetHalt allows the governance contract to set the halt status of GnoSwap.
// Only the governance contract can execute this function.
//
// Parameters:
// - halt (bool): true to halt, false to unhalt.
//
// Returns:
// - error: nil if successful, otherwise an error.
func SetHalt(halt bool) error {
	caller := getPrevAddr()
	if err := access.GovernanceOnly(caller); err != nil {
		return ufmt.Errorf("only governance(%s) can set halt, called from %s", govAddr, caller)
	}

	if halt {
		return setHaltLevel(phalt.LvCompleteHalt)
	}
	return setHaltLevel(phalt.LvNoHalt)
}

// SetHaltLevel allows the governance contract to set the halt level of GnoSwap.
// Only the governance contract can execute this function.
//
// Parameters:
// - haltLevel (halt.LevelID): The new halt level to set.
//
// Returns:
// - error: nil if successful, otherwise an error.
func SetHaltLevel(haltLevel phalt.LevelID) error {
	caller := getPrevAddr()
	if err := access.GovernanceOnly(caller); err != nil {
		return ufmt.Errorf("only governance(%s) can set halt level, called from %s", govAddr, caller)
	}
	return setHaltLevel(haltLevel)
}

// setHaltLevel updates the halt level to the specified value.
// This is an internal function that should only be called by privileged functions.
//
// Parameters:
// - haltLevel (halt.LevelID): The new halt level to set.
//
// Returns:
// - error: nil if successful, otherwise an error.
func setHaltLevel(haltLevel phalt.LevelID) error {
	if err := haltManager.SetCurrentLevel(haltLevel); err != nil {
		return ufmt.Errorf("invalid halt level: %v", err)
	}

	prevAddr, prevPkgPath := getPrevAsString()
	std.Emit(
		"setHaltLevel",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"level", strconv.Itoa(int(haltLevel)),
		"levelName", haltManager.Level().Name(),
	)
	return nil
}

// SetOperationStatus allows governance to enable/disable specific operations.
// This provides granular control over protocol functions.
//
// Parameters:
// - opType (halt.OpType): The operation type to configure.
// - allowed (bool): Whether the operation should be allowed.
//
// Returns:
// - error: nil if successful, otherwise an error.
func SetOperationStatus(opType phalt.OpType, allowed bool) error {
	caller := getPrevAddr()
	if err := access.GovernanceOnly(caller); err != nil {
		return ufmt.Errorf("only governance(%s) can set operation status, called from %s", govAddr, caller)
	}
	return setOperationStatus(opType, allowed)
}

// SetOperationStatusByAdmin allows an admin to enable/disable specific operations.
//
// Parameters:
// - opType (halt.OpType): The operation type to configure.
// - allowed (bool): Whether the operation should be allowed.
//
// Returns:
// - error: nil if successful, otherwise an error.
func SetOperationStatusByAdmin(opType phalt.OpType, allowed bool) error {
	caller := getPrevAddr()
	if err := access.AdminOnly(caller); err != nil {
		return ufmt.Errorf("only admin can set operation status, called from %s", caller)
	}

	return setOperationStatus(opType, allowed)
}

// setOperationStatus updates whether a specific operation is allowed.
// This is an internal function that should only be called by privileged functions.
//
// Parameters:
// - opType (halt.OpType): The operation type to configure.
// - allowed (bool): Whether the operation should be allowed.
//
// Returns:
// - error: nil if successful, otherwise an error.
func setOperationStatus(opType phalt.OpType, allowed bool) error {
	if err := haltManager.SetOperationStatus(opType, allowed); err != nil {
		return ufmt.Errorf("failed to set operation status: %v", err)
	}

	prevAddr, prevPkgPath := getPrevAsString()
	std.Emit(
		"setOperationStatus",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"operation", string(opType),
		"allowed", strconv.FormatBool(allowed),
	)
	return nil
}

// EnableWithdrawalsForTestnet enables withdrawals in MainnetSafeMode.
// This should be called after ensuring stability on beta mainnet.
//
// Returns:
// - error: nil if successful, otherwise an error.
func EnableWithdrawalsForTestnet() error {
	caller := getPrevAddr()
	// TODO: no need to check governance?
	if err := access.AdminOnly(caller); err != nil {
		return ufmt.Errorf("only admin can enable withdrawals, called from %s", caller)
	}

	// Only proceed if we're in MainnetSafeMode
	if haltManager.Level().Level() != LvMainnetSafeMode {
		return nil
	}

	err := setOperationStatus(OpTypeWithdraw, true)
	if err != nil {
		return err
	}

	prevAddr, prevPkgPath := getPrevAsString()
	std.Emit(
		"enableWithdrawals",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
	)

	return nil
}

// EnableSwapsForTestnet enables swaps in MainnetSafeMode.
// This should be called after ensuring stability on beta mainnet.
//
// Returns:
// - error: nil if successful, otherwise an error.
func EnableSwapsForTestnet() error {
	caller := getPrevAddr()
	// TODO: no need to check governance?
	if err := access.AdminOnly(caller); err != nil {
		return ufmt.Errorf("only admin can enable swaps, called from %s", caller)
	}

	// Only proceed if we're in MainnetSafeMode
	if haltManager.Level().Level() != LvMainnetSafeMode {
		return nil
	}

	err := setOperationStatus(OpTypeSwap, true)
	if err != nil {
		return err
	}

	prevAddr, prevPkgPath := getPrevAsString()
	std.Emit(
		"enableSwaps",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
	)

	return nil
}

// EnableLiquidityForTestnet enables liquidity operations in MainnetSafeMode.
// This should be called after ensuring stability on beta mainnet.
//
// Returns:
// - error: nil if successful, otherwise an error.
func EnableLiquidityForTestnet() error {
	caller := getPrevAddr()
	if err := access.AdminOnly(caller); err != nil {
		return ufmt.Errorf("only admin can enable liquidity, called from %s", caller)
	}

	// Only proceed if we're in MainnetSafeMode
	if haltManager.Level().Level() != LvMainnetSafeMode {
		return nil
	}

	err := setOperationStatus(OpTypeLiquidity, true)
	if err != nil {
		return err
	}

	prevAddr, prevPkgPath := getPrevAsString()
	std.Emit(
		"enableLiquidity",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
	)

	return nil
}

// GetHaltManager returns the halt manager instance.
// This is useful for external packages that need to interact directly with the manager.
//
// Returns:
// - *halt.Manager: The halt manager instance.
func GetHaltManager() *phalt.Manager {
	return haltManager
}

// GetCurrentHaltLevel returns the current halt level.
//
// Returns:
// - halt.LevelID: The current halt level ID.
func GetCurrentHaltLevel() phalt.LevelID {
	return haltManager.Level().Level()
}

// EnableContractOperations allows enabling contract-specific operations.
// Only an admin can execute this function.
//
// Parameters:
// - contract (halt.OpType): The contract operation type to enable.
//
// Returns:
// - error: nil if successful, otherwise an error.
func EnableContractOperations(contract phalt.OpType) error {
	caller := getPrevAddr()
	if err := access.AdminOnly(caller); err != nil {
		return ufmt.Errorf("only admin can enable contract operations, called from %s", caller)
	}

	// Only proceed if we're in ContractSafeMode
	if haltManager.Level().Level() != LvContractSafeMode {
		return nil
	}

	err := setOperationStatus(contract, true)
	if err != nil {
		return err
	}

	prevAddr, prevPkgPath := getPrevAsString()
	std.Emit(
		"enableContract",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"contract", string(contract),
	)

	return nil
}

// DisableContractOperations allows disabling contract-specific operations.
// Only an admin can execute this function.
//
// Parameters:
// - contract (halt.OpType): The contract operation type to disable.
//
// Returns:
func DisableContractOperations(contract phalt.OpType) error {
	caller := getPrevAddr()
	if err := access.AdminOnly(caller); err != nil {
		return ufmt.Errorf("only admin can disable contract operations, called from %s", caller)
	}

	err := setOperationStatus(contract, false)
	if err != nil {
		return err
	}

	prevAddr, prevPkgPath := getPrevAsString()
	std.Emit(
		"disableContract",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"contract", string(contract),
	)

	return nil
}

// IsContractHalted checks if specific contract operations are halted
func IsContractHalted(contract phalt.OpType) error {
	return IsHalted(contract)
}

// GetContractStatus returns the current status for a specific contract
func GetContractStatus(contract phalt.OpType) bool {
	return haltManager.Level().IsOperationAllowed(phalt.NewOperation(contract, string(contract), ""))
}
