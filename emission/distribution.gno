package emission

import (
	"std"
	"strconv"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

const (
	LIQUIDITY_STAKER int = iota + 1
	DEVOPS
	COMMUNITY_POOL
	GOV_STAKER
)

var distributionBpsPct *avl.Tree

func init() {
	distributionBpsPct = avl.NewTree()
	distributionBpsPct.Set(strconv.Itoa(LIQUIDITY_STAKER), 7500)
	distributionBpsPct.Set(strconv.Itoa(DEVOPS), 2000)
	distributionBpsPct.Set(strconv.Itoa(COMMUNITY_POOL), 500)
	distributionBpsPct.Set(strconv.Itoa(GOV_STAKER), 0)
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

// ChangeDistributionPctByAdmin changes the distribution percentage for the given targets.
// Panics if the caller is not the admin.
func ChangeDistributionPctByAdmin(
	target01 int, pct01 uint64,
	target02 int, pct02 uint64,
	target03 int, pct03 uint64,
	target04 int, pct04 uint64,
) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
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

	assertDistributionTarget(target01)
	assertDistributionTarget(target02)
	assertDistributionTarget(target03)
	assertDistributionTarget(target04)

	checkSumDistributionPct(pct01, pct02, pct03, pct04)

	setDistributionPct(target01, pct01)
	setDistributionPct(target02, pct02)
	setDistributionPct(target03, pct03)
	setDistributionPct(target04, pct04)
}

// distributeToTarget distributes the specified amount to different targets based on their percentages.
func distributeToTarget(amount uint64) uint64 {
	totalSent := uint64(0)

	distributionBpsPct.Iterate("", "", func(targetStr string, iPct interface{}) bool {
		targetInt, err := strconv.Atoi(targetStr)
		if err != nil {
			panic(addDetailToError(
				errInvalidEmissionTarget,
				ufmt.Sprintf("emission.gno__distributeToTarget() || invalid target(%s)", targetStr),
			))
		}

		pct := uint64(iPct)
		distAmount := calculateAmount(amount, pct)
		totalSent += distAmount

		transferToTarget(targetInt, distAmount)
	})

	leftGNSAmount := amount - totalSent
	if leftGNSAmount > 0 {
		setLeftGNSAmount(leftGNSAmount)
	}

	return totalSent
}

// calculateAmount calculates the amount based on the given percentage in basis points.
func calculateAmount(amount, bptPct uint64) uint64 {
	return amount * bptPct / 10000
}

// transferToTarget transfers the specified amount to the given addresses.
func transferToTarget(target int, amount uint64) {
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
func changeDistributionPct(target int, pct uint64) {
	assertDistributionTarget(target)

	setDistributionPct(target, pct)
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

/*

var distributionBpsPct *avl.Tree

func init() {
	distributionBpsPct = avl.NewTree()
	distributionBpsPct.Set(strconv.Itoa(LIQUIDITY_STAKER), 7500)
	distributionBpsPct.Set(strconv.Itoa(DEVOPS), 2000)
	distributionBpsPct.Set(strconv.Itoa(COMMUNITY_POOL), 500)
	distributionBpsPct.Set(strconv.Itoa(GOV_STAKER), 0)
}

*/

func GetDistributionPct(target int) uint64 {
	assertDistributionTarget(target)
	iUint64, exist := distributionBpsPct.Get(strconv.Itoa(target))
	if !exist {
		panic(addDetailToError(
			errInvalidEmissionTarget,
			ufmt.Sprintf("invalid target(%d)", target),
		))
	}

	return uint64(iUint64)
}

func setDistributionPct(target int, pct uint64) {
	distributionBpsPct.Set(strconv.Itoa(target), pct)
}

func assertDistributionTarget(target int) {
	if target != LIQUIDITY_STAKER && target != DEVOPS && target != COMMUNITY_POOL && target != GOV_STAKER {
		panic(addDetailToError(
			errInvalidEmissionTarget,
			ufmt.Sprintf("invalid target(%d)", target),
		))
	}
}
