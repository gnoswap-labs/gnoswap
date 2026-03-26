package halt

import (
	"gno.land/p/onbloc/json"
)

// IsHalted returns true if any of the specified operation types are halted.
// Returns error if any operation type is invalid.
func IsHalted(ops ...OpType) (bool, error) {
	var mask uint64
	for _, op := range ops {
		if !op.IsValid() {
			return true, makeErrorWithDetails(errInvalidOpType, op.String())
		}
		mask |= uint64(op)
	}
	return haltState&mask != 0, nil
}

// GetHaltConfig returns the current halt configuration as a map of operation name to halted status.
func GetHaltConfig() map[string]bool {
	config := make(map[string]bool, len(opTypeList))
	for _, op := range opTypeList {
		config[op.String()] = haltState&uint64(op) != 0
	}
	return config
}

// GetHaltConfigJson returns the halt configuration as a JSON string.
// Uses opTypeList for deterministic key ordering.
func GetHaltConfigJson() string {
	statusNodes := make(map[string]*json.Node)
	for _, op := range opTypeList {
		name := op.String()
		halted := haltState&uint64(op) != 0
		statusNodes[name] = json.BoolNode(name, halted)
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
	if !op.IsValid() {
		panic(makeErrorWithDetails(errInvalidOpType, op.String()))
	}
	return haltState&uint64(op) != 0
}
