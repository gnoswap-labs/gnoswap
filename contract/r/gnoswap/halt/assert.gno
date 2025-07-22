package halt

func AssertIsHalted(opTypes ...OpType) {
	halted, err := IsHalted(opTypes...)
	if err != nil {
		panic(err)
	}

	if halted {
		panic(halted)
	}
}

func AssertIsHaltedPool() {
	AssertIsHaltedOperation(OpTypePool)
}

func AssertIsHaltedPosition() {
	AssertIsHaltedOperation(OpTypePosition)
}

func AssertIsHaltedProtocolFee() {
	AssertIsHaltedOperation(OpTypeProtocolFee)
}

func AssertIsHaltedRouter() {
	AssertIsHaltedOperation(OpTypeRouter)
}

func AssertIsHaltedStaker() {
	AssertIsHaltedOperation(OpTypeStaker)
}

func AssertIsHaltedLaunchpad() {
	AssertIsHaltedOperation(OpTypeLaunchpad)
}

func AssertIsHaltedGovernance() {
	AssertIsHaltedOperation(OpTypeGovernance)
}

func AssertIsHaltedGovStaker() {
	AssertIsHaltedOperation(OpTypeGovStaker)
}

func AssertIsHaltedXGns() {
	AssertIsHaltedOperation(OpTypeXGns)
}

func AssertIsHaltedCommunityPool() {
	AssertIsHaltedOperation(OpTypeCommunityPool)
}

func AssertIsHaltedEmission() {
	AssertIsHaltedOperation(OpTypeEmission)
}

func AssertIsHaltedWithdraw() {
	AssertIsHaltedOperation(OpTypeWithdraw)
}

func AssertIsHaltedOperation(op OpType) {
	if halted := isHaltedOperation(op); halted {
		panic(makeErrorWithDetails(errHalted, op.String()))
	}
}
