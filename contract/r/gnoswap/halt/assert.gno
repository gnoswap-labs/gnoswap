package halt

func AssertIsNotHaltedPool()          { assertActionAllowed(OpTypePool, ActionOperate) }
func AssertIsNotHaltedPosition()      { assertActionAllowed(OpTypePosition, ActionOperate) }
func AssertIsNotHaltedProtocolFee()   { assertActionAllowed(OpTypeProtocolFee, ActionOperate) }
func AssertIsNotHaltedRouter()        { assertActionAllowed(OpTypeRouter, ActionOperate) }
func AssertIsNotHaltedStaker()        { assertActionAllowed(OpTypeStaker, ActionOperate) }
func AssertIsNotHaltedLaunchpad()     { assertActionAllowed(OpTypeLaunchpad, ActionOperate) }
func AssertIsNotHaltedGovernance()    { assertActionAllowed(OpTypeGovernance, ActionOperate) }
func AssertIsNotHaltedGovStaker()     { assertActionAllowed(OpTypeGovStaker, ActionOperate) }
func AssertIsNotHaltedXGns()          { assertActionAllowed(OpTypeXGns, ActionOperate) }
func AssertIsNotHaltedCommunityPool() { assertActionAllowed(OpTypeCommunityPool, ActionOperate) }
func AssertIsNotHaltedEmission()      { assertActionAllowed(OpTypeEmission, ActionOperate) }

func AssertCanRecover(domain OpType) {
	assertActionAllowed(domain, ActionRecover)
}

func assertActionAllowed(domain OpType, action Action) {
	if halted := isActionHalted(domain, action); halted {
		panic(makeErrorWithDetails(errHalted, policyKey(domain, action)))
	}
}
