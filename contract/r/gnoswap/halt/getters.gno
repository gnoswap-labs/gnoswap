package halt

import (
	"gno.land/p/onbloc/json/v0"
)

// IsHalted returns true if any of the specified operation types are halted.
// Returns error if any operation type is invalid.
//
// Parameters:
//   - opTypes: operation types to inspect; an empty list reports no halted operations
//
// Returns:
//   - halted: true when any requested operation is halted; on invalid input it
//     is also true alongside the error
//   - error: nil when all requested operation types are valid and inspected;
//     an invalid-operation or state error otherwise
func IsHalted(opTypes ...OpType) (bool, error) {
	for _, op := range opTypes {
		if !op.IsValid() {
			return true, makeErrorWithDetails(errInvalidOpType, op.String())
		}

		halted, err := haltStates.IsOperationHalted(op)
		if err != nil {
			return true, err
		}

		if halted {
			return true, nil
		}
	}

	return false, nil
}

// GetHaltConfig returns a copy of the current halt configuration.
//
// Returns:
//   - config: copy of the current halt status keyed by operation type
func GetHaltConfig() HaltConfig {
	return haltStates.ToConfig()
}

// GetHaltConfigJson returns the halt configuration as a JSON string.
//
// Returns:
//   - json: JSON object containing each operation type's halt status
func GetHaltConfigJson() string {
	haltConfig := GetHaltConfig()

	statusNodes := make(map[string]*json.Node)

	for op, halted := range haltConfig {
		statusNodes[op.String()] = json.BoolNode(op.String(), halted)
	}

	objectNode := json.ObjectNode("status", statusNodes)

	return objectNode.String()
}

// IsHaltedPool returns true if pool operations are halted.
//
// Returns:
//   - halted: true when pool operations are halted; false otherwise
func IsHaltedPool() bool {
	return isHaltedOperation(OpTypePool)
}

// IsHaltedPosition returns true if position operations are halted.
//
// Returns:
//   - halted: true when position operations are halted; false otherwise
func IsHaltedPosition() bool {
	return isHaltedOperation(OpTypePosition)
}

// IsHaltedProtocolFee returns true if protocol fee operations are halted.
//
// Returns:
//   - halted: true when protocol-fee operations are halted; false otherwise
func IsHaltedProtocolFee() bool {
	return isHaltedOperation(OpTypeProtocolFee)
}

// IsHaltedRouter returns true if router operations are halted.
//
// Returns:
//   - halted: true when router operations are halted; false otherwise
func IsHaltedRouter() bool {
	return isHaltedOperation(OpTypeRouter)
}

// IsHaltedStaker returns true if staker operations are halted.
//
// Returns:
//   - halted: true when staker operations are halted; false otherwise
func IsHaltedStaker() bool {
	return isHaltedOperation(OpTypeStaker)
}

// IsHaltedLaunchpad returns true if launchpad operations are halted.
//
// Returns:
//   - halted: true when launchpad operations are halted; false otherwise
func IsHaltedLaunchpad() bool {
	return isHaltedOperation(OpTypeLaunchpad)
}

// IsHaltedGovernance returns true if governance operations are halted.
//
// Returns:
//   - halted: true when governance operations are halted; false otherwise
func IsHaltedGovernance() bool {
	return isHaltedOperation(OpTypeGovernance)
}

// IsHaltedGovStaker returns true if governance staker operations are halted.
//
// Returns:
//   - halted: true when governance-staker operations are halted; false otherwise
func IsHaltedGovStaker() bool {
	return isHaltedOperation(OpTypeGovStaker)
}

// IsHaltedXGns returns true if xGNS operations are halted.
//
// Returns:
//   - halted: true when xGNS operations are halted; false otherwise
func IsHaltedXGns() bool {
	return isHaltedOperation(OpTypeXGns)
}

// IsHaltedCommunityPool returns true if community pool operations are halted.
//
// Returns:
//   - halted: true when community-pool operations are halted; false otherwise
func IsHaltedCommunityPool() bool {
	return isHaltedOperation(OpTypeCommunityPool)
}

// IsHaltedEmission returns true if emission operations are halted.
//
// Returns:
//   - halted: true when emission operations are halted; false otherwise
func IsHaltedEmission() bool {
	return isHaltedOperation(OpTypeEmission)
}

// IsHaltedWithdraw returns true if withdraw operations are halted.
//
// Returns:
//   - halted: true when withdrawal operations are halted; false otherwise
func IsHaltedWithdraw() bool {
	return isHaltedOperation(OpTypeWithdraw)
}

// isHaltedOperation returns halt status for the specified operation type.
// Panics if operation type is invalid.
func isHaltedOperation(op OpType) bool {
	if !op.IsValid() {
		panic(makeErrorWithDetails(errInvalidOpType, op.String()))
	}

	halted, err := haltStates.IsOperationHalted(op)
	if err != nil {
		panic(err)
	}

	return halted
}
