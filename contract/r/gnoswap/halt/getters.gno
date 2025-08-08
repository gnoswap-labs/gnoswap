package halt

import (
	"gno.land/p/demo/json"
)

// IsHalted checks if any operation types are halted.
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

// GetHaltConfig returns copy of current halt configuration.
func GetHaltConfig() HaltConfig {
	return haltConfig.Clone()
}

// GetHaltConfigJson returns halt configuration as JSON.
func GetHaltConfigJson() string {
	haltConfig := GetHaltConfig()

	statusNodes := make(map[string]*json.Node)

	for op, halted := range haltConfig {
		statusNodes[op.String()] = json.BoolNode(op.String(), halted)
	}

	objectNode := json.ObjectNode("status", statusNodes)

	return objectNode.String()
}

// IsHaltedPool checks if pool operations are halted.
func IsHaltedPool() bool {
	return isHaltedOperation(OpTypePool)
}

// IsHaltedPosition checks if position operations are halted.
func IsHaltedPosition() bool {
	return isHaltedOperation(OpTypePosition)
}

// IsHaltedProtocolFee checks if protocol fee operations are halted.
func IsHaltedProtocolFee() bool {
	return isHaltedOperation(OpTypeProtocolFee)
}

// IsHaltedRouter checks if router operations are halted.
func IsHaltedRouter() bool {
	return isHaltedOperation(OpTypeRouter)
}

// IsHaltedStaker checks if staker operations are halted.
func IsHaltedStaker() bool {
	return isHaltedOperation(OpTypeStaker)
}

// IsHaltedLaunchpad checks if launchpad operations are halted.
func IsHaltedLaunchpad() bool {
	return isHaltedOperation(OpTypeLaunchpad)
}

// IsHaltedGovernance checks if governance operations are halted.
func IsHaltedGovernance() bool {
	return isHaltedOperation(OpTypeGovernance)
}

// IsHaltedGovStaker checks if governance staker operations are halted.
func IsHaltedGovStaker() bool {
	return isHaltedOperation(OpTypeGovStaker)
}

// IsHaltedXGns checks if xGNS operations are halted.
func IsHaltedXGns() bool {
	return isHaltedOperation(OpTypeXGns)
}

// IsHaltedCommunityPool checks if community pool operations are halted.
func IsHaltedCommunityPool() bool {
	return isHaltedOperation(OpTypeCommunityPool)
}

// IsHaltedEmission checks if emission operations are halted.
func IsHaltedEmission() bool {
	return isHaltedOperation(OpTypeEmission)
}

// IsHaltedWithdraw checks if withdraw operations are halted.
func IsHaltedWithdraw() bool {
	return isHaltedOperation(OpTypeWithdraw)
}

// isHaltedOperation checks halt status, panics on invalid operation.
func isHaltedOperation(op OpType) bool {
	halted, err := haltConfig.get(op)
	if err != nil {
		panic(err)
	}

	return halted
}
