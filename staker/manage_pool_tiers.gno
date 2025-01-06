package staker

import (
	"std"
	"time"

	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

type ApiPoolWithEmissionGnsAmount struct {
	PoolPath       string `json:"poolPath"`
	Tier           uint64 `json:"tier"`
	Amount         uint64 `json:"amount"`
	StartTimestamp int64  `json:"startTimestamp"`
}

// GetPoolsWithTier returns a list of string that consists of pool path and tier
func GetPoolsWithTier() []string {
	var pools []string
	for pool, tier := range poolTiers {
		pools = append(pools, ufmt.Sprintf("%s_%d", pool, tier.tier))
	}
	return pools
}

// GetPoolsWithTierStruct returns a map of pools and their associated tier information
func GetPoolsWithTierStruct() map[string]InternalTier {
	return poolTiers
}

// GetPoolsWithEmissionGnsAmount returns a json formatted list of string that consists of pool path, tier, and the amount of GNS to be distributed as gns emission
func GetPoolsWithEmissionGnsAmount() string {
	var internals []ApiPoolWithEmissionGnsAmount

	const MAX_EMISSION_SUPPLY = 675_000_000_000_000 // uGNS

	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(MAX_EMISSION_SUPPLY)

	tier1Num, tier2Num, tier3Num := getNumPoolTiers()

	for poolPath, internal := range poolTiers {
		tier := internal.tier
		tierAmount := uint64(0)

		if tier == 1 {
			tierAmount = tier1Amount / tier1Num
		} else if tier == 2 {
			tierAmount = tier2Amount / tier2Num
		} else if tier == 3 {
			tierAmount = tier3Amount / tier3Num
		}

		internalIncentive := ApiPoolWithEmissionGnsAmount{}
		internalIncentive.PoolPath = poolPath
		internalIncentive.Tier = tier
		internalIncentive.Amount = tierAmount
		internalIncentive.StartTimestamp = internal.startTimestamp

		internals = append(internals, internalIncentive)
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, internal := range internals {
		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath":       json.StringNode("poolPath", internal.PoolPath),
			"rewardToken":    json.StringNode("rewardToken", consts.GNS_PATH),
			"startTimestamp": json.NumberNode("startTimestamp", float64(internal.StartTimestamp)),
			"tier":           json.NumberNode("tier", float64(internal.Tier)),
			"amount":         json.NumberNode("amount", float64(internal.Amount)),
		})
		responses.AppendArray(_incentiveNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

// GetEachTierPoolNum returns a list of string that consists of each tier and the number of pools in that tier
func GetEachTierPoolNum() []string {
	numTier1, numTier2, numTier3 := getNumPoolTiers()

	tier1 := ufmt.Sprintf("%d_%d", 1, numTier1)
	tier2 := ufmt.Sprintf("%d_%d", 2, numTier2)
	tier3 := ufmt.Sprintf("%d_%d", 3, numTier3)

	return []string{tier1, tier2, tier3}
}

func SetPoolTierByAdmin(poolPath string, tier uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	setPoolTier(poolPath, tier)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetPoolTierByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
		"tier", ufmt.Sprintf("%d", tier),
	)
}

func SetPoolTier(poolPath string, tier uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	setPoolTier(poolPath, tier)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetPoolTier",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
		"tier", ufmt.Sprintf("%d", tier),
	)
}

// setPoolTier sets the tier of a specified pool
//
// Parameters:
//   - pool (string): The path of the pool to set the tier for
//   - tier (uint64): The tier level to set (must be between 1 and 3)
//
// Panics:
//   - Pool does not exist
//   - Pool already exists in poolTiers
//   - Tier is not valid (not between 1 and 3)
func setPoolTier(pool string, tier uint64) {
	common.IsHalted()

	en.MintAndDistributeGns()
	// TODO:
	// 1. If pool does not exist, CalcPoolPosition() will be panic.
	// so, this function always can run while already pool exist.
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	// panic if pool does not exist
	if !(pl.DoesPoolPathExist(pool)) {
		panic(addDetailToError(
			errInvalidPoolPath,
			ufmt.Sprintf("manage_pool_tiers.gno__SetPoolTier() || pool(%s) does not exist", pool),
		))
	}

	// panic if pool exists in poolTiers
	_, exist := poolTiers[pool]
	if exist {
		panic(addDetailToError(
			errAlreadyHasTier,
			ufmt.Sprintf("manage_pool_tiers.gno__SetPoolTier() || pool(%s) already exists in poolTiers", pool),
		))
	}

	// check if tier is valid
	mustValidTier(tier)

	poolTiers[pool] = InternalTier{
		tier:           tier,
		startTimestamp: time.Now().Unix(),
	}
}

func ChangePoolTierByAdmin(poolPath string, tier uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	changePoolTier(poolPath, tier)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"ChangePoolTierByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
		"tier", ufmt.Sprintf("%d", tier),
	)
}

