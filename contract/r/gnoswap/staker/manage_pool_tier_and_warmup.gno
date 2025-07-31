package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/halt"

	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
)

const (
	NOT_EMISSION_TARGET_TIER uint64 = 0
)

// SetPoolTierByAdmin sets the tier of a pool by an admin
func SetPoolTierByAdmin(cur realm, poolPath string, tier uint64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	access.AssertIsAdmin(caller)
	assertPoolMustExist(poolPath)

	currentHeight := std.ChainHeight()	
	setPoolTier(poolPath, tier, currentHeight)
	
	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetPoolTierByAdmin",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"tier", formatUint(tier),
		"height", formatInt(currentHeight),
	)
}

// SetPoolTier sets the tier of a pool by governance
func SetPoolTier(cur realm, poolPath string, tier uint64) {
	caller := std.PreviousRealm().Address()
	access.AssertIsGovernance(caller)
	halt.AssertIsNotHaltedStaker()
	assertPoolMustExist(poolPath)

	currentHeight := std.ChainHeight()
	setPoolTier(poolPath, tier, currentHeight)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetPoolTier",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"tier", formatUint(tier),
		"height", formatInt(currentHeight),
	)
}

// ChangePoolTierByAdmin changes the tier of a pool by an admin
func ChangePoolTierByAdmin(cur realm, poolPath string, tier uint64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	access.AssertIsAdmin(caller)
	assertPoolMustExist(poolPath)

	currentHeight := std.ChainHeight()
	previousTier, newTier := changePoolTier(poolPath, tier, currentHeight)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"ChangePoolTierByAdmin",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"prevTier", formatUint(previousTier),
		"newTier", formatUint(newTier),
		"height", formatInt(currentHeight),
	)
}

// ChangePoolTier changes the tier of a pool by governance
func ChangePoolTier(cur realm, poolPath string, tier uint64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	access.AssertIsGovernance(caller)
	assertPoolMustExist(poolPath)

	currentHeight := std.ChainHeight()
	previousTier, newTier := changePoolTier(poolPath, tier, currentHeight)
	
	previousRealm := std.PreviousRealm()
	std.Emit(
		"ChangePoolTier",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"prevTier", formatUint(previousTier),
		"newTier", formatUint(newTier),
		"height", formatInt(currentHeight),
	)
}

// RemovePoolTierByAdmin removes the tier of a pool by an admin
func RemovePoolTierByAdmin(cur realm, poolPath string) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	access.AssertIsAdmin(caller)
	assertPoolMustExist(poolPath)

	currentHeight := std.ChainHeight()
	removePoolTier(poolPath, currentHeight)
	
	previousRealm := std.PreviousRealm()
	std.Emit(
		"RemovePoolTierByAdmin",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"height", formatInt(currentHeight),
	)
}

// RemovePoolTier removes the tier of a pool by governance
func RemovePoolTier(cur realm, poolPath string) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	access.AssertIsGovernance(caller)
	assertPoolMustExist(poolPath)
	
	currentHeight := std.ChainHeight()
	removePoolTier(poolPath, currentHeight)
	
	previousRealm := std.PreviousRealm()
	std.Emit(
		"RemovePoolTier",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"height", formatInt(currentHeight),
	)
}

// SetWarmUpByAdmin sets the warmup percentage and block duration by an admin
func SetWarmUpByAdmin(cur realm, pct, blockDuration int64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	access.AssertIsAdmin(caller)

	setWarmUp(pct, blockDuration)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetWarmUpByAdmin",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"pct", formatInt(pct),
		"blockDuration", formatInt(blockDuration),
	)
}

// SetWarmUp sets the warmup percentage and block duration by governance
func SetWarmUp(cur realm, pct, blockDuration int64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	access.AssertIsGovernance(caller)

	setWarmUp(pct, blockDuration)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetWarmUp",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"pct", formatInt(pct),
		"blockDuration", formatInt(blockDuration),
	)
}

func setPoolTier(poolPath string, tier uint64, height int64) {
	en.MintAndDistributeGns(cross)

	pools.GetOrCreate(poolPath)
	poolTier.changeTier(height, pools, poolPath, tier)
}

func changePoolTier(poolPath string, tier uint64, height int64) (uint64, uint64) {
	en.MintAndDistributeGns(cross)
	previousTier := poolTier.CurrentTier(poolPath)

	poolTier.changeTier(height, pools, poolPath, tier)

	return previousTier, tier
}

func removePoolTier(poolPath string, height int64) {
	en.MintAndDistributeGns(cross)

	poolTier.changeTier(height, pools, poolPath, NOT_EMISSION_TARGET_TIER)
}

func setWarmUp(pct, blockDuration int64) {
	en.MintAndDistributeGns(cross)

	modifyWarmup(pctToIndex(pct), blockDuration)
}

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

func assertPoolMustExist(poolPath string) {
	if !pl.ExistsPoolPath(poolPath) {
		panic(makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("pool(%s) does not exist", poolPath),
		))
	}
}