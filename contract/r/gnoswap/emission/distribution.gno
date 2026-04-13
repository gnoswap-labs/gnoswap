package emission

import (
	"chain"
	"chain/runtime"
	"time"

	ufmt "gno.land/p/nt/ufmt/v0"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
)

const (
	_ int = iota
	LIQUIDITY_STAKER
	DEVOPS
	COMMUNITY_POOL
	GOV_STAKER
)

var (
	// Stores the percentage (in basis points) for each distribution target
	// 1 basis point = 0.01%
	// These percentages can be modified through governance.
	distributionBpsPct map[int]int64

	distributedToStaker        int64 // can be cleared by staker contract
	distributedToDevOps        int64
	distributedToCommunityPool int64
	distributedToGovStaker     int64 // can be cleared by governance staker

	// Historical total distributions (never reset)
	accuDistributedToStaker        int64
	accuDistributedToDevOps        int64
	accuDistributedToCommunityPool int64
	accuDistributedToGovStaker     int64
)

// Initialize default distribution percentages:
// - Liquidity Stakers: 75%
// - DevOps: 20%
// - Community Pool: 5%
// - Governance Stakers: 0%
//
// ref: https://docs.gnoswap.io/gnoswap-token/emission
func init() {
	distributionBpsPct = map[int]int64{
		LIQUIDITY_STAKER: 7500,
		DEVOPS:           2000,
		COMMUNITY_POOL:   500,
		GOV_STAKER:       0,
	}
}

// ChangeDistributionPct changes distribution percentages for emission targets.
//
// This function redistributes how newly minted GNS tokens are allocated across
// protocol components. Before applying new ratios, it distributes any accumulated
// emissions using the current ratios, ensuring emissions are distributed according
// to the ratios in effect when they were generated. This prevents retroactive
// application of new ratios to past emissions.
//
// Parameters:
//   - liquidityStakerPct: Percentage for liquidity stakers in basis points (100 = 1%, 10000 = 100%)
//   - devOpsPct: Percentage for devops in basis points
//   - communityPoolPct: Percentage for community pool in basis points
//   - govStakerPct: Percentage for governance stakers in basis points
//
// Requirements:
//   - Percentages must sum to exactly 10000 (100%)
//   - Each percentage must be 0-10000
//
// Example:
//
//	ChangeDistributionPct(
//	  7000,  // 70% to liquidity stakers
//	  2000,  // 20% to devops
//	  1000,  // 10% to community pool
//	  0,     // 0% to governance stakers
//	)
//
// Only callable by admin or governance.
func ChangeDistributionPct(
	cur realm,
	liquidityStakerPct int64,
	devOpsPct int64,
	communityPoolPct int64,
	govStakerPct int64,
) {
	halt.AssertIsNotHaltedEmission()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertValidDistributionPct(liquidityStakerPct, devOpsPct, communityPoolPct, govStakerPct)

	// Distribute accumulated emissions with current ratios before changing ratios.
	// This prevents retroactive application of new ratios to emissions that occurred
	// under previous ratio configurations.
	MintAndDistributeGns(cross)

	if onDistributionPctChangeCallback != nil {
		currentTimestamp := time.Now().Unix()
		emissionAmountPerSecond := GetEmissionAmountPerSecondBy(currentTimestamp, liquidityStakerPct)
		onDistributionPctChangeCallback(emissionAmountPerSecond)
	}

	changeDistributionPcts(liquidityStakerPct, devOpsPct, communityPoolPct, govStakerPct)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"ChangeDistributionPct",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"liquidityStakerPct", formatInt(liquidityStakerPct),
		"devOpsPct", formatInt(devOpsPct),
		"communityPoolPct", formatInt(communityPoolPct),
		"govStakerPct", formatInt(govStakerPct),
	)
}

