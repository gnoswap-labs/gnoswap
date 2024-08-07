package emission

import (
	"std"

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
	XGNS
)

// distributionPct defines the distribution percentages.
var distributionPct distributionPctMap = distributionPctMap{
	LIQUIDITY_STAKING: 7500, // 75%
	DEVOPS:            2000, // 20%
	COMMUNITY_POOL:    500,  // 5%
	XGNS:              0,    // 0%
}

var (
	toStaker        uint64
	toDevOps        uint64
	toCommunityPool uint64
	toXGNS          uint64

	toStakerAccu        uint64
	toDevOpsAccu        uint64
	toCommunityPoolAccu uint64
	toXGNSAccu          uint64
)

// GetDistributionPct returns the distribution percentage for the given target.
func GetDistributionPct(target emissionTarget) uint64 {
	return distributionPct[target]
}

// ChangeDistributionPct01 changes the distribution percentage for the given single target.
func ChangeDistributionPct01(target01 emissionTarget, pct01 uint64) {
	changeDistributionPct(target01, pct01)

	checkSumDistributionPct()
}

// ChangeDistributionPct02 changes the distribution percentage for the given two targets.
func ChangeDistributionPct02(
	target01 emissionTarget, pct01 uint64,
	target02 emissionTarget, pct02 uint64,
) {
	changeDistributionPct(target01, pct01)
	changeDistributionPct(target02, pct02)

	checkSumDistributionPct()
}

// ChangeDistributionPct03 changes the distribution percentage for the given three targets.
func ChangeDistributionPct03(
	target01 emissionTarget, pct01 uint64,
	target02 emissionTarget, pct02 uint64,
	target03 emissionTarget, pct03 uint64,
) {
	changeDistributionPct(target01, pct01)
	changeDistributionPct(target02, pct02)
	changeDistributionPct(target03, pct03)

	checkSumDistributionPct()
}

// ChangeDistributionPct04 changes the distribution percentage for the given four targets.
func ChangeDistributionPct04(
	target01 emissionTarget, pct01 uint64,
	target02 emissionTarget, pct02 uint64,
	target03 emissionTarget, pct03 uint64,
	target04 emissionTarget, pct04 uint64,
) {
	changeDistributionPct(target01, pct01)
	changeDistributionPct(target02, pct02)
	changeDistributionPct(target03, pct03)
	changeDistributionPct(target04, pct04)

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
	case XGNS:
		gns.Transfer(a2u(consts.X_GNS_ADDR), amount)
		toXGNS = amount
		toXGNSAccu += amount
	default:
		panic("invalid target")
	}
}

// changeDistributionPct changes the distribution percentage for the given target.
func changeDistributionPct(target emissionTarget, pct uint64) {
	// only admin or governance can change
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic("only admin or governance can change distribution percentages")
	}

	// cannot add new target
	if target != LIQUIDITY_STAKING && target != DEVOPS && target != COMMUNITY_POOL && target != XGNS {
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
	return lastExecutedHeight, lastStakerGnsBalance, emissionGnsBalance, toStaker, toDevOps, toCommunityPool, toXGNS
}

func GetAccuDistributedAmount() (uint64, uint64, uint64, uint64) {
	return toStaker, toDevOps, toCommunityPool, toXGNS
}

func GetLastDistributeToStaker() uint64 {
	return toStaker
}
