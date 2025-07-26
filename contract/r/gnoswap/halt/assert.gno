package halt

func AssertIsNotHalted(opTypes ...OpType) {
	halted, err := IsHalted(opTypes...)
	if err != nil {
		panic(err)
	}

	if halted {
		panic(halted)
	}
}

func AssertIsNotHaltedPool() {
	AssertIsNotHaltedOperation(OpTypePool)
}

func AssertIsNotHaltedPosition() {
	AssertIsNotHaltedOperation(OpTypePosition)
}

func AssertIsNotHaltedProtocolFee() {
	AssertIsNotHaltedOperation(OpTypeProtocolFee)
}

func AssertIsNotHaltedRouter() {
	AssertIsNotHaltedOperation(OpTypeRouter)
}

func AssertIsNotHaltedStaker() {
	AssertIsNotHaltedOperation(OpTypeStaker)
}

func AssertIsNotHaltedLaunchpad() {
	AssertIsNotHaltedOperation(OpTypeLaunchpad)
}

func AssertIsNotHaltedGovernance() {
	AssertIsNotHaltedOperation(OpTypeGovernance)
}

func AssertIsNotHaltedGovStaker() {
	AssertIsNotHaltedOperation(OpTypeGovStaker)
}

func AssertIsNotHaltedXGns() {
	AssertIsNotHaltedOperation(OpTypeXGns)
}

func AssertIsNotHaltedCommunityPool() {
	AssertIsNotHaltedOperation(OpTypeCommunityPool)
}

func AssertIsNotHaltedEmission() {
	AssertIsNotHaltedOperation(OpTypeEmission)
}

func AssertIsNotHaltedWithdraw() {
	AssertIsNotHaltedOperation(OpTypeWithdraw)
}

func AssertIsNotHaltedOperation(op OpType) {
	if halted := isHaltedOperation(op); halted {
		panic(makeErrorWithDetails(errHalted, op.String()))
	}
}
