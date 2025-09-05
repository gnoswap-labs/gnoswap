package emission

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
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
	// These percentages can be modified through governance.
	distributionBpsPct *avl.Tree

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
	distributionBpsPct = avl.NewTree()
	distributionBpsPct.Set(strconv.Itoa(LIQUIDITY_STAKER), int64(7500))
	distributionBpsPct.Set(strconv.Itoa(DEVOPS), int64(2000))
	distributionBpsPct.Set(strconv.Itoa(COMMUNITY_POOL), int64(500))
	distributionBpsPct.Set(strconv.Itoa(GOV_STAKER), int64(0))
}

// ChangeDistributionPct changes distribution percentages for emission targets.
//
// This function redistributes how newly minted GNS tokens are allocated across
// protocol components. Changes take effect immediately for future emissions.
// Historical distributions are not affected.
//
// Parameters:
//   - target01-04: Target identifiers (1=LIQUIDITY_STAKER, 2=DEVOPS, 3=COMMUNITY_POOL, 4=GOV_STAKER)
//   - pct01-04: Percentage in basis points (100 = 1%, 10000 = 100%)
//
// Requirements:
//   - All four targets must be specified (use current values if unchanged)
//   - Percentages must sum to exactly 10000 (100%)
//   - Each percentage must be 0-10000
//   - Targets must be unique (no duplicates)
//
// Example:
//
//	ChangeDistributionPct(
//	  1, 7000,  // 70% to liquidity stakers
//	  2, 2000,  // 20% to devops
//	  3, 1000,  // 10% to community pool
//	  4, 0      // 0% to governance stakers
//	)
//
// Only callable by admin or governance.
func ChangeDistributionPct(
	cur realm,
	target01 int, pct01 int64,
	target02 int, pct02 int64,
	target03 int, pct03 int64,
	target04 int, pct04 int64,
) {
	halt.AssertIsNotHaltedEmission()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertValidDistributionTargets(target01, target02, target03, target04)
	assertValidDistributionPct(pct01, pct02, pct03, pct04)

	changeDistributionPcts(
		target01, pct01,
		target02, pct02,
		target03, pct03,
		target04, pct04,
	)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"ChangeDistributionPct",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"target01", targetToStr(target01),
		"pct01", formatInt(pct01),
		"target02", targetToStr(target02),
		"pct02", formatInt(pct02),
		"target03", targetToStr(target03),
		"pct03", formatInt(pct03),
		"target04", targetToStr(target04),
		"pct04", formatInt(pct04),
	)
}

// changeDistributionPcts updates the distribution percentages in the AVL tree.
func changeDistributionPcts(
	target01 int, pct01 int64,
	target02 int, pct02 int64,
	target03 int, pct03 int64,
	target04 int, pct04 int64,
) {
	// First, cache the percentage of the staker just before it changes Callback if needed
	// (check if the LIQUIDITY_STAKER was located between target01 and 04)
	setDistributionBpsPct(target01, pct01)
	setDistributionBpsPct(target02, pct02)
	setDistributionBpsPct(target03, pct03)
	setDistributionBpsPct(target04, pct04)
}

