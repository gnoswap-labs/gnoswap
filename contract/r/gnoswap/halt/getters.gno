package halt

import (
	"gno.land/p/onbloc/json"
)

// IsHalted returns true if any of the specified operation types are halted.
// Returns error if any operation type is invalid.
func IsHalted(opTypes ...OpType) (bool, error) {
	for _, op := range opTypes {
		if !op.IsValid() {
			return true, makeErrorWithDetails(errInvalidOpType, op.String())
		}

		halted, err := haltConfig.get(op)
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
func GetHaltConfig() HaltConfig {
	return haltConfig.Clone()
}

// GetHaltConfigJson returns the halt configuration as a JSON string.
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
func IsHaltedPool() bool {
	return isHaltedOperation(OpTypePool)
}

// IsHaltedPosition returns true if position operations are halted.
func IsHaltedPosition() bool {
	return isHaltedOperation(OpTypePosition)
}

// IsHaltedProtocolFee returns true if protocol fee operations are halted.
func IsHaltedProtocolFee() bool {
	return isHaltedOperation(OpTypeProtocolFee)
}

// IsHaltedRouter returns true if router operations are halted.
func IsHaltedRouter() bool {
	return isHaltedOperation(OpTypeRouter)
}

// IsHaltedStaker returns true if staker operations are halted.
func IsHaltedStaker() bool {
	return isHaltedOperation(OpTypeStaker)
}

// IsHaltedLaunchpad returns true if launchpad operations are halted.
func IsHaltedLaunchpad() bool {
	return isHaltedOperation(OpTypeLaunchpad)
}

// IsHaltedGovernance returns true if governance operations are halted.
func IsHaltedGovernance() bool {
	return isHaltedOperation(OpTypeGovernance)
}

// IsHaltedGovStaker returns true if governance staker operations are halted.
func IsHaltedGovStaker() bool {
	return isHaltedOperation(OpTypeGovStaker)
}

// IsHaltedXGns returns true if xGNS operations are halted.
func IsHaltedXGns() bool {
	return isHaltedOperation(OpTypeXGns)
}

// IsHaltedCommunityPool returns true if community pool operations are halted.
func IsHaltedCommunityPool() bool {
	return isHaltedOperation(OpTypeCommunityPool)
}

// IsHaltedEmission returns true if emission operations are halted.
func IsHaltedEmission() bool {
	return isHaltedOperation(OpTypeEmission)
}

// IsHaltedWithdraw returns true if withdraw operations are halted.
func IsHaltedWithdraw() bool {
	return isHaltedOperation(OpTypeWithdraw)
}

// isHaltedOperation returns halt status for the specified operation type.
// Panics if operation type is invalid.
func isHaltedOperation(op OpType) bool {
	halted, err := haltConfig.get(op)
	if err != nil {
		panic(err)
	}

	return halted
}