// changeDistributionPcts updates the distribution percentages for all targets.
func changeDistributionPcts(liquidityStakerPct, devOpsPct, communityPoolPct, govStakerPct int64) {
	setDistributionBpsPct(LIQUIDITY_STAKER, liquidityStakerPct)
	setDistributionBpsPct(DEVOPS, devOpsPct)
	setDistributionBpsPct(COMMUNITY_POOL, communityPoolPct)
	setDistributionBpsPct(GOV_STAKER, govStakerPct)
}

func calculateDistributableAmounts(amount int64) (map[int]int64, int64) {
	distributable := make(map[int]int64, 0)
	totalSent := int64(0)

	for target, pct := range distributionBpsPct {
		distAmount := calculateAmount(amount, pct)
		if distAmount == 0 {
			continue
		}

		distributable[target] = distAmount
		totalSent = gnsmath.SafeAddInt64(totalSent, distAmount)
	}

	leftAmount := gnsmath.SafeSubInt64(amount, totalSent)
	return distributable, leftAmount
}

// calculateAmount converts basis points to actual token amount.
func calculateAmount(amount, bptPct int64) int64 {
	if amount < 0 || bptPct < 0 || bptPct > 10000 {
		panic("invalid amount or bptPct")
	}

	// More precise overflow prevention
	const maxInt64 = 9223372036854775807
	if amount > maxInt64/10000 {
		panic("amount too large, would cause overflow")
	}

	// Additional safety check for zero division
	if bptPct == 0 {
		return 0
	}

	return amount * bptPct / 10000
}

func applyDistribution(targets map[int]int64) (map[address]int64, error) {
	amountByAddress := make(map[address]int64, 0)

	for target, amount := range targets {
		var addr address

		switch target {
		case LIQUIDITY_STAKER:
			distributedToStaker = gnsmath.SafeAddInt64(distributedToStaker, amount)
			accuDistributedToStaker = gnsmath.SafeAddInt64(accuDistributedToStaker, amount)
			addr = access.MustGetAddress(prbac.ROLE_STAKER.String())

		case DEVOPS:
			distributedToDevOps = gnsmath.SafeAddInt64(distributedToDevOps, amount)
			accuDistributedToDevOps = gnsmath.SafeAddInt64(accuDistributedToDevOps, amount)
			addr = access.MustGetAddress(prbac.ROLE_DEVOPS.String())

		case COMMUNITY_POOL:
			distributedToCommunityPool = gnsmath.SafeAddInt64(distributedToCommunityPool, amount)
			accuDistributedToCommunityPool = gnsmath.SafeAddInt64(accuDistributedToCommunityPool, amount)
			addr = access.MustGetAddress(prbac.ROLE_COMMUNITY_POOL.String())

		case GOV_STAKER:
			distributedToGovStaker = gnsmath.SafeAddInt64(distributedToGovStaker, amount)
			accuDistributedToGovStaker = gnsmath.SafeAddInt64(accuDistributedToGovStaker, amount)
			addr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

		default:
			return nil, makeErrorWithDetails(
				errInvalidEmissionTarget,
				ufmt.Sprintf("invalid target(%d)", target),
			)
		}

		amountByAddress[addr] = gnsmath.SafeAddInt64(amountByAddress[addr], amount)
	}

	return amountByAddress, nil
}

func transferToTarget(targets map[address]int64) error {
	for address, amount := range targets {
		gns.Transfer(cross, address, amount)
	}

	return nil
}

// GetDistributionBpsPct returns the distribution percentage in basis points for a specific target.
func GetDistributionBpsPct(target int) int64 {
	assertValidDistributionTarget(target)
	if distributionBpsPct == nil {
		panic("distributionBpsPct is nil")
	}

	pct, exist := distributionBpsPct[target]
	if !exist {
		panic(makeErrorWithDetails(
			errInvalidEmissionTarget,
			ufmt.Sprintf("invalid target(%d)", target),
		))
	}

	return pct
}

// GetDistributedToStaker returns pending GNS for liquidity stakers.
func GetDistributedToStaker() int64 {
	return distributedToStaker
}

