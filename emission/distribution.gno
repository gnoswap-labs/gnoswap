package emission

import (
	"std"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"

	"gno.land/p/demo/ufmt"
)

// emissionTarget represents different targets for token emission.
type emissionTarget int

// distributionPctMap maps emission targets to their respective distribution percentages.
type distributionPctMap map[emissionTarget]uint64

// TODO:
// 1. change more clear name from LIQUIDITY_STAKING to LIQUIDITY_STAKER
const (
	LIQUIDITY_STAKER emissionTarget = iota + 1
	DEVOPS
	COMMUNITY_POOL
	GOV_STAKER
)

// distributionPct defines the distribution percentages.
var distributionPct distributionPctMap = distributionPctMap{
	LIQUIDITY_STAKER: 7500, // 75%
	DEVOPS:           2000, // 20%
	COMMUNITY_POOL:   500,  // 5%
	GOV_STAKER:       0,    // 0%
}

var (
	toStaker        uint64
	toDevOps        uint64
	toCommunityPool uint64
	toGovStaker     uint64

	toStakerAccu        uint64
	toDevOpsAccu        uint64
	toCommunityPoolAccu uint64
	toGovStakerAccu     uint64
)

// GetDistributionPct returns the distribution percentage for the given target.
func GetDistributionPct(target int) uint64 {
	return distributionPct[emissionTarget(target)]
}

// ChangeDistributionPctByAdmin changes the distribution percentage for the given targets.
// Panics if the caller is not the admin.
func ChangeDistributionPctByAdmin(
	target01 int, pct01 uint64,
	target02 int, pct02 uint64,
	target03 int, pct03 uint64,
	target04 int, pct04 uint64,
) {
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("emission.gno__ChangeDistributionPctByAdmin() || only admin(%s) can change distribution percentages, called from %s", consts.ADMIN, caller.String()),
		))
	}

	checkSumDistributionPct(pct01, pct02, pct03, pct04)

	changeDistributionPcts(
		target01, pct01,
		target02, pct02,
		target03, pct03,
		target04, pct04,
	)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"ChangeDistributionPctByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"target01", ufmt.Sprintf("%d", target01),
		"pct01", ufmt.Sprintf("%d", pct01),
		"target02", ufmt.Sprintf("%d", target02),
		"pct02", ufmt.Sprintf("%d", pct02),
		"target03", ufmt.Sprintf("%d", target03),
		"pct03", ufmt.Sprintf("%d", pct03),
		"target04", ufmt.Sprintf("%d", target04),
		"pct04", ufmt.Sprintf("%d", pct04),
	)
}

// ChangeDistributionPct changes the distribution percentage for the given targets.
// Panics if the caller is not the governance contract.
func ChangeDistributionPct(
	target01 int, pct01 uint64,
	target02 int, pct02 uint64,
	target03 int, pct03 uint64,
	target04 int, pct04 uint64,
) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("emission.gno__ChangeDistributionPct() || only governance(%s) can change distribution percentages, called from %s", consts.GOV_GOVERNANCE_ADDR, caller.String()),
		))
	}

	checkSumDistributionPct(pct01, pct02, pct03, pct04)

	changeDistributionPcts(
		target01, pct01,
		target02, pct02,
		target03, pct03,
		target04, pct04,
	)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"ChangeDistributionPct",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"target01", ufmt.Sprintf("%d", target01),
		"pct01", ufmt.Sprintf("%d", pct01),
		"target02", ufmt.Sprintf("%d", target02),
		"pct02", ufmt.Sprintf("%d", pct02),
		"target03", ufmt.Sprintf("%d", target03),
		"pct03", ufmt.Sprintf("%d", pct03),
		"target04", ufmt.Sprintf("%d", target04),
		"pct04", ufmt.Sprintf("%d", pct04),
	)
}

func changeDistributionPcts(
	target01 int, pct01 uint64,
	target02 int, pct02 uint64,
	target03 int, pct03 uint64,
	target04 int, pct04 uint64,
) {
	common.IsHalted()

	checkSumDistributionPct(pct01, pct02, pct03, pct04)

	changeDistributionPct(emissionTarget(target01), pct01)
	changeDistributionPct(emissionTarget(target02), pct02)
	changeDistributionPct(emissionTarget(target03), pct03)
	changeDistributionPct(emissionTarget(target04), pct04)
}

