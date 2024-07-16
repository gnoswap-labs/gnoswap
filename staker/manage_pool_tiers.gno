package staker

import (
	"std"
	"time"

	pl "gno.land/r/gnoswap/pool"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/consts"

	en "gno.land/r/gnoswap/emission"
)

// GetPoolWithTiers returns list of pools with their tiers
func GetPoolWithTiers() map[string]InternalTier {
	return poolTiers
}

// SetPoolTier sets the tier of the pool
//
// Panics if any of the following conditions are met:
// - caller is not admin
// - pool does not exist
// - pool exists in poolTiers
// - tier is not valid
func SetPoolTier(pool string, tier uint64) {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	// panic if pool does not exist
	if !(pl.DoesPoolPathExist(pool)) {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__SetPoolTier() || pool(%s) does not exist"))
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
	validTier(tier)

	poolTiers[pool] = InternalTier{
		tier:           tier,
		startTimestamp: time.Now().Unix(),
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

// ChangePoolTier changes the tier of the pool
//
// Panics if any of the following conditions are met:
// - caller is not admin
// - pool does not exist in poolTiers
// - tier is not valid
// - pool is default pool
func ChangePoolTier(pool string, tier uint64) {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	// panic if pool does not exist in poolTiers
	internal, exist := poolTiers[pool]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__ChangePoolTier() || pool(%s) does not exist in poolTiers"))
	}

	// check if tier is valid
	validTier(tier)

	// CAN'T CHANGE TIER OF THIS GNS:GNOT 0.3%
	if pool == MUST_EXISTS_IN_TIER_1 {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__ChangePoolTier() || Cannot change tier of this pool(%s)"))
	}

	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"[STAKER] manage_pool_tiers.gno__ChangePoolTier() || only admin(%s) or governance(%s) can change existing pool with tier, called from %s",
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
	poolTiers[pool] = internal
}

// RemovePoolTier removes the pool from poolTiers
//
// Panics if any of the following conditions are met:
// - caller is not admin
// - pool is default pool
func RemovePoolTier(pool string) {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	if pool == MUST_EXISTS_IN_TIER_1 {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__RemovePoolTier() || Cannot change tier of this pool"))
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

func validTier(tier uint64) {
	if tier < 1 || tier > 3 {
		panic(ufmt.Sprintf("tier(%d) is not valid", tier))
	}
}
