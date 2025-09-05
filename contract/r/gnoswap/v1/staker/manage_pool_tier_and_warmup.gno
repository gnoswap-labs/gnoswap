package staker

import (
	"std"
	"time"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"

	en "gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/v1/pool"
)

const (
	NOT_EMISSION_TARGET_TIER uint64 = 0
)

// SetPoolTier assigns a tier level to a pool for internal GNS emission rewards.
// Only admin or governance can call this function.
func SetPoolTier(cur realm, poolPath string, tier uint64) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(poolPath)
	assertIsValidPoolTier(tier)

	currentTime := time.Now().Unix()
	setPoolTier(poolPath, tier, currentTime)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetPoolTier",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"tier", formatUint(tier),
		"currentTime", formatInt(currentTime),
		"currentHeight", formatInt(std.ChainHeight()),
	)
}

// ChangePoolTier modifies the tier level of an existing pool.
// Only admin or governance can call this function.
func ChangePoolTier(cur realm, poolPath string, tier uint64) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(poolPath)
	assertIsValidPoolTier(tier)

	currentTime := time.Now().Unix()
	previousTier, newTier := changePoolTier(poolPath, tier, currentTime)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"ChangePoolTier",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"prevTier", formatUint(previousTier),
		"newTier", formatUint(newTier),
		"currentTime", formatInt(currentTime),
		"currentHeight", formatInt(std.ChainHeight()),
	)
}

// RemovePoolTier removes a pool from internal GNS emission rewards.
// Only admin or governance can call this function.
func RemovePoolTier(cur realm, poolPath string) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(poolPath)

	currentTime := time.Now().Unix()
	removePoolTier(poolPath, currentTime)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"RemovePoolTier",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"currentTime", formatInt(currentTime),
		"currentHeight", formatInt(std.ChainHeight()),
	)
}

// SetWarmUp configures the warm-up percentage and duration for rewards.
// Only admin or governance can call this function.
func SetWarmUp(cur realm, pct, timeDuration int64) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	setWarmUp(pct, timeDuration)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetWarmUp",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"pct", formatInt(pct),
		"timeDuration", formatInt(timeDuration),
	)
}

// setPoolTier internally sets the pool tier.
func setPoolTier(poolPath string, tier uint64, currentTime int64) {
	en.MintAndDistributeGns(cross)

	pools.GetOrCreate(poolPath)
	poolTier.changeTier(std.ChainHeight(), currentTime, pools, poolPath, tier)
}

// changePoolTier internally changes the pool tier and returns old and new tiers.
func changePoolTier(poolPath string, tier uint64, currentTime int64) (uint64, uint64) {
	en.MintAndDistributeGns(cross)
	previousTier := poolTier.CurrentTier(poolPath)

	poolTier.changeTier(std.ChainHeight(), currentTime, pools, poolPath, tier)

	return previousTier, tier
}

// removePoolTier internally removes the pool from tier system.
func removePoolTier(poolPath string, currentTime int64) {
	en.MintAndDistributeGns(cross)

	poolTier.changeTier(std.ChainHeight(), currentTime, pools, poolPath, NOT_EMISSION_TARGET_TIER)
}

// setWarmUp internally sets the warm-up parameters.
func setWarmUp(pct, timeDuration int64) {
	en.MintAndDistributeGns(cross)

	modifyWarmup(pctToIndex(pct), timeDuration)
}

// pctToIndex converts percentage to warmup index.
func pctToIndex(pct int64) int {
	switch pct {
	case 30:
		return 0
	case 50:
		return 1
	case 70:
		return 2
	case 100:
		return 3
	default:
		panic("staker.gno__pctToIndex() || pct is not valid")
	}
}

// assertPoolMustExist panics if the pool doesn't exist.
func assertPoolMustExist(poolPath string) {
	if !pl.ExistsPoolPath(poolPath) {
		panic(makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("pool(%s) does not exist", poolPath),
		))
	}
}