// distributeToTarget distributes tokens according to configured percentages.
//
// Returns total amount distributed and any error.
func distributeToTarget(amount int64) (int64, error) {
	totalSent := int64(0)

	var err error

	distributionBpsPct.Iterate("", "", func(targetStr string, iPct any) bool {
		targetInt, distErr := strconv.Atoi(targetStr)
		if distErr != nil {
			err = distErr
			return true
		}

		pct, ok := iPct.(int64)
		if !ok {
			panic("failed to cast distributionBpsPct's element to int64")
		}

		distAmount := calculateAmount(amount, pct)

		// Skip zero amounts to avoid unnecessary transfers
		if distAmount == 0 {
			return false
		}

		totalSent += distAmount

		distErr = transferToTarget(targetInt, distAmount)
		if distErr != nil {
			err = distErr

			return true
		}

		return false
	})

	return totalSent, err
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

// transferToTarget sends tokens to the appropriate target address.
//
// Returns error if target address not found.
func transferToTarget(target int, amount int64) error {
	switch target {
	case LIQUIDITY_STAKER:
		stakerAddr, ok := access.GetAddress(prbac.ROLE_STAKER.String())
		if !ok {
			return makeErrorWithDetails(
				errDistributionAddressNotFound,
				ufmt.Sprintf("%s not found", prbac.ROLE_STAKER.String()),
			)
		}

		gns.Transfer(cross, stakerAddr, amount)
		distributedToStaker += amount
		accuDistributedToStaker += amount

	case DEVOPS:
		devOpsAddr, ok := access.GetAddress(prbac.ROLE_DEVOPS.String())
		if !ok {
			return makeErrorWithDetails(
				errDistributionAddressNotFound,
				ufmt.Sprintf("%s not found", prbac.ROLE_DEVOPS.String()),
			)
		}

		gns.Transfer(cross, devOpsAddr, amount)
		distributedToDevOps += amount
		accuDistributedToDevOps += amount

	case COMMUNITY_POOL:
		communityPoolAddr, ok := access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())
		if !ok {
			return makeErrorWithDetails(
				errDistributionAddressNotFound,
				ufmt.Sprintf("%s not found", prbac.ROLE_COMMUNITY_POOL.String()),
			)
		}

		gns.Transfer(cross, communityPoolAddr, amount)
		distributedToCommunityPool += amount
		accuDistributedToCommunityPool += amount

	case GOV_STAKER:
		govStakerAddr, ok := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
		if !ok {
			return makeErrorWithDetails(
				errDistributionAddressNotFound,
				ufmt.Sprintf("%s not found", prbac.ROLE_GOV_STAKER.String()),
			)
		}

		gns.Transfer(cross, govStakerAddr, amount)
		distributedToGovStaker += amount
		accuDistributedToGovStaker += amount

	default:
		return makeErrorWithDetails(
			errInvalidEmissionTarget,
			ufmt.Sprintf("invalid target(%d)", target),
		)
	}

	return nil
}

// GetDistributionBpsPct returns the distribution percentage in basis points for a specific target.
func GetDistributionBpsPct(target int) int64 {
	assertValidDistributionTarget(target)
	if distributionBpsPct == nil {
		panic("distributionBpsPct is nil")
	}

	iInt64, exist := distributionBpsPct.Get(strconv.Itoa(target))
	if !exist {
		panic(makeErrorWithDetails(
			errInvalidEmissionTarget,
			ufmt.Sprintf("invalid target(%d)", target),
		))
	}

	pct, ok := iInt64.(int64)
	if !ok {
		panic("failed to cast distributionBpsPct's element to int64")
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

// GetStakerEmissionAmountPerSecond returns the current per-second emission amount allocated to liquidity stakers.
func GetStakerEmissionAmountPerSecond() int64 {
	currentTimestamp := time.Now().Unix()
	return calculateAmount(gns.GetEmissionAmountPerSecondByTimestamp(currentTimestamp), GetDistributionBpsPct(LIQUIDITY_STAKER))
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
	caller := std.PreviousRealm().Address()
	access.AssertIsStaker(caller)

	distributedToStaker = 0
}

// ClearDistributedToGovStaker resets the pending distribution amount for governance stakers.
//
// Only callable by governance staker contract.
func ClearDistributedToGovStaker(cur realm) {
	caller := std.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)
	distributedToGovStaker = 0
}

// setDistributionBpsPct changes percentage of each target for how much GNS it will get by emission.
// Creates new AVL tree if nil.
func setDistributionBpsPct(target int, pct int64) {
	if distributionBpsPct == nil {
		distributionBpsPct = avl.NewTree()
	}

	distributionBpsPct.Set(strconv.Itoa(target), pct)
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
