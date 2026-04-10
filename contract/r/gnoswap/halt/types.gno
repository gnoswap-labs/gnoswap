package halt

// Halt levels define different states of system operation restriction.
const (
	HaltLevelNone      HaltLevel = "NONE"      // All actions enabled.
	HaltLevelSafeMode  HaltLevel = "SAFE_MODE" // Shared recovery actions halted.
	HaltLevelEmergency HaltLevel = "EMERGENCY" // Governance operate + recovery actions remain enabled.
	HaltLevelComplete  HaltLevel = "COMPLETE"  // All actions disabled.
)

// Domain keys represent protocol areas controlled by halt policy.
const (
	OpTypePool          OpType = "pool"
	OpTypePosition      OpType = "position"
	OpTypeProtocolFee   OpType = "protocol_fee"
	OpTypeRouter        OpType = "router"
	OpTypeStaker        OpType = "staker"
	OpTypeLaunchpad     OpType = "launchpad"
	OpTypeGovernance    OpType = "governance"
	OpTypeGovStaker     OpType = "gov_staker"
	OpTypeXGns          OpType = "xgns"
	OpTypeCommunityPool OpType = "community_pool"
	OpTypeEmission      OpType = "emission"
)

// Action keys represent the type of behavior being controlled within a domain.
const (
	ActionOperate Action = "operate"
	ActionRecover Action = "recover"
)

var haltLevelDescriptions = map[HaltLevel]string{
	HaltLevelNone:      "All actions enabled",
	HaltLevelSafeMode:  "Shared recovery actions halted",
	HaltLevelEmergency: "Governance operate and recovery actions remain enabled",
	HaltLevelComplete:  "All actions disabled",
}

type HaltLevel string

func (h HaltLevel) String() string { return string(h) }

func (h HaltLevel) Description() string {
	desc, ok := haltLevelDescriptions[h]
	if !ok {
		return "Unknown halt level"
	}
	return desc
}

func (h HaltLevel) IsValid() bool {
	switch h {
	case HaltLevelNone, HaltLevelSafeMode, HaltLevelEmergency, HaltLevelComplete:
		return true
	default:
		return false
	}
}

// OpType now represents the domain axis of halt policy.
type OpType string

var opTypes = map[OpType]bool{
	OpTypePool:          true,
	OpTypePosition:      true,
	OpTypeProtocolFee:   true,
	OpTypeRouter:        true,
	OpTypeStaker:        true,
	OpTypeLaunchpad:     true,
	OpTypeGovernance:    true,
	OpTypeGovStaker:     true,
	OpTypeXGns:          true,
	OpTypeCommunityPool: true,
	OpTypeEmission:      true,
}

func (o OpType) String() string { return string(o) }

func (o OpType) IsValid() bool {
	_, ok := opTypes[o]
	return ok
}

func OpTypes() []OpType {
	allOpTypes := make([]OpType, 0, len(opTypes))
	for op := range opTypes {
		allOpTypes = append(allOpTypes, op)
	}
	return allOpTypes
}

type Action string

var actions = map[Action]bool{
	ActionOperate: true,
	ActionRecover: true,
}

func (a Action) String() string { return string(a) }

func (a Action) IsValid() bool {
	_, ok := actions[a]
	return ok
}

func Actions() []Action {
	allActions := make([]Action, 0, len(actions))
	for action := range actions {
		allActions = append(allActions, action)
	}
	return allActions
}

var allowedActionsByDomain = map[OpType]map[Action]bool{
	OpTypePool: {
		ActionOperate: true,
		ActionRecover: true,
	},
	OpTypePosition: {
		ActionOperate: true,
		ActionRecover: true,
	},
	OpTypeProtocolFee: {
		ActionOperate: true,
	},
	OpTypeRouter: {
		ActionOperate: true,
	},
	OpTypeStaker: {
		ActionOperate: true,
		ActionRecover: true,
	},
	OpTypeLaunchpad: {
		ActionOperate: true,
		ActionRecover: true,
	},
	OpTypeGovernance: {
		ActionOperate: true,
	},
	OpTypeGovStaker: {
		ActionOperate: true,
		ActionRecover: true,
	},
	OpTypeXGns: {
		ActionOperate: true,
		ActionRecover: true,
	},
	OpTypeCommunityPool: {
		ActionOperate: true,
	},
	OpTypeEmission: {
		ActionOperate: true,
	},
}

func IsAllowedAction(domain OpType, action Action) bool {
	allowedActions, ok := allowedActionsByDomain[domain]
	if !ok {
		return false
	}
	_, ok = allowedActions[action]
	return ok
}

func policyKey(domain OpType, action Action) string {
	return domain.String() + ":" + action.String()
}
