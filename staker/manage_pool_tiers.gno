package staker

import (
	"std"
	"time"

	en "gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/pool"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/consts"
)

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
