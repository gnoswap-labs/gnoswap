package emission

import (
	"chain"
	"chain/runtime"
	"math"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
)

const totalDistributionDuration = 12 * 365 * 24 * 60 * 60 // 12 years

var (
	// leftGNSAmount tracks undistributed GNS tokens from previous distributions
	leftGNSAmount int64

	// lastExecutedTimestamp stores the last timestamp when distribution was executed
	lastExecutedTimestamp int64

	// emissionAddr is the address of the emission realm
	emissionAddr = runtime.CurrentRealm().Address()

	// distributionStartTimestamp is the timestamp from which emission distribution starts
	// Default is 0, meaning distribution is not started until explicitly set
	distributionStartTimestamp int64

	// onDistributionPctChangeCallback is called when distribution percentages change
	// This allows external contracts (like staker) to update their caches
	onDistributionPctChangeCallback func(emissionAmountPerSecond int64)
)

// setLeftGNSAmount updates the undistributed GNS token amount
func setLeftGNSAmount(amount int64) {
	if amount < 0 {
		panic("left GNS amount cannot be negative")
	}

	leftGNSAmount = amount
}

// setLastExecutedTimestamp updates the timestamp of the last emission distribution execution.
func setLastExecutedTimestamp(timestamp int64) {
	if timestamp < 0 {
		panic("last executed timestamp cannot be negative")
	}

	lastExecutedTimestamp = timestamp
}

// MintAndDistributeGns mints and distributes GNS tokens according to the emission schedule.
//
// This function is called automatically by protocol contracts during user interactions
// to trigger periodic GNS emission. It mints new tokens based on elapsed time since
// last distribution and distributes them to predefined targets (staker, devops, etc.).
//
// Returns:
//   - int64: Total amount of GNS distributed in this call
//
// Note: Distribution only occurs if start timestamp is set and reached.
// Any undistributed tokens from previous calls are carried forward.
func MintAndDistributeGns(cur realm) (int64, bool) {
	if halt.IsHaltedEmission() {
		return 0, false
	}

	currentHeight := runtime.ChainHeight()
	currentTimestamp := time.Now().Unix()

	// Check if distribution start timestamp is set and if current timestamp has reached it
	// If distributionStartTimestamp is 0 (default), skip distribution to prevent immediate start
	// If current timestamp is below start timestamp, skip distribution
	if distributionStartTimestamp == 0 || currentTimestamp < distributionStartTimestamp {
		return 0, true
	}

	// Skip if we've already minted tokens at this timestamp
	lastMintedTimestamp := gns.LastMintedTimestamp()
	if currentTimestamp <= lastMintedTimestamp {
		return 0, true
	}

	// Additional check to prevent re-entrancy
	if lastExecutedTimestamp >= currentTimestamp {
		// Skip if we've already processed this height in emission
		return 0, true
	}

	// Mint new tokens and add any leftover amounts from previous distribution
	mintedEmissionRewardAmount := gns.MintGns(cross, emissionAddr)

	// Validate minted amount
	if mintedEmissionRewardAmount < 0 {
		panic("minted emission reward amount cannot be negative")
	}

	distributableAmount := mintedEmissionRewardAmount
	prevLeftAmount := GetLeftGNSAmount()

	if leftGNSAmount > 0 {
		// Check for overflow before addition
		if distributableAmount > math.MaxInt64-prevLeftAmount {
			panic("distributable amount would overflow")
		}

		distributableAmount += prevLeftAmount
		setLeftGNSAmount(0)
	}

	// Distribute tokens and track any undistributed amount
	distributedGNSAmount, err := distributeToTarget(distributableAmount)
	if err != nil {
		panic(err)
	}

	// Validate distribution arithmetic
	if distributedGNSAmount < 0 {
		panic("distributed amount cannot be negative")
	}

	if distributedGNSAmount > distributableAmount {
		panic("distributed amount cannot exceed distributable amount")
	}

	if distributableAmount != distributedGNSAmount {
		remainder := safeSubInt64(distributableAmount, distributedGNSAmount)
		if remainder < 0 {
			panic("remainder calculation error")
		}
		setLeftGNSAmount(remainder)
	}

	setLastExecutedTimestamp(currentTimestamp)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"MintAndDistributeGns",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lastTimestamp", formatInt(lastExecutedTimestamp),
		"currentTimestamp", formatInt(currentTimestamp),
		"currentHeight", formatInt(currentHeight),
		"mintedAmount", formatInt(mintedEmissionRewardAmount),
		"prevLeftAmount", formatInt(prevLeftAmount),
		"distributedAmount", formatInt(distributedGNSAmount),
		"currentLeftAmount", formatInt(GetLeftGNSAmount()),
		"gnsTotalSupply", formatInt(gns.TotalSupply()),
	)

	return distributedGNSAmount, true
}

// SetDistributionStartTime sets the timestamp when emission distribution starts.
//
// This function controls when GNS emission begins. Once set and reached, the protocol
// starts minting GNS tokens according to the emission schedule. The timestamp can only
// be set before distribution starts - it becomes immutable once active.
//
// Parameters:
//   - startTimestamp: Unix timestamp when emission should begin
//
// Requirements:
//   - Must be called before distribution starts (one-time setup)
//   - Timestamp must be in the future
//   - Cannot be negative
//
// Effects:
//   - Sets global distribution start time
//   - Initializes GNS emission state if not already started
//   - Emission begins automatically when timestamp is reached
//
// Only callable by admin or governance.
func SetDistributionStartTime(cur realm, startTimestamp int64) {
	halt.AssertIsNotHaltedEmission()
	halt.AssertIsNotHaltedWithdraw()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	if startTimestamp <= 0 {
		panic("distribution start timestamp must be positive")
	}

	if startTimestamp > math.MaxInt64-totalDistributionDuration {
		panic("distribution end timestamp must be before max int64 timestamp")
	}

	currentTimestamp := time.Now().Unix()

	// Must be in the future.
	if startTimestamp <= currentTimestamp {
		panic("distribution start timestamp must be greater than current timestamp")
	}

	// Cannot change after distribution started.
	if distributionStartTimestamp != 0 && distributionStartTimestamp <= currentTimestamp {
		panic("distribution has already started, cannot change start timestamp")
	}

	prevStartTimestamp := distributionStartTimestamp

	if gns.MintedEmissionAmount() == 0 {
		currentHeight := runtime.ChainHeight()
		gns.InitEmissionState(cross, currentHeight, startTimestamp)
	}

	distributionStartTimestamp = startTimestamp

	chain.Emit(
		"SetDistributionStartTime",
		"caller", caller.String(),
		"prevStartTimestamp", formatInt(prevStartTimestamp),
		"newStartTimestamp", formatInt(startTimestamp),
		"height", formatInt(runtime.ChainHeight()),
		"timestamp", formatInt(time.Now().Unix()),
	)
}

// SetOnDistributionPctChangeCallback sets a callback function to be called when distribution percentages change.
// This allows external contracts (like staker) to update their internal caches when governance changes emission rates.
//
// Only callable by the staker contract.
func SetOnDistributionPctChangeCallback(cur realm, callback func(int64)) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsStaker(caller)

	onDistributionPctChangeCallback = callback

	if onDistributionPctChangeCallback != nil {
		emissionAmountPerSecond := GetStakerEmissionAmountPerSecond()
		onDistributionPctChangeCallback(emissionAmountPerSecond)
	}
}
