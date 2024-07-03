package emission

import (
	"std"

	"gno.land/r/demo/gnoswap/consts"
	"gno.land/r/demo/gns"

	"gno.land/p/demo/ufmt"
)

type emissionTarget int

const (
	LIQUIDITY_STAKING emissionTarget = iota + 1
	DEVOPS
	COMMUNITY_POOL
	XGNS
)

// BasisPoint
// 1 = 0.01%
// 10 = 0.1%
// 100 = 1%
// 1000 = 10%
// 10000 = 100%
type distributionPctMap map[emissionTarget]uint64

var distributionPct distributionPctMap = distributionPctMap{
	LIQUIDITY_STAKING: 7500, // / 10000 = 75%
	DEVOPS:            2000,
	COMMUNITY_POOL:    500,
	XGNS:              0,
}

func DistributeToTarget(amount uint64) {
	totalSent := uint64(0)
	for target, pct := range distributionPct {
		distAmount := getAmount(amount, pct)
		totalSent += distAmount

		transferToTarget(target, distAmount)
	}

	// `amount-totalSent` can be left due to rounding
	// it will be distributed next time
}

func getAmount(amount, bptPct uint64) uint64 {
	return amount * bptPct / 10000
}

func transferToTarget(target emissionTarget, amount uint64) {
	switch target {
	case LIQUIDITY_STAKING:
		// transfer to staker contract
		gns.Transfer(a2u(consts.STAKER_ADDR), amount)
	case DEVOPS:
		// transfer to devops
		gns.Transfer(a2u(consts.DEV_OPS), amount)
	case COMMUNITY_POOL:
		// TBD, transfer to community pool
		gns.Transfer(a2u(consts.ZERO_ADDRESS), amount)
	case XGNS:
		// TBD, transfer to xGNS
		gns.Transfer(a2u(consts.ZERO_ADDRESS), amount)
	default:
		panic("invalid target")
	}
}

// GETTER
func GetDistributionPct(target emissionTarget) uint64 {
	return distributionPct[target]
}

// SETTER
func ChangeDistributionPct01(target01 emissionTarget, pct01 uint64) {
	changeDistributionPct(target01, pct01)

	checkSumDistributionPct()
}

func ChangeDistributionPct02(
	target01 emissionTarget, pct01 uint64,
	target02 emissionTarget, pct02 uint64,
) {
	changeDistributionPct(target01, pct01)
	changeDistributionPct(target02, pct02)

	checkSumDistributionPct()
}

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

func changeDistributionPct(target emissionTarget, pct uint64) {
	// only admin or governance can change
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic("only admin or governance can change")
	}

	// cannot add new target
	if target != LIQUIDITY_STAKING && target != DEVOPS && target != COMMUNITY_POOL && target != XGNS {
		panic("invalid target")
	}

	// maximum pct for single target is 100% (10000 bps)
	if pct > 10000 {
		panic("too many pct")
	}

	distributionPct[target] = pct
}

// after changing distribution pct, check if sum of all pct is 100% (10000 bps)
func checkSumDistributionPct() {
	sum := uint64(0)
	for _, pct := range distributionPct {
		sum += pct
	}

	if sum != 10000 {
		panic(ufmt.Sprintf("sum of all pct should be 100%% (10000 bps), got %d\n", sum))
	}
}
