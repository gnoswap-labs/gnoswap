package halt

import (
	"gno.land/p/onbloc/json"
)

// IsHalted keeps backward-compatible meaning: operate action for the domains.
func IsHalted(domains ...OpType) (bool, error) {
	for _, domain := range domains {
		halted, err := haltStates.IsActionHalted(domain, ActionOperate)
		if err != nil {
			return true, err
		}
		if halted {
			return true, nil
		}
	}
	return false, nil
}

func IsActionHalted(domain OpType, action Action) (bool, error) {
	return haltStates.IsActionHalted(domain, action)
}

func GetHaltConfig() HaltConfig {
	return haltStates.ToConfig()
}

func GetHaltConfigJson() string {
	haltConfig := GetHaltConfig()
	statusNodes := make(map[string]*json.Node)
	for domain, actions := range haltConfig {
		actionNodes := make(map[string]*json.Node)
		for action, halted := range actions {
			actionNodes[action.String()] = json.BoolNode(action.String(), halted)
		}
		statusNodes[domain.String()] = json.ObjectNode(domain.String(), actionNodes)
	}
	objectNode := json.ObjectNode("status", statusNodes)
	return objectNode.String()
}

func IsHaltedPool() bool          { return isActionHalted(OpTypePool, ActionOperate) }
func IsHaltedPosition() bool      { return isActionHalted(OpTypePosition, ActionOperate) }
func IsHaltedProtocolFee() bool   { return isActionHalted(OpTypeProtocolFee, ActionOperate) }
func IsHaltedRouter() bool        { return isActionHalted(OpTypeRouter, ActionOperate) }
func IsHaltedStaker() bool        { return isActionHalted(OpTypeStaker, ActionOperate) }
func IsHaltedLaunchpad() bool     { return isActionHalted(OpTypeLaunchpad, ActionOperate) }
func IsHaltedGovernance() bool    { return isActionHalted(OpTypeGovernance, ActionOperate) }
func IsHaltedGovStaker() bool     { return isActionHalted(OpTypeGovStaker, ActionOperate) }
func IsHaltedXGns() bool          { return isActionHalted(OpTypeXGns, ActionOperate) }
func IsHaltedCommunityPool() bool { return isActionHalted(OpTypeCommunityPool, ActionOperate) }
func IsHaltedEmission() bool      { return isActionHalted(OpTypeEmission, ActionOperate) }

func isActionHalted(domain OpType, action Action) bool {
	halted, err := haltStates.IsActionHalted(domain, action)
	if err != nil {
		panic(err)
	}
	return halted
}
