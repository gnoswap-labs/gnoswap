package staker

import (
	"std"

	pl "gno.land/r/demo/pool"

	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"
)

// GetPoolWithTiers returns list of pools with their tiers
func GetPoolWithTiers() map[string]uint64 {
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
	// check if caller is admin
	isAdmin()

	// panic if pool does not exist
	if !(pl.DoesPoolPathExist(pool)) {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__SetPoolTier() || pool(%s) does not exist"))
	}

	// panic if pool exists in poolTiers
	if _, exist := poolTiers[pool]; exist {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__SetPoolTier() || pool(%s) already exists in poolTiers"))
	}

	// check if tier is valid
	validTier(tier)

	poolTiers[pool] = tier
}

// ChangePoolTier changes the tier of the pool
//
// Panics if any of the following conditions are met:
// - caller is not admin
// - pool does not exist in poolTiers
// - tier is not valid
// - pool is default pool
func ChangePoolTier(pool string, tier uint64) {
	// check if caller is admin
	isAdmin()

	// panic if pool does not exist in poolTiers
	if _, exist := poolTiers[pool]; !exist {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__ChangePoolTier() || pool(%s) does not exist in poolTiers"))
	}

	// check if tier is valid
	validTier(tier)

	// CAN'T CHANGE TIER OF THIS GNS:GNOT 0.3%
	if pool == MUST_EXISTS_IN_TIER_1 {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__ChangePoolTier() || Cannot change tier of this pool(%s)"))
	}

	poolTiers[pool] = tier
}

// RemovePoolTier removes the pool from poolTiers
//
// Panics if any of the following conditions are met:
// - caller is not admin
// - pool is default pool
func RemovePoolTier(pool string) {
	// check if caller is admin
	isAdmin()

	if pool == MUST_EXISTS_IN_TIER_1 {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__RemovePoolTier() || Cannot change tier of this pool"))
	}

	delete(poolTiers, pool)
}

func isAdmin() {
	if std.GetOrigCaller() != consts.GNOSWAP_ADMIN {
		panic(ufmt.Sprintf("caller(%s) is not admin", std.GetOrigCaller()))
	}
}

func validTier(tier uint64) {
	if tier < 1 || tier > 3 {
		panic(ufmt.Sprintf("tier(%d) is not valid", tier))
	}
}
