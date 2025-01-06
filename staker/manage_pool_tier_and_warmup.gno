package staker

import (
	"std"
	"strconv"

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
		"tier", strconv.FormatUint(tier, 10),
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
		"tier", strconv.FormatUint(tier, 10),
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

func SetWramUpByAdmin(index, duration uint64) {
	assertOnlyAdmin()
	assertMustNotHalted()

	setWramUp(index, duration)
}

func SetWramUp(index, blockDuration uint64) {
	assertOnlyGovernance()
	assertMustNotHalted()

	setWramUp(index, blockDuration)
}

func setWramUp(index, blockDuration uint64) {
	en.MintAndDistributeGns()

	modifyWarmup(int(index), int64(blockDuration))

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetWramUp",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"index", strconv.FormatUint(index, 10),
		"blockDuration", strconv.FormatUint(blockDuration, 10),
	)
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
