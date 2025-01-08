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

	poolTier.changeTier(uint64(std.GetHeight()), poolPath, tier)
	pools.GetOrCreate(poolPath)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetPoolTier",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
		"tier", ufmt.Sprintf("%d", tier),
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

	poolTier.changeTier(uint64(std.GetHeight()), poolPath, tier)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"ChangePoolTier",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
		"tier", ufmt.Sprintf("%d", tier),
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

	poolTier.changeTier(uint64(std.GetHeight()), poolPath, NOT_EMISSION_TARGET_TIER)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"RemovePoolTier",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
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
		"pct", ufmt.Sprintf("%d", pct),
		"blockDuration", ufmt.Sprintf("%d", blockDuration),
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