// GetDistributedToDevOps returns accumulated GNS for DevOps.
func GetDistributedToDevOps() int64 {
	return distributedToDevOps
}

// GetDistributedToCommunityPool returns the amount of GNS distributed to Community Pool.
func GetDistributedToCommunityPool() int64 {
	return distributedToCommunityPool
}

// GetDistributedToGovStaker returns the amount of GNS distributed to governance stakers since last clear.
func GetDistributedToGovStaker() int64 {
	return distributedToGovStaker
}

func AccumulateDistributedInfo() (toStaker, toDevOps, toCommunityPool, toGovStaker int64) {
	toStaker = GetDistributedToStaker()
	toDevOps = GetDistributedToDevOps()
	toCommunityPool = GetDistributedToCommunityPool()
	toGovStaker = GetDistributedToGovStaker()
	return
}

// GetAccuDistributedToStaker returns the total historical GNS distributed to liquidity stakers.
func GetAccuDistributedToStaker() int64 {
	return accuDistributedToStaker
}

// GetAccuDistributedToDevOps returns the total historical GNS distributed to DevOps.
func GetAccuDistributedToDevOps() int64 {
	return accuDistributedToDevOps
}

// GetAccuDistributedToCommunityPool returns the total historical GNS distributed to Community Pool.
func GetAccuDistributedToCommunityPool() int64 {
	return accuDistributedToCommunityPool
}

// GetAccuDistributedToGovStaker returns the total historical GNS distributed to governance stakers.
func GetAccuDistributedToGovStaker() int64 {
	return accuDistributedToGovStaker
}

// GetEmissionAmountPerSecondBy returns the emission amount per second for a given timestamp and distribution percentage.
func GetEmissionAmountPerSecondBy(timestamp, distributionPct int64) int64 {
	return calculateAmount(gns.GetEmissionAmountPerSecondByTimestamp(timestamp), distributionPct)
}

// GetStakerEmissionAmountPerSecond returns the current per-second emission amount allocated to liquidity stakers.
func GetStakerEmissionAmountPerSecond() int64 {
	currentTimestamp := time.Now().Unix()
	return GetEmissionAmountPerSecondBy(currentTimestamp, GetDistributionBpsPct(LIQUIDITY_STAKER))
}

// GetStakerEmissionAmountPerSecondInRange returns emission amounts allocated to liquidity stakers for a time range.
func GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64) {
	halvingBlocks, halvingEmissions := gns.GetEmissionAmountPerSecondInRange(start, end)
	for i := range halvingBlocks {
		// Applying staker ratio for past halving blocks
		halvingEmissions[i] = calculateAmount(halvingEmissions[i], GetDistributionBpsPct(LIQUIDITY_STAKER))
	}

	return halvingBlocks, halvingEmissions
}

// ClearDistributedToStaker resets the pending distribution amount for liquidity stakers.
//
// Only callable by staker contract.
func ClearDistributedToStaker(cur realm) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsStaker(caller)

	distributedToStaker = 0
}

// ClearDistributedToGovStaker resets the pending distribution amount for governance stakers.
//
// Only callable by governance staker contract.
func ClearDistributedToGovStaker(cur realm) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)
	distributedToGovStaker = 0
}

// setDistributionBpsPct changes percentage of each target for how much GNS it will get by emission.
// Creates new AVL tree if nil.
func setDistributionBpsPct(target int, pct int64) {
	if distributionBpsPct == nil {
		distributionBpsPct = make(map[int]int64)
	}

	distributionBpsPct[target] = pct
}

// targetToStr converts target constant to string representation.
func targetToStr(target int) string {
	switch target {
	case LIQUIDITY_STAKER:
		return "LIQUIDITY_STAKER"
	case DEVOPS:
		return "DEVOPS"
	case COMMUNITY_POOL:
		return "COMMUNITY_POOL"
	case GOV_STAKER:
		return "GOV_STAKER"
	default:
		return "UNKNOWN"
	}
}
