package halt

// AssertIsNotHalted panics if any of the specified operation types are halted.
// Panics with error if operation type is invalid or any operation is halted.
func AssertIsNotHalted(opTypes ...OpType) {
	halted, err := IsHalted(opTypes...)
	if err != nil {
		panic(err)
	}

	if halted {
		panic(halted)
	}
}

// AssertIsNotHaltedPool panics if pool operations are halted.
func AssertIsNotHaltedPool() {
	AssertIsNotHaltedOperation(OpTypePool)
}

// AssertIsNotHaltedPosition panics if position operations are halted.
func AssertIsNotHaltedPosition() {
	AssertIsNotHaltedOperation(OpTypePosition)
}

// AssertIsNotHaltedProtocolFee panics if protocol fee operations are halted.
func AssertIsNotHaltedProtocolFee() {
	AssertIsNotHaltedOperation(OpTypeProtocolFee)
}

// AssertIsNotHaltedRouter panics if router operations are halted.
func AssertIsNotHaltedRouter() {
	AssertIsNotHaltedOperation(OpTypeRouter)
}

// AssertIsNotHaltedStaker panics if staker operations are halted.
func AssertIsNotHaltedStaker() {
	AssertIsNotHaltedOperation(OpTypeStaker)
}

// AssertIsNotHaltedLaunchpad panics if launchpad operations are halted.
func AssertIsNotHaltedLaunchpad() {
	AssertIsNotHaltedOperation(OpTypeLaunchpad)
}

// AssertIsNotHaltedGovernance panics if governance operations are halted.
func AssertIsNotHaltedGovernance() {
	AssertIsNotHaltedOperation(OpTypeGovernance)
}

// AssertIsNotHaltedGovStaker panics if governance staker operations are halted.
func AssertIsNotHaltedGovStaker() {
	AssertIsNotHaltedOperation(OpTypeGovStaker)
}

// AssertIsNotHaltedXGns panics if xGNS operations are halted.
func AssertIsNotHaltedXGns() {
	AssertIsNotHaltedOperation(OpTypeXGns)
}

// AssertIsNotHaltedCommunityPool panics if community pool operations are halted.
func AssertIsNotHaltedCommunityPool() {
	AssertIsNotHaltedOperation(OpTypeCommunityPool)
}

// AssertIsNotHaltedEmission panics if emission operations are halted.
func AssertIsNotHaltedEmission() {
	AssertIsNotHaltedOperation(OpTypeEmission)
}

// AssertIsNotHaltedWithdraw panics if withdraw operations are halted.
func AssertIsNotHaltedWithdraw() {
	AssertIsNotHaltedOperation(OpTypeWithdraw)
}

// AssertIsNotHaltedOperation panics if the specified operation type is halted.
// Panics with error details including operation type name.
func AssertIsNotHaltedOperation(op OpType) {
	if halted := isHaltedOperation(op); halted {
		panic(makeErrorWithDetails(errHalted, op.String()))
	}
}
