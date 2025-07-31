package staker

import (
	"std"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/halt"

	en "gno.land/r/gnoswap/v1/emission"
)

const (
	NOT_EMISSION_TARGET_TIER uint64 = 0
)

// SetPoolTier sets the tier of a pool by governance
func SetPoolTier(cur realm, poolPath string, tier uint64) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(poolPath)
	assertIsValidPoolTier(tier)

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

// ChangePoolTier changes the tier of a pool by governance
func ChangePoolTier(cur realm, poolPath string, tier uint64) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(poolPath)
	assertIsValidPoolTier(tier)

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

// RemovePoolTier removes the tier of a pool by governance
func RemovePoolTier(cur realm, poolPath string) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(poolPath)

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

// SetWarmUp sets the warmup percentage and block duration by governance
func SetWarmUp(cur realm, pct, blockDuration int64) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

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
