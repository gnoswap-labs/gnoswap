package halt

import (
	"gno.land/p/demo/json"

	"gno.land/p/demo/ufmt"
)

// Checks if any of the given operation types are halted
// Returns true if any operation type is not enabled in the halt configuration
// Returns error if an invalid operation type is provided
func IsHalted(opTypes ...OpType) (bool, error) {
	// Validate and check halt status for each operation
	for _, op := range opTypes {
		if !op.IsValid() {
			return true, ufmt.Errorf("invalid operation type: %s", op)
		}

		halted, err := haltConfig.get(op)
		if err != nil {
			return true, err
		}

		if halted {
			return true, nil // Operation is halted
		}
	}

	// No operations are halted
	return false, nil
}

// GetHaltConfig returns a deep copy of the current halt configuration
// This ensures that external modifications cannot affect the internal state
func GetHaltConfig() HaltConfig {
	return haltConfig.Clone()
}

// GetHaltConfigJson returns a JSON string representation of the current halt configuration
// The returned JSON object contains operation types as keys and their enabled status as boolean values
// Example: {"status": {"pool": true, "position": false, ...}}
func GetHaltConfigJson() string {
	haltConfig := GetHaltConfig()

	statusNodes := make(map[string]*json.Node)

	for op, halted := range haltConfig {
		statusNodes[op.String()] = json.BoolNode(op.String(), halted)
	}

	objectNode := json.ObjectNode("status", statusNodes)

	return objectNode.String()
}

// Checks if pool operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedPool() bool {
	return isHaltedOperation(OpTypePool)
}

// Checks if position operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedPosition() bool {
	return isHaltedOperation(OpTypePosition)
}

// Checks if protocol fee operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedProtocolFee() bool {
	return isHaltedOperation(OpTypeProtocolFee)
}

// Checks if router operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedRouter() bool {
	return isHaltedOperation(OpTypeRouter)
}

// Checks if staker operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedStaker() bool {
	return isHaltedOperation(OpTypeStaker)
}

// Checks if launchpad operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedLaunchpad() bool {
	return isHaltedOperation(OpTypeLaunchpad)
}

// Checks if governance operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedGovernance() bool {
	return isHaltedOperation(OpTypeGovernance)
}

// Checks if governance staker operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedGovStaker() bool {
	return isHaltedOperation(OpTypeGovStaker)
}

// Checks if xGNS operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedXGns() bool {
	return isHaltedOperation(OpTypeXGns)
}

// Checks if community pool operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedCommunityPool() bool {
	return isHaltedOperation(OpTypeCommunityPool)
}

// Checks if emission operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedEmission() bool {
	return isHaltedOperation(OpTypeEmission)
}

// Checks if withdraw operations are currently halted
// Returns true if halted, panics if operation type is invalid
func IsHaltedWithdraw() bool {
	return isHaltedOperation(OpTypeWithdraw)
}

// Helper function to check halt status with panic on invalid operation type
// Returns true if operation is halted
func isHaltedOperation(op OpType) bool {
	halted, err := haltConfig.get(op)
	if err != nil {
		panic(err)
	}

	return halted
}
