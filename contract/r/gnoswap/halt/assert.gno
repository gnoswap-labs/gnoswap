package halt

func AssertActionAllowed(domain OpType, action Action) {
	if halted := isActionHalted(domain, action); halted {
		panic(makeErrorWithDetails(errHalted, policyKey(domain, action)))
	}
}

func AssertIsNotHaltedPool()       { AssertActionAllowed(OpTypePool, ActionOperate) }
func AssertIsNotHaltedPosition()   { AssertActionAllowed(OpTypePosition, ActionOperate) }
func AssertIsNotHaltedProtocolFee() { AssertActionAllowed(OpTypeProtocolFee, ActionOperate) }
func AssertIsNotHaltedRouter()     { AssertActionAllowed(OpTypeRouter, ActionOperate) }
func AssertIsNotHaltedStaker()     { AssertActionAllowed(OpTypeStaker, ActionOperate) }
func AssertIsNotHaltedLaunchpad()  { AssertActionAllowed(OpTypeLaunchpad, ActionOperate) }
func AssertIsNotHaltedGovernance() { AssertActionAllowed(OpTypeGovernance, ActionOperate) }
func AssertIsNotHaltedGovStaker()  { AssertActionAllowed(OpTypeGovStaker, ActionOperate) }
func AssertIsNotHaltedXGns()       { AssertActionAllowed(OpTypeXGns, ActionOperate) }
func AssertIsNotHaltedCommunityPool() { AssertActionAllowed(OpTypeCommunityPool, ActionOperate) }
func AssertIsNotHaltedEmission()   { AssertActionAllowed(OpTypeEmission, ActionOperate) }

func AssertCanRecover(domain OpType) {
	AssertActionAllowed(domain, ActionRecover)
}
