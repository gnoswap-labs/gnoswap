package halt

// Halt levels define different states of system operation restriction.
const (
	HaltLevelNone      HaltLevel = "NONE"
	HaltLevelSafeMode  HaltLevel = "SAFE_MODE"
	HaltLevelEmergency HaltLevel = "EMERGENCY"
	HaltLevelComplete  HaltLevel = "COMPLETE"
)

// OpType represents operation types as bit flags for bitmask-based halt checks.
type OpType uint64

const (
	OpTypePool          OpType = 1 << iota // 0x001
	OpTypePosition                         // 0x002
	OpTypeProtocolFee                      // 0x004
	OpTypeRouter                           // 0x008
	OpTypeStaker                           // 0x010
	OpTypeLaunchpad                        // 0x020
	OpTypeGovernance                       // 0x040
	OpTypeGovStaker                        // 0x080
	OpTypeXGns                             // 0x100
	OpTypeCommunityPool                    // 0x200
	OpTypeEmission                         // 0x400
	OpTypeWithdraw                         // 0x800

	OpTypeAll = OpTypePool | OpTypePosition | OpTypeProtocolFee |
		OpTypeRouter | OpTypeStaker | OpTypeLaunchpad |
		OpTypeGovernance | OpTypeGovStaker | OpTypeXGns |
		OpTypeCommunityPool | OpTypeEmission | OpTypeWithdraw
)

var haltLevelDescriptions = map[HaltLevel]string{
	HaltLevelNone:      "All operations enabled",
	HaltLevelSafeMode:  "All operations enabled except withdrawals",
	HaltLevelEmergency: "Only governance and withdrawal operations enabled",
	HaltLevelComplete:  "All operations disabled",
}

// HaltLevel represents current system halt state.
type HaltLevel string

func (h HaltLevel) String() string {
	return string(h)
}

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

// opTypeList provides deterministic iteration order.
var opTypeList = []OpType{
	OpTypePool,
	OpTypePosition,
	OpTypeProtocolFee,
	OpTypeRouter,
	OpTypeStaker,
	OpTypeLaunchpad,
	OpTypeGovernance,
	OpTypeGovStaker,
	OpTypeXGns,
	OpTypeCommunityPool,
	OpTypeEmission,
	OpTypeWithdraw,
}

var opTypeNames = map[OpType]string{
	OpTypePool:          "pool",
	OpTypePosition:      "position",
	OpTypeProtocolFee:   "protocol_fee",
	OpTypeRouter:        "router",
	OpTypeStaker:        "staker",
	OpTypeLaunchpad:     "launchpad",
	OpTypeGovernance:    "governance",
	OpTypeGovStaker:     "gov_staker",
	OpTypeXGns:          "xgns",
	OpTypeCommunityPool: "community_pool",
	OpTypeEmission:      "emission",
	OpTypeWithdraw:      "withdraw",
}

var opTypeFromName = map[string]OpType{
	"pool":           OpTypePool,
	"position":       OpTypePosition,
	"protocol_fee":   OpTypeProtocolFee,
	"router":         OpTypeRouter,
	"staker":         OpTypeStaker,
	"launchpad":      OpTypeLaunchpad,
	"governance":     OpTypeGovernance,
	"gov_staker":     OpTypeGovStaker,
	"xgns":           OpTypeXGns,
	"community_pool": OpTypeCommunityPool,
	"emission":       OpTypeEmission,
	"withdraw":       OpTypeWithdraw,
}

func (o OpType) String() string {
	name, ok := opTypeNames[o]
	if !ok {
		return "unknown"
	}
	return name
}

// IsValid returns true if the operation type is a single valid bit flag.
func (o OpType) IsValid() bool {
	return o != 0 && o&OpTypeAll == o && o&(o-1) == 0
}

// OpTypes returns all operation types in a fixed deterministic order.
func OpTypes() []OpType {
	out := make([]OpType, len(opTypeList))
	copy(out, opTypeList)
	return out
}

// OpTypeFromString converts a string name to the corresponding OpType.
func OpTypeFromString(s string) (OpType, bool) {
	op, ok := opTypeFromName[s]
	return op, ok
}
