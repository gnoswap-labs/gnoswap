package emission

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

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

// ChangeDistributionPct modifies the distribution percentages for GNS emission targets.
//
// This function allows administrators or governance to adjust how newly minted GNS tokens
// are distributed among different protocol components. All four targets must be specified
// and percentages must sum to exactly 10000 basis points (100%).
//
// Parameters:
//   - cur realm: Current execution context realm
//   - target01-04: Distribution target identifiers (LIQUIDITY_STAKER=1, DEVOPS=2, COMMUNITY_POOL=3, GOV_STAKER=4)
//   - pct01-04: Percentage in basis points (1 bp = 0.01%, 10000 bp = 100%)
//
// Requirements:
//   - Caller must be admin or governance
//   - All targets must be valid (1-4)
//   - No duplicate targets
//   - Sum of all percentages must equal 10000
//   - System must not be halted for emission
//
// Panics:
//   - Caller is not admin or governance
//   - Invalid target specified
//   - Duplicate targets provided
//   - Percentages don't sum to 10000
//   - System is halted
//
// Events:
//
//	Emits ChangeDistributionPct event with all target and percentage details
//
// Example:
//
//	// Set distribution: 75% stakers, 20% devops, 5% community, 0% gov stakers
//	ChangeDistributionPct(
//	  LIQUIDITY_STAKER, 7500,
//	  DEVOPS, 2000,
//	  COMMUNITY_POOL, 500,
//	  GOV_STAKER, 0
//	)
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

// distributeToTarget splits an amount according to the configured percentages
// and sends tokens to each target address. Returns the total amount distributed.
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

// calculateAmount converts a basis point percentage to actual token amount
// bptPct is in basis points (1/100th of 1%)
// Example: 7500 basis points = 75%
func calculateAmount(amount, bptPct int64) int64 {
	if amount < 0 || bptPct < 0 || bptPct > 10000 {
		panic("invalid amount or bptPct")
	}

	// prevent multiplication overflow
	if amount > 9223372036854775807/10000 {
		panic("amount too large")
	}

	return amount * bptPct / 10000
}

// transferToTarget sends tokens to the appropriate address based on target type
// and updates both current and accumulated distribution tracking
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

// GetDistributionBpsPct returns the distribution percentage for a specific target.
//
// Parameters:
//   - target: Distribution target identifier (1-4)
//
// Returns:
//   - int64: Percentage in basis points (1 bp = 0.01%)
//
// Panics:
//   - Invalid target specified
//   - Target not found in distribution tree
//
// Example:
//
//	pct := GetDistributionBpsPct(LIQUIDITY_STAKER)
//	// pct = 7500 (75%)
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

// GetDistributedToStaker returns the amount of GNS distributed to liquidity stakers since last clear.
//
// This value accumulates until cleared by the staker contract when it processes
// the distributed rewards. Used for tracking pending distributions.
//
// Returns:
//   - int64: GNS amount distributed but not yet processed
func GetDistributedToStaker() int64 {
	return distributedToStaker
}

// GetDistributedToDevOps returns the amount of GNS distributed to DevOps address.
//
// This value accumulates continuously as it's not cleared by any contract.
// Represents the current unclaimed DevOps rewards.
//
// Returns:
//   - int64: GNS amount distributed to DevOps
func GetDistributedToDevOps() int64 {
	return distributedToDevOps
}

// GetDistributedToCommunityPool returns the amount of GNS distributed to Community Pool.
//
// This value accumulates continuously as it's not cleared by any contract.
// Represents the total community pool holdings from emissions.
//
// Returns:
//   - int64: GNS amount distributed to Community Pool
func GetDistributedToCommunityPool() int64 {
	return distributedToCommunityPool
}

// GetDistributedToGovStaker returns the amount of GNS distributed to governance stakers since last clear.
//
// This value accumulates until cleared by the governance staker contract when it
// processes the distributed rewards. Used for tracking pending distributions.
//
// Returns:
//   - int64: GNS amount distributed but not yet processed
func GetDistributedToGovStaker() int64 {
	return distributedToGovStaker
}

