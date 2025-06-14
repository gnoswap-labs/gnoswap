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
func SetPoolTierByAdmin(poolPath string, tier uint64) {
	crossing()
	assertOnlyAdmin()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	setPoolTier(poolPath, tier)
}

// SetPoolTier sets the tier of a pool by governance
func SetPoolTier(poolPath string, tier uint64) {
	crossing()
	assertOnlyGovernance()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	setPoolTier(poolPath, tier)
}

func setPoolTier(poolPath string, tier uint64) {
	cross(en.MintAndDistributeGns)()

	currentHeight := std.ChainHeight()
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

// ChangePoolTierByAdmin changes the tier of a pool by an admin
func ChangePoolTierByAdmin(poolPath string, tier uint64) {
	crossing()
	assertOnlyAdmin()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	changePoolTier(poolPath, tier)
}

// ChangePoolTier changes the tier of a pool by governance
func ChangePoolTier(poolPath string, tier uint64) {
	crossing()
	assertOnlyGovernance()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	changePoolTier(poolPath, tier)
}

func changePoolTier(poolPath string, tier uint64) {
	cross(en.MintAndDistributeGns)()

	prevTier := poolTier.CurrentTier(poolPath)
	currentHeight := std.ChainHeight()
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

// RemovePoolTierByAdmin removes the tier of a pool by an admin
func RemovePoolTierByAdmin(poolPath string) {
	crossing()
	assertOnlyAdmin()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	removePoolTier(poolPath)
}

// RemovePoolTier removes the tier of a pool by governance
func RemovePoolTier(poolPath string) {
	crossing()
	assertOnlyGovernance()
	assertMustNotHalted()
	assertPoolMustExist(poolPath)

	removePoolTier(poolPath)
}

func removePoolTier(poolPath string) {
	cross(en.MintAndDistributeGns)()

	currentHeight := std.ChainHeight()
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

// SetWarmUpByAdmin sets the warmup percentage and block duration by an admin
func SetWarmUpByAdmin(pct, blockDuration int64) {
	crossing()
	assertOnlyAdmin()
	assertMustNotHalted()

	setWarmUp(pct, blockDuration)
}

// SetWarmUp sets the warmup percentage and block duration by governance
func SetWarmUp(pct, blockDuration int64) {
	crossing()
	assertOnlyGovernance()
	assertMustNotHalted()

	setWarmUp(pct, blockDuration)
}

func setWarmUp(pct, blockDuration int64) {
	cross(en.MintAndDistributeGns)()

	modifyWarmup(pctToIndex(pct), blockDuration)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetWarmUp",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pct", formatInt(pct),
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
	access.AdminOnly(getPrevAddr())
}

func assertOnlyGovernance() {
	access.GovernanceOnly(getPrevAddr())
}

func assertMustNotHalted() {
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}
}
