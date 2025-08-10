package emission

import (
	"std"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
)

var (
	// leftGNSAmount tracks undistributed GNS tokens from previous distributions
	leftGNSAmount int64
	// lastExecutedTimestamp stores the last timestamp when distribution was executed
	lastExecutedTimestamp int64

	// emissionAddr is the address of the emission realm
	emissionAddr = std.CurrentRealm().Address()

	// distributionStartTimestamp is the timestamp from which emission distribution starts
	// Default is 0, meaning distribution is not started until explicitly set
	distributionStartTimestamp int64
)

// GetLeftGNSAmount returns the amount of undistributed GNS tokens from previous distributions.
func GetLeftGNSAmount() int64 { return leftGNSAmount }

// GetDistributionStartTimestamp returns the timestamp when emission distribution started.
// Returns 0 if distribution has not been started yet.
func GetDistributionStartTimestamp() int64 { return distributionStartTimestamp }

// setLeftGNSAmount updates the amount of undistributed GNS tokens.
func setLeftGNSAmount(amount int64) { leftGNSAmount = amount }

// GetLastExecutedTimestamp returns the timestamp of the last emission distribution execution.
func GetLastExecutedTimestamp() int64 { return lastExecutedTimestamp }

// setLastExecutedTimestamp updates the timestamp of the last emission distribution execution.
func setLastExecutedTimestamp(timestamp int64) { lastExecutedTimestamp = timestamp }

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
func MintAndDistributeGns(cur realm) int64 {
	halt.AssertIsNotHaltedEmission()

	currentHeight := std.ChainHeight()
	currentTimestamp := time.Now().Unix()

	// Check if distribution start timestamp is set and if current timestamp has reached it
	// If distributionStartTimestamp is 0 (default), skip distribution to prevent immediate start
	// If current timestamp is below start timestamp, skip distribution
	if distributionStartTimestamp == 0 || currentTimestamp < distributionStartTimestamp {
		return 0
	}

	// Skip if we've already minted tokens at this timestamp
	lastMintedTimestamp := gns.LastMintedTimestamp()
	if currentTimestamp <= lastMintedTimestamp {
		return 0
	}

	// Mint new tokens and add any leftover amounts from previous distribution
	mintedEmissionRewardAmount := gns.MintGns(cross, emissionAddr)

	distributableAmount := mintedEmissionRewardAmount
	prevLeftAmount := GetLeftGNSAmount()
	if leftGNSAmount > 0 {
		distributableAmount += prevLeftAmount
		setLeftGNSAmount(0)
	}
	// Distribute tokens and track any undistributed amount
	distributedGNSAmount, err := distributeToTarget(distributableAmount)
	if err != nil {
		panic(err)
	}

	if distributableAmount != distributedGNSAmount {
		setLeftGNSAmount(distributableAmount - distributedGNSAmount)
	}

	setLastExecutedTimestamp(currentTimestamp)

	previousRealm := std.PreviousRealm()
	std.Emit(
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

	return distributedGNSAmount
}

// SetDistributionStartTime sets the timestamp when emission distribution starts.
//
// Parameters:
//   - startTimestamp: unix timestamp for distribution start
//
// Only callable by admin or governance.
func SetDistributionStartTime(cur realm, startTimestamp int64) {
	halt.AssertIsNotHaltedEmission()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	// Prevent negative timestamps.
	if startTimestamp < 0 {
		panic("distribution start timestamp cannot be negative")
	}

	currentTimestamp := time.Now().Unix()

	// Cannot change after distribution started.
	if distributionStartTimestamp != 0 && distributionStartTimestamp <= currentTimestamp {
		panic("distribution has already started, cannot change start timestamp")
	}

	// Must be in the future.
	if startTimestamp > 0 && startTimestamp <= currentTimestamp {
		panic("distribution start timestamp must be greater than current timestamp")
	}

	prevStartTimestamp := distributionStartTimestamp

	// Reinitialize emission state if not started yet.
	if startTimestamp > currentTimestamp && gns.MintedEmissionAmount() == 0 {
		gns.InitEmissionState(cross, startTimestamp, startTimestamp)
	}

	distributionStartTimestamp = startTimestamp

	std.Emit(
		"SetDistributionStartTime",
		"caller", caller.String(),
		"prevStartTimestamp", formatInt(prevStartTimestamp),
		"newStartTimestamp", formatInt(startTimestamp),
		"height", formatInt(std.ChainHeight()),
		"timestamp", formatInt(time.Now().Unix()),
	)
}
