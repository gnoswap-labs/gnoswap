package emission

import (
	"std"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"

	"gno.land/p/demo/ufmt"
)

// emissionTarget represents different targets for token emission.
type emissionTarget int

// distributionPctMap maps emission targets to their respective distribution percentages.
type distributionPctMap map[emissionTarget]uint64

const (
	LIQUIDITY_STAKING emissionTarget = iota + 1
	DEVOPS
	COMMUNITY_POOL
	GOV_STAKER
)

// distributionPct defines the distribution percentages.
var distributionPct distributionPctMap = distributionPctMap{
	LIQUIDITY_STAKING: 7500, // 75%
	DEVOPS:            2000, // 20%
	COMMUNITY_POOL:    500,  // 5%
	GOV_STAKER:        0,    // 0%
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
		panic("only admin can change distribution percentages")
	}

	changeDistributionPcts(
		target01, pct01,
		target02, pct02,
		target03, pct03,
		target04, pct04,
	)

	checkSumDistributionPct()

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
		panic("only governance can change distribution percentages")
	}

	changeDistributionPcts(
		target01, pct01,
		target02, pct02,
		target03, pct03,
		target04, pct04,
	)

	checkSumDistributionPct()

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

	changeDistributionPct(emissionTarget(target01), pct01)
	changeDistributionPct(emissionTarget(target02), pct02)
	changeDistributionPct(emissionTarget(target03), pct03)
	changeDistributionPct(emissionTarget(target04), pct04)

	checkSumDistributionPct()
}

// distributeToTarget distributes the specified amount to different targets based on their percentages.
func distributeToTarget(amount uint64) {
	totalSent := uint64(0)
	for target, pct := range distributionPct {
		distAmount := calculateAmount(amount, pct)
		totalSent += distAmount

		transferToTarget(target, distAmount)
	}

	// `amount-totalSent` can be left due to rounding
	// it will be distributed next time
}

// calculateAmount calculates the amount based on the given percentage in basis points.
func calculateAmount(amount, bptPct uint64) uint64 {
	return amount * bptPct / 10000
}

// transferToTarget transfers the specified amount to the given addresses.
func transferToTarget(target emissionTarget, amount uint64) {
	switch target {
	case LIQUIDITY_STAKING:
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
		panic("invalid target")
	}
}

// changeDistributionPct changes the distribution percentage for the given target.
func changeDistributionPct(target emissionTarget, pct uint64) {
	// cannot add new target
	if target != LIQUIDITY_STAKING && target != DEVOPS && target != COMMUNITY_POOL && target != GOV_STAKER {
		panic("invalid target")
	}

	// Maximum pct for a single target is 10000 basis points (100%)
	if pct > 10000 {
		panic("percentage too high")
	}

	distributionPct[target] = pct
}

// checkSumDistributionPct ensures the sum of all distribution percentages is 100%
func checkSumDistributionPct() {
	sum := uint64(0)
	for _, pct := range distributionPct {
		sum += pct
	}

	if sum != 10000 {
		panic(ufmt.Sprintf("sum of all pct should be 100%% (10000 bps), got %d\n", sum))
	}
}

func GetLastDistributedAmount() (int64, uint64, uint64, uint64, uint64, uint64, uint64) {
	return lastExecutedHeight, lastStakerGnsBalance, emissionGnsBalance, toStaker, toDevOps, toCommunityPool, toGovStaker
}

func GetAccuDistributedAmount() (uint64, uint64, uint64, uint64) {
	return toStakerAccu, toDevOpsAccu, toCommunityPoolAccu, toGovStakerAccu
}

func ClearAccuDistributedAmount() {
	common.IsHalted()

	prevRealm := std.PrevRealm().PkgPath()

	if !(prevRealm == consts.STAKER_PATH && prevRealm == consts.GOV_STAKER_PATH) {
		panic("only staker or gov staker can clear accumulated distributed amount")
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

	prevRealm := std.PrevRealm().PkgPath()

	if prevRealm != consts.GOV_STAKER_PATH {
		panic("only gov staker can clear accumulated distributed amount")
	}

	toGovStakerAccu = 0
}

func GetLastDistributeToStaker() uint64 {
	return toStaker
}

func GetLastDistributeToGovStaker() uint64 {
	return toGovStaker
}
