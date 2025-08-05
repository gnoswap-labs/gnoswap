package emission

import (
	"std"
	"time"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/halt"
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

// GetLeftGNSAmount returns the amount of undistributed GNS tokens
func GetLeftGNSAmount() int64 { return leftGNSAmount }

// GetDistributionStartBlockHeight returns the block height from which emission distribution starts
func GetDistributionStartTimestamp() int64 { return distributionStartTimestamp }

// setLeftGNSAmount updates the undistributed GNS token amount
func setLeftGNSAmount(amount int64) { leftGNSAmount = amount }

// GetLastExecutedTimestamp returns the last timestamp when distribution was executed
func GetLastExecutedTimestamp() int64 { return lastExecutedTimestamp }

// setLastExecutedTimestamp updates the last executed timestamp
func setLastExecutedTimestamp(timestamp int64) { lastExecutedTimestamp = timestamp }

// MintAndDistributeGns mints new GNS tokens according to the emission schedule and distributes them to target modules.
//
// This function is called by external systems (e.g., cron jobs) to trigger periodic GNS emission.
// It handles the minting process based on the halving schedule, manages any undistributed amounts
// from previous distributions, and distributes tokens to staking and governance modules.
//
// Parameters:
//   - cur realm: Current execution context realm
//
// Returns:
//   - int64: Total amount of GNS tokens distributed in this execution
//
// Behavior:
//   - Checks if distribution has started (distributionStartTimestamp > 0)
//   - Skips if already minted for current timestamp
//   - Mints new tokens based on time elapsed and halving schedule
//   - Adds any leftover amounts from previous distributions
//   - Distributes to target modules (staking, governance)
//   - Stores any undistributed amount for next execution
//
// Panics:
//   - System is halted for emission or withdrawal
//   - Distribution error occurs
//
// Events:
//   Emits MintAndDistributeGns event with distribution details
//
// Example:
//   // Called by external system every block or periodically
//   distributed := MintAndDistributeGns()
//   // distributed = 1000000 (1 GNS distributed)
func MintAndDistributeGns(cur realm) int64 {
	halt.AssertIsNotHaltedEmission()
	halt.AssertIsNotHaltedWithdraw()

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

// SetDistributionStartTime configures when GNS emission distribution should begin.
//
// This function sets the timestamp from which the emission schedule starts. It must be
// called before any emissions can occur. Once distribution has started, the timestamp
// cannot be changed. This ensures the integrity of the emission schedule.
//
// Parameters:
//   - cur realm: Current execution context realm
//   - startTimestamp: Unix timestamp when distribution should start
//
// Requirements:
//   - Caller must be admin or governance
//   - startTimestamp must be positive
//   - startTimestamp must be in the future
//   - Cannot change after distribution has started
//
// Panics:
//   - System is halted for emission or withdrawal
//   - Caller is not admin or governance
//   - startTimestamp is negative
//   - startTimestamp is in the past
//   - Distribution has already started
//
// Events:
//   Emits SetDistributionStartTime event with configuration details
//
// Example:
//   // Set distribution to start at specific timestamp
//   futureTime := time.Now().Unix() + 86400 // 24 hours from now
//   SetDistributionStartTime(futureTime)
//
// Note:
//   If no emissions have occurred yet, this also reinitializes the emission
//   state to adjust halving year calculations based on the new start time.
func SetDistributionStartTime(cur realm, startTimestamp int64) {
	halt.AssertIsNotHaltedEmission()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	// this check will also prevent the overflow of int64 value
	if startTimestamp < 0 {
		panic("distribution start timestamp cannot be negative")
	}

	currentTimestamp := time.Now().Unix()

	// Prevent changing start height after distribution has already started
	if distributionStartTimestamp != 0 && distributionStartTimestamp <= currentTimestamp {
		panic("distribution has already started, cannot change start timestamp")
	}

	// Prevent setting distribution start height to a past block
	if startTimestamp > 0 && startTimestamp <= currentTimestamp {
		panic("distribution start timestamp must be greater than current timestamp")
	}

	prevStartTimestamp := distributionStartTimestamp

	// If setting a future start height and no emission has occurred yet,
	// reinitialize the emission state to adjust halving years
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
