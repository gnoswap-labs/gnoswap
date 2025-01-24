package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"

	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
)

const (
	NOT_EMISSION_TARGET_TIER uint64 = 0
)

func SetPoolTierByAdmin(poolPath string, tier uint64) {
	assertOnlyAdmin()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	setPoolTier(poolPath, tier)
}

func SetPoolTier(poolPath string, tier uint64) {
	assertOnlyGovernance()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	setPoolTier(poolPath, tier)
}

func setPoolTier(poolPath string, tier uint64) {
	en.MintAndDistributeGns()

	currentHeight := std.GetHeight()
	pools.GetOrCreate(poolPath)
	poolTier.changeTier(currentHeight, pools, poolPath, tier)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetPoolTier",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
		"tier", formatUint(tier),
		"height", formatInt(currentHeight),
	)
}

func ChangePoolTierByAdmin(poolPath string, tier uint64) {
	assertOnlyAdmin()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	changePoolTier(poolPath, tier)
}

func ChangePoolTier(poolPath string, tier uint64) {
	assertOnlyGovernance()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	changePoolTier(poolPath, tier)
}

func changePoolTier(poolPath string, tier uint64) {
	en.MintAndDistributeGns()

	prevTier := poolTier.CurrentTier(poolPath)
	currentHeight := std.GetHeight()
	poolTier.changeTier(currentHeight, pools, poolPath, tier)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"ChangePoolTier",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
		"prevTier", formatUint(prevTier),
		"newTier", formatUint(tier),
		"height", formatInt(currentHeight),
	)
}

func RemovePoolTierByAdmin(poolPath string) {
	assertOnlyAdmin()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	removePoolTier(poolPath)
}

func RemovePoolTier(poolPath string) {
	assertOnlyGovernance()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	removePoolTier(poolPath)
}

func removePoolTier(poolPath string) {
	en.MintAndDistributeGns()

	currentHeight := std.GetHeight()
	poolTier.changeTier(currentHeight, pools, poolPath, NOT_EMISSION_TARGET_TIER)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"RemovePoolTier",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
		"height", formatInt(currentHeight),
	)
}

func SetWarmUpByAdmin(pct, blockDuration int64) {
	assertOnlyAdmin()
	assertMustNotHalted()

	setWarmUp(pct, blockDuration)
}

func SetWarmUp(pct, blockDuration int64) {
	assertOnlyGovernance()
	assertMustNotHalted()

	setWarmUp(pct, blockDuration)
}

func setWarmUp(pct, blockDuration int64) {
	en.MintAndDistributeGns()

	modifyWarmup(pctToIndex(pct), blockDuration)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetWarmUp",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pct", formatUint(pct),
		"blockDuration", formatInt(blockDuration),
	)
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
	if !(pl.DoesPoolPathExist(poolPath)) {
		panic(addDetailToError(
			errInvalidPoolPath,
			ufmt.Sprintf("pool(%s) does not exist", poolPath),
		))
	}
}

func assertOnlyAdmin() {
	common.AdminOnly(getPrevAddr())
}

func assertOnlyGovernance() {
	common.GovernanceOnly(getPrevAddr())
}

func assertMustNotHalted() {
	common.IsHalted()
}
