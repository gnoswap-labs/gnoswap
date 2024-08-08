package staker

import (
	"std"
	"time"

	en "gno.land/r/gnoswap/v2/emission"
	pl "gno.land/r/gnoswap/v2/pool"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"
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
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__GetPoolsWithEmissionGnsAmount() || json marshal error: %s", err.Error()))
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

// SetPoolTier sets the tier of a specified pool
//
// Parameters:
//   - pool (string): The path of the pool to set the tier for
//   - tier (uint64): The tier level to set (must be between 1 and 3)
//
// Panics:
//   - Caller is not admin or governance address
//   - Pool does not exist
//   - Pool already exists in poolTiers
//   - Tier is not valid (not between 1 and 3)
func SetPoolTier(pool string, tier uint64) {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	// panic if pool does not exist
	if !(pl.DoesPoolPathExist(pool)) {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__SetPoolTier() || pool(%s) does not exist", pool))
	}

	// panic if pool exists in poolTiers
	_, exist := poolTiers[pool]
	if exist {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__SetPoolTier() || pool(%s) already exists in poolTiers", pool))
	}

	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"[STAKER] manage_pool_tiers.gno__SetPoolTier() || only admin(%s) or governance(%s) can set additional pool with tier, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	// check if tier is valid
	mustValidTier(tier)

	poolTiers[pool] = InternalTier{
		tier:           tier,
		startTimestamp: time.Now().Unix(),
		startHeight:    std.GetHeight(),
		updateHeight:   std.GetHeight(),
	}

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_poolPath", pool,
		"p_tier", uint64ToStr(tier),
	)
}

// ChangePoolTier changes the tier of an existing pool in poolTiers
//
// Parameters:
//   - pool (string): The path of the pool to change the tier for
//   - tier (uint64): The new tier level to set (must be between 1 and 3)
//
// Panics:
//   - Caller is not admin or governance address
//   - Pool does not exist in poolTiers
//   - Tier is not valid (not between 1 and 3)
//   - Pool is default pool (MUST_EXISTS_IN_TIER_1)
func ChangePoolTier(pool string, tier uint64) {
	// because we changed poolTiers, previous calculation should be based on last tier
	// from next calculation, it will be based on new tier
	en.MintAndDistributeGns()
	CalcPoolPosition()

	// panic if pool does not exist in poolTiers
	internal, exist := poolTiers[pool]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__ChangePoolTier() || pool(%s) does not exist in poolTiers", pool))
	}

	// check if tier is valid
	mustValidTier(tier)

	// CAN'T CHANGE TIER OF THIS GNS:GNOT 0.3%
	if pool == MUST_EXISTS_IN_TIER_1 {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__ChangePoolTier() || Cannot change tier of this pool(%s)", pool))
	}

	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"[STAKER] manage_pool_tiers.gno__ChangePoolTier() || only admin(%s) or governance(%s) can change existing pool tier, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_poolPath", pool,
		"p_tier", uint64ToStr(tier),
	)

	internal.tier = tier
	internal.updateHeight = std.GetHeight()
	poolTiers[pool] = internal
}

// RemovePoolTier removes the pool from poolTiers
//
// Parameters:
//   - pool (string): The path of the pool to remove from poolTiers
//
// Panics:
//   - Caller is not admin or governance address
//   - Pool is default pool (MUST_EXISTS_IN_TIER_1)
func RemovePoolTier(pool string) {
	// because we remove pool from poolTiers, this should be final calculation
	en.MintAndDistributeGns()
	CalcPoolPosition()

	if pool == MUST_EXISTS_IN_TIER_1 {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__RemovePoolTier() || Cannot change tier of this pool(%s)", pool))
	}

	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"[STAKER] manage_pool_tiers.gno__RemovePoolTier() || only admin(%s) or governance(%s) can remove existing pool with tier, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	delete(poolTiers, pool)

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_poolPath", pool,
	)
}

// mustValidTier checks if the provided tier is valid (between 1 and 3)
func mustValidTier(tier uint64) {
	if tier < 1 || tier > 3 {
		panic(ufmt.Sprintf("tier(%d) is not valid", tier))
	}
}
