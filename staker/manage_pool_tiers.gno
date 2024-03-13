package staker

import (
	"std"

	pl "gno.land/r/demo/pool"

	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"
)

func GetPoolWithTiers() map[string]uint64 {
	return poolTiers
}

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

func ChangePoolTier(pool string, tier uint64) {
	// check if caller is admin
	isAdmin()

	// panic if pool does not exist in poolTiers
	if _, exist := poolTiers[pool]; !exist {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__ChangePoolTier() || pool(%s) does not exist in poolTiers"))
	}

	// check if tier is valid
	validTier(tier)

	// CAN'T CHANGE TIER OF THIS GNS:GNOT 0.03%
	if pool == MUST_EXISTS_IN_TIER_1 {
		panic(ufmt.Sprintf("[STAKER] manage_pool_tiers.gno__ChangePoolTier() || Cannot change tier of this pool(%s)"))
	}

	poolTiers[pool] = tier
}

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
