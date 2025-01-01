package emission

import (
	"std"
	"strconv"

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

var (
	// Stores the percentage (in basis points) for each distribution target
	// 1 basis point = 0.01%
	distributionBpsPct *avl.Tree

	distributedToStaker        uint64 // can be cleared by staker contract
	distributedToDevOps        uint64
	distributedToCommunityPool uint64
	distributedToGovStaker     uint64 // can be cleared by governance staker

	// Historical total distributions (never reset)
	accuDistributedToStaker        uint64
	accuDistributedToDevOps        uint64
	accuDistributedToCommunityPool uint64
	accuDistributedToGovStaker     uint64
)

// Initialize default distribution percentages:
// - Liquidity Stakers: 75%
// - DevOps: 20%
// - Community Pool: 5%
// - Governance Stakers: 0%
func init() {
	distributionBpsPct = avl.NewTree()
	distributionBpsPct.Set(strconv.Itoa(LIQUIDITY_STAKER), 7500)
	distributionBpsPct.Set(strconv.Itoa(DEVOPS), 2000)
	distributionBpsPct.Set(strconv.Itoa(COMMUNITY_POOL), 500)
	distributionBpsPct.Set(strconv.Itoa(GOV_STAKER), 0)
}

// ChangeDistributionPctByAdmin changes the distribution percentage for the given targets.
// Panics if following conditions are not met:
// - caller is not admin
// - invalid target
// - sum of percentages is not 10000
// - swap is halted
func ChangeDistributionPctByAdmin(
	target01 int, pct01 uint64,
	target02 int, pct02 uint64,
	target03 int, pct03 uint64,
	target04 int, pct04 uint64,
) {
	assertOnlyAdmin()
	assertDistributionTarget(target01)
	assertDistributionTarget(target02)
	assertDistributionTarget(target03)
	assertDistributionTarget(target04)
	assertSumDistributionPct(pct01, pct02, pct03, pct04)
	assertOnlyNotHalted()

	changeDistributionPcts(
		target01, pct01,
		target02, pct02,
		target03, pct03,
		target04, pct04,
	)
}

// ChangeDistributionPct changes the distribution percentage for the given targets.
// Panics if following conditions are not met:
// - caller is not governance
// - invalid target
// - sum of percentages is not 10000
// - swap is halted
func ChangeDistributionPct(
	target01 int, pct01 uint64,
	target02 int, pct02 uint64,
	target03 int, pct03 uint64,
	target04 int, pct04 uint64,
) {
	assertOnlyGovernance()
	assertDistributionTarget(target01)
	assertDistributionTarget(target02)
	assertDistributionTarget(target03)
	assertDistributionTarget(target04)
	assertSumDistributionPct(pct01, pct02, pct03, pct04)
	assertOnlyNotHalted()

	changeDistributionPcts(
		target01, pct01,
		target02, pct02,
		target03, pct03,
		target04, pct04,
	)
}

func changeDistributionPcts(
	target01 int, pct01 uint64,
	target02 int, pct02 uint64,
	target03 int, pct03 uint64,
	target04 int, pct04 uint64,
) {
	setDistributionBpsPct(target01, pct01)
	setDistributionBpsPct(target02, pct02)
	setDistributionBpsPct(target03, pct03)
	setDistributionBpsPct(target04, pct04)

	prevAddr, prevPkgPath := getPrevAsString()
	std.Emit(
		"ChangeDistributionPct",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"target01", strconv.Itoa(target01),
		"pct01", strconv.FormatUint(pct01, 10),
		"target02", strconv.Itoa(target02),
		"pct02", strconv.FormatUint(pct02, 10),
		"target03", strconv.Itoa(target03),
		"pct03", strconv.FormatUint(pct03, 10),
		"target04", strconv.Itoa(target04),
		"pct04", strconv.FormatUint(pct04, 10),
	)
}

// distributeToTarget splits an amount according to the configured percentages
// and sends tokens to each target address. Returns the total amount distributed.
func distributeToTarget(amount uint64) uint64 {
	totalSent := uint64(0)

	distributionBpsPct.Iterate("", "", func(targetStr string, iPct interface{}) bool {
		targetInt, err := strconv.Atoi(targetStr)
		if err != nil {
			panic(addDetailToError(
				errInvalidEmissionTarget,
				ufmt.Sprintf("invalid target(%s)", targetStr),
			))
		}

		pct := uint64(iPct)
		distAmount := calculateAmount(amount, pct)
		totalSent += distAmount

		transferToTarget(targetInt, distAmount)

		return false
	})

	leftAmount := amount - totalSent
	if leftGNSAmount > 0 {
		setLeftGNSAmount(leftAmount)
	}

	return totalSent
}

// calculateAmount converts a basis point percentage to actual token amount
// bptPct is in basis points (1/100th of 1%)
// Example: 7500 basis points = 75%
func calculateAmount(amount, bptPct uint64) uint64 {
	return amount * bptPct / 10000
}

// transferToTarget sends tokens to the appropriate address based on target type
// and updates both current and accumulated distribution tracking
func transferToTarget(target int, amount uint64) {
	switch target {
	case LIQUIDITY_STAKER:
		gns.Transfer(a2u(consts.STAKER_ADDR), amount)
		distributedToStaker += amount
		accuDistributedToStaker += amount

	case DEVOPS:
		gns.Transfer(a2u(consts.DEV_OPS), amount)
		distributedToDevOps += amount
		accuDistributedToDevOps += amount

	case COMMUNITY_POOL:
		gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), amount)
		distributedToCommunityPool += amount
		accuDistributedToCommunityPool += amount

	case GOV_STAKER:
		gns.Transfer(a2u(consts.GOV_STAKER_ADDR), amount)
		distributedToGovStaker += amount
		accuDistributedToGovStaker += amount

	default:
		panic(addDetailToError(
			errInvalidEmissionTarget,
			ufmt.Sprintf("invalid target(%d)", target),
		))
	}
}

func GetDistributionBpsPct(target int) uint64 {
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

func GetDistributedToStaker() uint64 {
	return distributedToStaker
}

func GetDistributedToDevOps() uint64 {
	return distributedToDevOps
}

func GetDistributedToCommunityPool() uint64 {
	return distributedToCommunityPool
}

func GetDistributedToGovStaker() uint64 {
	return distributedToGovStaker
}

func GetAccuDistributedToStaker() uint64 {
	return accuDistributedToStaker
}

func GetAccuDistributedToDevOps() uint64 {
	return accuDistributedToDevOps
}

func GetAccuDistributedToCommunityPool() uint64 {
	return accuDistributedToCommunityPool
}

func GetAccuDistributedToGovStaker() uint64 {
	return accuDistributedToGovStaker
}

func ClearDistributedToStaker() {
	assertStakerOnly()
	distributedToStaker = 0
}

func ClearDistributedToGovStaker() {
	assertOnlyGovStaker()
	distributedToGovStaker = 0
}

func setDistributionBpsPct(target int, pct uint64) {
	distributionBpsPct.Set(strconv.Itoa(target), pct)
}
