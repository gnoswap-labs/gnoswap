package governance

import (
	"std"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"
	cp "gno.land/r/gnoswap/v1/community_pool"

	pl "gno.land/r/gnoswap/v1/pool"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	rr "gno.land/r/gnoswap/v1/router"
	sr "gno.land/r/gnoswap/v1/staker"

	"gno.land/r/gnoswap/halt"
)

// Package paths
const (
	GNS_PATH            = "gno.land/r/gnoswap/gns"
	HALT_PATH           = "gno.land/r/gnoswap/halt"
	ACCESS_PATH         = "gno.land/r/gnoswap/access"
	EMISSION_PATH       = "gno.land/r/gnoswap/emission"
	COMMON_PATH         = "gno.land/r/gnoswap/v1/common"
	POOL_PATH           = "gno.land/r/gnoswap/v1/pool"
	ROUTER_PATH         = "gno.land/r/gnoswap/v1/router"
	STAKER_PATH         = "gno.land/r/gnoswap/v1/staker"
	PROTOCOL_FEE_PATH   = "gno.land/r/gnoswap/v1/protocol_fee"
	COMMUNITY_POOL_PATH = "gno.land/r/gnoswap/v1/community_pool"
	GOV_GOVERNANCE_PATH = "gno.land/r/gnoswap/v1/gov/governance"
)

// ParameterHandler interface defines the contract for parameter execution handlers.
// Each handler is responsible for executing specific parameter changes in the system.
type ParameterHandler interface {
	// Execute processes the parameters and applies the changes to the system
	Execute(params []string) error
}

// ParameterHandlerOptions contains the configuration and execution logic for a parameter handler.
// This struct encapsulates all information needed to identify and execute a parameter change.
type ParameterHandlerOptions struct {
	pkgPath     string               // Package path of the target contract
	function    string               // Function name to be called
	paramCount  int                  // Expected number of parameters
	handlerFunc func([]string) error // Function that executes the parameter change
}

// HandlerKey generates a unique key for this handler based on package path and function name.
//
// Returns:
//   - string: unique identifier for the handler
func (h *ParameterHandlerOptions) HandlerKey() string {
	return makeHandlerKey(h.pkgPath, h.function)
}

// Execute validates parameter count and executes the handler function.
// This method ensures the correct number of parameters are provided before execution.
//
// Parameters:
//   - params: slice of string parameters to pass to the handler
//
// Returns:
//   - error: execution error if parameter count mismatch or handler execution fails
func (h *ParameterHandlerOptions) Execute(params []string) error {
	// Validate parameter count matches expected count
	if len(params) != h.paramCount {
		return ufmt.Errorf("expected %d parameters, got %d", h.paramCount, len(params))
	}

	// Create realm context function and execute handler
	fn := func(cur realm) error {
		return h.handlerFunc(params)
	}

	return fn(cross)
}

// NewParameterHandlerOptions creates a new parameter handler with the specified configuration.
//
// Parameters:
//   - pkgPath: package path of the target contract
//   - function: function name to be called
//   - paramCount: expected number of parameters
//   - handlerFunc: function that executes the parameter change
//
// Returns:
//   - ParameterHandler: configured parameter handler interface
func NewParameterHandlerOptions(
	pkgPath,
	function string,
	paramCount int,
	handlerFunc func([]string) error,
) ParameterHandler {
	return &ParameterHandlerOptions{
		pkgPath:     pkgPath,
		function:    function,
		paramCount:  paramCount,
		handlerFunc: handlerFunc,
	}
}

// ParameterRegistry manages the collection of parameter handlers for governance execution.
// This registry allows proposals to execute parameter changes across different system contracts.
type ParameterRegistry struct {
	handlers *avl.Tree // Tree storing handler configurations keyed by package:function
}

// register adds a new parameter handler to the registry.
// Each handler is identified by a unique combination of package path and function name.
//
// Parameters:
//   - handler: parameter handler configuration to register
func (r *ParameterRegistry) register(handler ParameterHandlerOptions) {
	r.handlers.Set(handler.HandlerKey(), handler)
}

// handler retrieves a parameter handler by package path and function name.
// This method is used during proposal execution to find the appropriate handler.
//
// Parameters:
//   - pkgPath: package path of the target contract
//   - function: function name to be called
//
// Returns:
//   - ParameterHandler: the matching parameter handler
//   - error: error if handler not found or casting fails
func (r *ParameterRegistry) handler(pkgPath, function string) (ParameterHandler, error) {
	// Generate lookup key
	key := makeHandlerKey(pkgPath, function)

	// Retrieve handler from registry
	h, exists := r.handlers.Get(key)
	if !exists {
		return nil, ufmt.Errorf("handler not found for %s", key)
	}

	// Cast to correct type
	handler, ok := h.(ParameterHandlerOptions)
	if !ok {
		return nil, ufmt.Errorf("failed to cast handler %s to ParameterHandler", key)
	}

	return &handler, nil
}

// NewParameterRegistry creates a new empty parameter registry.
//
// Returns:
//   - *ParameterRegistry: new registry instance
func NewParameterRegistry() *ParameterRegistry {
	return &ParameterRegistry{handlers: avl.NewTree()}
}