// GetAccuDistributedToStaker returns the total historical GNS distributed to liquidity stakers.
//
// This is a cumulative value that never resets, providing a complete historical
// record of all emissions to liquidity stakers.
//
// Returns:
//   - int64: Total GNS ever distributed to stakers
func GetAccuDistributedToStaker() int64 {
	return accuDistributedToStaker
}

// GetAccuDistributedToDevOps returns the total historical GNS distributed to DevOps.
//
// This is a cumulative value that never resets, providing a complete historical
// record of all emissions to the DevOps address.
//
// Returns:
//   - int64: Total GNS ever distributed to DevOps
func GetAccuDistributedToDevOps() int64 {
	return accuDistributedToDevOps
}

// GetAccuDistributedToCommunityPool returns the total historical GNS distributed to Community Pool.
//
// This is a cumulative value that never resets, providing a complete historical
// record of all emissions to the Community Pool.
//
// Returns:
//   - int64: Total GNS ever distributed to Community Pool
func GetAccuDistributedToCommunityPool() int64 {
	return accuDistributedToCommunityPool
}

// GetAccuDistributedToGovStaker returns the total historical GNS distributed to governance stakers.
//
// This is a cumulative value that never resets, providing a complete historical
// record of all emissions to governance stakers.
//
// Returns:
//   - int64: Total GNS ever distributed to governance stakers
func GetAccuDistributedToGovStaker() int64 {
	return accuDistributedToGovStaker
}

func GetStakerEmissionAmountPerSecond() int64 {
	currentTimestamp := time.Now().Unix()
	return calculateAmount(gns.GetEmissionAmountPerSecondByTimestamp(currentTimestamp), GetDistributionBpsPct(LIQUIDITY_STAKER))
}

// GetStakerEmissionAmountPerSecondInRange returns emission amounts allocated to liquidity stakers for a time range.
//
// This function calculates the portion of total emissions that should go to liquidity stakers
// based on the current distribution percentage. It handles halving transitions within the
// specified time range.
//
// Parameters:
//   - start: Start timestamp (inclusive)
//   - end: End timestamp (inclusive)
//
// Returns:
//   - []int64: Array of timestamps when emission rate changes (halving points)
//   - []int64: Array of emission amounts per second for stakers at each period
//
// Note:
//
//	When distribution percentages change, the staker contract flushes pending rewards first,
//	ensuring this function can use current percentages for historical calculations.
//
// Example:
//
//	times, amounts := GetStakerEmissionAmountPerSecondInRange(startTime, endTime)
//	// times[0] = 1234567890, amounts[0] = 5345674 (75% of 7127566 GNS/second)
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
// This function is called by the staker contract after it has processed and distributed
// the pending rewards to individual stakers. Only the staker contract can call this.
//
// Parameters:
//   - cur realm: Current execution context realm
//
// Panics:
//   - Caller is not the staker contract
//
// Note:
//
//	This only clears the pending amount, not the historical accumulated amount.
func ClearDistributedToStaker(cur realm) {
	caller := std.PreviousRealm().Address()
	access.AssertIsStaker(caller)

	distributedToStaker = 0
}

// ClearDistributedToGovStaker resets the pending distribution amount for governance stakers.
//
// This function is called by the governance staker contract after it has processed
// and distributed the pending rewards to individual stakers. Only the governance
// staker contract can call this.
//
// Parameters:
//   - cur realm: Current execution context realm
//
// Panics:
//   - Caller is not the governance staker contract
//
// Note:
//
//	This only clears the pending amount, not the historical accumulated amount.
func ClearDistributedToGovStaker(cur realm) {
	caller := std.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)

	distributedToGovStaker = 0
}

// setDistributionBpsPct changes percentage of each target for how much gns it will get by emission.
func setDistributionBpsPct(target int, pct int64) {
	if distributionBpsPct == nil {
		distributionBpsPct = avl.NewTree()
	}

	distributionBpsPct.Set(strconv.Itoa(target), pct)
}

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