// distributeToTarget distributes the specified amount to different targets based on their percentages.
// TOCO:
// 1. should return amount of sent GNS for distribution
func distributeToTarget(amount uint64) uint64 {
	totalSent := uint64(0)
	for target, pct := range distributionPct {
		distAmount := calculateAmount(amount, pct)
		totalSent += distAmount

		transferToTarget(target, distAmount)
	}

	// TODO:
	// 1. Check amount - totalSent is 0
	// 2. if not 0, save it to leftGNSAmount and distribute it next time
	// 3. this job is processed in emission.gno
	return totalSent
	// `amount-totalSent` can be left due to rounding
	// it will be distributed next time
}

// calculateAmount calculates the amount based on the given percentage in basis points.
func calculateAmount(amount, bptPct uint64) uint64 {
	return amount * bptPct / 10000
}

// transferToTarget transfers the specified amount to the given addresses.
func transferToTarget(target emissionTarget, amount uint64) {
	// TODO:
	// 1. add more clear name from LIQUIDITY_STAKING to LIQUIDITY_STAKER
	switch target {
	case LIQUIDITY_STAKER:
		// transfer to staker contract
		gns.Transfer(a2u(consts.STAKER_ADDR), amount)
		toStaker = amount
		toStakerAccu += amount
	case DEVOPS:
		// transfer to devops
		gns.Transfer(a2u(consts.DEV_OPS), amount)
		toDevOps = amount
		toDevOpsAccu += amount
	case COMMUNITY_POOL:
		gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), amount)
		toCommunityPool = amount
		toCommunityPoolAccu += amount
	case GOV_STAKER:
		gns.Transfer(a2u(consts.GOV_STAKER_ADDR), amount)
		toGovStaker = amount
		toGovStakerAccu += amount
	default:
		panic(addDetailToError(
			errInvalidEmissionTarget,
			ufmt.Sprintf("emission.gno__transferToTarget() || invalid target(%d)", target),
		))
	}
}

// changeDistributionPct changes the distribution percentage for the given target.
func changeDistributionPct(target emissionTarget, pct uint64) {
	// cannot add new target
	// TODO:
	// 1. add more clear name from LIQUIDITY_STAKING to LIQUIDITY_STAKER
	if target != LIQUIDITY_STAKER && target != DEVOPS && target != COMMUNITY_POOL && target != GOV_STAKER {
		panic(addDetailToError(
			errInvalidEmissionTarget,
			ufmt.Sprintf("emission.gno__changeDistributionPct() || invalid target(%d)", target),
		))
	}

	distributionPct[target] = pct
}

// checkSumDistributionPct ensures the sum of all distribution percentages is 100%
func checkSumDistributionPct(pct01, pct02, pct03, pct04 uint64) {
	sum := pct01 + pct02 + pct03 + pct04

	if sum != 10000 {
		panic(addDetailToError(
			errInvalidEmissionPct,
			ufmt.Sprintf("sum of all pct should be 100%% (10000 bps), got %d", sum),
		))
	}
}

func GetAccuDistributedAmount() (uint64, uint64, uint64, uint64) {
	return toStakerAccu, toDevOpsAccu, toCommunityPoolAccu, toGovStakerAccu
}

func ClearAccuDistributedAmount() {
	common.IsHalted()

	prevAddr := std.PrevRealm().Addr()

	if !(prevAddr == consts.STAKER_ADDR || prevAddr == consts.GOV_STAKER_ADDR) {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only staker(%s) or gov/staker(%s) can clear accumulated distributed amount, called from %s",
				consts.STAKER_ADDR, consts.GOV_STAKER_ADDR, prevAddr.String(),
			),
		))
	}

	toStakerAccu = 0
	toDevOpsAccu = 0
	toCommunityPoolAccu = 0
	toGovStakerAccu = 0
}

func GetAccuDistributedAmountForGovStaker() uint64 {
	return toGovStakerAccu
}

func ClearAccuDistributedAmountForGovStaker() {
	common.IsHalted()

	prevAddr := std.PrevRealm().Addr()
	if prevAddr != consts.GOV_STAKER_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only gov/staker(%s) can clear accumulated distributed amount, called from %s",
				consts.GOV_STAKER_ADDR, prevAddr.String(),
			),
		))
	}

	toGovStakerAccu = 0
}

func GetAccuDistributedAmountForStaker() uint64 {
	return toStakerAccu
}

func ClearAccuDistributedAmountForStaker() {
	common.IsHalted()

	prevAddr := std.PrevRealm().Addr()
	if prevAddr != consts.STAKER_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only staker(%s) can clear accumulated distributed amount, called from %s",
				consts.STAKER_ADDR, prevAddr.String(),
			),
		))
	}

	toStakerAccu = 0
}

func GetLastDistributedGNSAmount() (uint64, uint64, uint64, uint64) {
	return toStaker, toDevOps, toCommunityPool, toGovStaker
}