// makeHandlerKey creates a unique identifier for a handler based on package path and function.
//
// Parameters:
//   - pkgPath: package path of the target contract
//   - function: function name to be called
//
// Returns:
//   - string: unique key in format "pkgPath:function"
func makeHandlerKey(pkgPath, function string) string {
	return ufmt.Sprintf("%s:%s", pkgPath, function)
}

// createParameterHandlers initializes and configures all supported parameter handlers.
// This function defines all the parameter changes that can be executed through governance proposals.
// It covers configuration changes for various system components including pools, staking, fees, etc.
//
// Returns:
//   - *ParameterRegistry: fully configured registry with all supported handlers
func createParameterHandlers() *ParameterRegistry {
	registry := NewParameterRegistry()

	// Define all handler configurations for different system components
	handlers := []*ParameterHandlerOptions{
		// Access control
		{
			pkgPath:    ACCESS_PATH,
			function:   "UpdateSwapWhiteList",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Update swap whitelist
				access.UpdateSwapWhiteList(cross, std.Address(params[0]))

				return nil
			},
		},
		{
			pkgPath:    ACCESS_PATH,
			function:   "RemoveFromSwapWhiteList",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Remove from swap whitelist
				access.RemoveFromSwapWhiteList(cross, std.Address(params[0]))

				return nil
			},
		},
		// Community pool token transfers
		{
			pkgPath:    COMMUNITY_POOL_PATH,
			function:   "TransferToken",
			paramCount: 3,
			handlerFunc: func(params []string) error {
				// Transfer tokens from community pool to specified address
				cp.TransferToken(
					cross,
					params[0],              // pkgPath
					std.Address(params[1]), // to
					parseNumber(params[2], kindInt64).(int64), // amount
				)

				return nil
			},
		},
		// Emission distribution configuration
		{
			pkgPath:    EMISSION_PATH,
			function:   "SetDistributionStartTime",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Set distribution start time
				en.SetDistributionStartTime(cross, parseInt64(params[0]))

				return nil
			},
		},
		{
			pkgPath:    EMISSION_PATH,
			function:   "ChangeDistributionPct",
			paramCount: 8,
			handlerFunc: func(params []string) error {
				// Parse distribution targets and percentages
				target01 := parseNumber(params[0], kindInt).(int)  // target01
				pct01 := parseNumber(params[1], kindInt64).(int64) // pct01
				target02 := parseNumber(params[2], kindInt).(int)  // target02
				pct02 := parseNumber(params[3], kindInt64).(int64) // pct02
				target03 := parseNumber(params[4], kindInt).(int)  // target03
				pct03 := parseNumber(params[5], kindInt64).(int64) // pct03
				target04 := parseNumber(params[6], kindInt).(int)  // target04
				pct04 := parseNumber(params[7], kindInt64).(int64) // pct04

				// Update emission distribution percentages
				en.ChangeDistributionPct(
					cross,
					target01, // target01
					pct01,    // pct01
					target02, // target02
					pct02,    // pct02
					target03, // target03
					pct03,    // pct03
					target04, // target04
					pct04,    // pct04
				)

				return nil
			},
		},
		// Governance configuration changes
		{
			pkgPath:    GOV_GOVERNANCE_PATH,
			function:   "Reconfigure",
			paramCount: 7,
			handlerFunc: func(params []string) error {
				// Parse governance configuration parameters
				votingStartDelay := parseInt64(params[0])
				votingPeriod := parseInt64(params[1])
				votingWeightSmoothingDuration := parseInt64(params[2])
				quorum := parseInt64(params[3])
				proposalCreationThreshold := parseInt64(params[4])
				executionDelay := parseInt64(params[5])
				executionWindow := parseInt64(params[6])

				// Reconfigure governance parameters through governance process
				Reconfigure(
					cross,
					votingStartDelay,
					votingPeriod,
					votingWeightSmoothingDuration,
					quorum,
					proposalCreationThreshold,
					executionDelay,
					executionWindow,
				)

				return nil
			},
		},

		// Pool protocol fee configuration
		{
			pkgPath:    POOL_PATH,
			function:   "CollectProtocol",
			paramCount: 6,
			handlerFunc: func(params []string) error {
				// Collect protocol fees
				pl.CollectProtocol(
					cross,
					params[0],                      // token0Path
					params[1],                      // token1Path
					uint32(parseUint64(params[2])), // fee
					std.Address(params[3]),         // recipient
					params[4],                      // amount0Requested
					params[5],                      // amount1Requested
				)

				return nil
			},
		},
		{
			pkgPath:    POOL_PATH,
			function:   "SetFeeProtocol",
			paramCount: 2,
			handlerFunc: func(params []string) error {
				// Parse and validate fee protocol values
				feeProtocol0 := parseInt64(params[0])
				feeProtocol1 := parseInt64(params[1])

				// Validate fee protocol values are within uint8 range
				if feeProtocol0 > 255 {
					panic(ufmt.Sprintf("feeProtocol0 out of range: %d", feeProtocol0))
				}

				if feeProtocol1 > 255 {
					panic(ufmt.Sprintf("feeProtocol1 out of range: %d", feeProtocol1))
				}

				// Set protocol fee percentages
				pl.SetFeeProtocol(
					cross,
					uint8(feeProtocol0), // feeProtocol0
					uint8(feeProtocol1), // feeProtocol1
				)

				return nil
			},
		},
		// Pool creation fee
		{
			pkgPath:    POOL_PATH,
			function:   "SetPoolCreationFee",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Set fee required to create new pools
				pl.SetPoolCreationFee(cross, parseInt64(params[0])) // fee
				return nil
			},
		},
		// Pool withdrawal fee
		{
			pkgPath:    POOL_PATH,
			function:   "SetWithdrawalFee",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Set fee for withdrawing from pools
				pl.SetWithdrawalFee(cross, parseUint64(params[0])) // fee
				return nil
			},
		},

		// Protocol fee distribution
		{
			pkgPath:    PROTOCOL_FEE_PATH,
			function:   "SetDevOpsPct",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Set percentage of protocol fees going to development operations
				pf.SetDevOpsPct(cross, parseInt64(params[0])) // pct
				return nil
			},
		},

		// Router swap fee
		{
			pkgPath:    ROUTER_PATH,
			function:   "SetSwapFee",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Set fee charged for token swaps
				rr.SetSwapFee(cross, parseUint64(params[0])) // fee
				return nil
			},
		},

		// Staker configuration handlers
		{
			pkgPath:    STAKER_PATH,
			function:   "SetDepositGnsAmount",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Set minimum GNS amount required for staking deposits
				sr.SetDepositGnsAmount(cross, parseInt64(params[0])) // amount
				return nil
			},
		},
		{
			pkgPath:    STAKER_PATH,
			function:   "SetMinimumRewardAmount",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Set minimum GNS amount required for staking deposits
				sr.SetMinimumRewardAmount(cross, parseInt64(params[0])) // amount
				return nil
			},
		},
		{
			pkgPath:    STAKER_PATH,
			function:   "SetTokenMinimumRewardAmount",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Set minimum GNS amount required for staking deposits
				// params[0] is a string in the format "tokenPath:amount"
				sr.SetTokenMinimumRewardAmount(cross, params[0]) // amount
				return nil
			},
		},
		{
			pkgPath:    STAKER_PATH,
			function:   "SetPoolTier",
			paramCount: 2,
			handlerFunc: func(params []string) error {
				// Assign tier level to a specific pool
				sr.SetPoolTier(
					cross,
					params[0],              // pool
					parseUint64(params[1]), // tier
				)
				return nil
			},
		},
		{
			pkgPath:    STAKER_PATH,
			function:   "ChangePoolTier",
			paramCount: 2,
			handlerFunc: func(params []string) error {
				// Change existing pool's tier level
				sr.ChangePoolTier(
					cross,
					params[0],              // pool
					parseUint64(params[1]), // tier
				)
				return nil
			},
		},
		{
			pkgPath:    STAKER_PATH,
			function:   "RemovePoolTier",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Remove tier assignment from a pool
				sr.RemovePoolTier(cross, params[0]) // pool
				return nil
			},
		},
		{
			pkgPath:    STAKER_PATH,
			function:   "SetUnStakingFee",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Set fee charged for unstaking operations
				fee := parseInt64(params[0])
				sr.SetUnStakingFee(cross, fee)
				return nil
			},
		},
		{
			pkgPath:    STAKER_PATH,
			function:   "SetWarmUp",
			paramCount: 2,
			handlerFunc: func(params []string) error {
				// Set warm-up period configuration for staking
				percent := parseInt64(params[0])
				block := parseNumber(params[1], kindInt64).(int64)
				sr.SetWarmUp(cross, percent, block)

				return nil
			},
		},

		// System halt controls
		{
			pkgPath:    HALT_PATH,
			function:   "SetHaltLevel",
			paramCount: 1,
			handlerFunc: func(params []string) error {
				// Set system-wide halt status
				halt.SetHaltLevel(cross, halt.HaltLevel(params[0])) // true = halt, false = no halt

				return nil
			},
		},
		{
			pkgPath:    HALT_PATH,
			function:   "SetOperationStatus",
			paramCount: 2,
			handlerFunc: func(params []string) error {
				// Enable or disable specific operation types
				opType := halt.OpType(params[0])
				allowed := parseBool(params[1])

				halt.SetOperationStatus(cross, opType, allowed)

				return nil
			},
		},
	}

	// Register all configured handlers in the registry
	registerHandlers(registry, handlers)

	return registry
}

// registerHandlers batch registers all configured handlers into the registry.
// This helper function processes the handler configuration array and adds each handler to the registry.
//
// Parameters:
//   - registry: the parameter registry to add handlers to
//   - handlerOptions: slice of handler configurations to register
func registerHandlers(registry *ParameterRegistry, handlerOptions []*ParameterHandlerOptions) {
	for _, handlerOption := range handlerOptions {
		registry.register(*handlerOption)
	}
}