func ChangePoolTier(poolPath string, tier uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"manage_pool_tiers.gno__ChangePoolTier() || only governance(%s) can change existing pool tier, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		))
	}

	changePoolTier(poolPath, tier)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"ChangePoolTier",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
		"tier", ufmt.Sprintf("%d", tier),
	)
}

// changePoolTier changes the tier of an existing pool in poolTiers
//
// Parameters:
//   - pool (string): The path of the pool to change the tier for
//   - tier (uint64): The new tier level to set (must be between 1 and 3)
//
// Panics:
//   - Pool does not exist in poolTiers
//   - Tier is not valid (not between 1 and 3)
//   - Pool is default pool (MUST_EXISTS_IN_TIER_1)
func changePoolTier(pool string, tier uint64) {
	// because we changed poolTiers, previous calculation should be based on last tier
	// from next calculation, it will be based on new tier
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	// panic if pool does not exist in poolTiers
	internal, exist := poolTiers[pool]
	if !exist {
		panic(addDetailToError(
			errInvalidPoolPath,
			ufmt.Sprintf("manage_pool_tiers.gno__ChangePoolTier() || pool(%s) does not exist in poolTiers", pool),
		))
	}

	// check if tier is valid
	mustValidTier(tier)

	// CAN'T CHANGE TIER OF THIS GNS:GNOT 0.3%
	if pool == MUST_EXISTS_IN_TIER_1 {
		panic(addDetailToError(
			errDefaultPoolTier1,
			ufmt.Sprintf("manage_pool_tiers.gno__ChangePoolTier() || cannot change tier of this pool(%s)", pool),
		))
	}

	internal.tier = tier
	poolTiers[pool] = internal
}

func RemovePoolTierByAdmin(poolPath string) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	removePoolTier(poolPath)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"RemovePoolTierByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
	)
}

func RemovePoolTier(poolPath string) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	removePoolTier(poolPath)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"RemovePoolTier",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
	)
}

// removePoolTier removes the pool from poolTiers
//
// Parameters:
//   - pool (string): The path of the pool to remove from poolTiers
//
// Panics:
//   - Pool is default pool (MUST_EXISTS_IN_TIER_1)
func removePoolTier(pool string) {
	common.IsHalted()

	// because we remove pool from poolTiers, this should be final calculation
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	if pool == MUST_EXISTS_IN_TIER_1 {
		panic(addDetailToError(
			errDefaultPoolTier1,
			ufmt.Sprintf("manage_pool_tiers.gno__RemovePoolTier() || cannot remove tier of this pool(%s)", pool),
		))
	}

	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN && caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"manage_pool_tiers.gno__RemovePoolTier() || only admin(%s) or governance(%s) can remove existing pool with tier, called from %s",
				consts.ADMIN,
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		))
	}

	delete(poolTiers, pool)
}

// mustValidTier checks if the provided tier is valid (between 1 and 3)
func mustValidTier(tier uint64) {
	if tier < 1 || tier > 3 {
		panic(addDetailToError(
			errInvalidPoolTier,
			ufmt.Sprintf("tier(%d) must be 1~3", tier),
		))
	}
}

// isExistPoolTier checks if the pool exists in poolTiers
func isExistPoolTiers(poolPath string) bool {
	_, exist := poolTiers[poolPath]
	return exist
}
