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
	// lastExecutedHeight stores the last block height when distribution was executed
	lastExecutedHeight int64

	// emissionAddr is the address of the emission realm
	emissionAddr = std.CurrentRealm().Address()

	// distributionStartBlockHeight is the block height from which emission distribution starts
	// Default is 0, meaning distribution is not started until explicitly set
	distributionStartBlockHeight int64
)

// GetLeftGNSAmount returns the amount of undistributed GNS tokens
func GetLeftGNSAmount() int64 { return leftGNSAmount }

// GetDistributionStartBlockHeight returns the block height from which emission distribution starts
func GetDistributionStartBlockHeight() int64 { return distributionStartBlockHeight }

// setLeftGNSAmount updates the undistributed GNS token amount
func setLeftGNSAmount(amount int64) { leftGNSAmount = amount }

// GetLastExecutedHeight returns the last block height when distribution was executed
func GetLastExecutedHeight() int64 { return lastExecutedHeight }

// setLastExecutedHeight updates the last executed block height
func setLastExecutedHeight(height int64) { lastExecutedHeight = height }

// MintAndDistributeGns mints new GNS tokens and distributes them to targets
// Returns the total amount of GNS distributed
func MintAndDistributeGns(cur realm) int64 {
	halt.AssertIsNotHaltedEmission()

	currentHeight := std.ChainHeight()

	// Check if distribution start block height is set and if current height has reached it
	// and skip emission distribution if not started or below start height
	if currentHeight < distributionStartBlockHeight {
		return 0
	}

	lastMintedHeight := gns.LastMintedHeight()
	if lastMintedHeight >= currentHeight {
		// Skip if we've already minted tokens at this height
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
	distributedGNSAmount, err := distributeToTarget(cur, distributableAmount)
	if err != nil {
		panic(err)
	}

	if distributableAmount != distributedGNSAmount {
		setLeftGNSAmount(distributableAmount - distributedGNSAmount)
	}

	// Emit event with distribution details
	previousRealm := std.PreviousRealm()
	std.Emit(
		"MintAndDistributeGns",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lastHeight", formatInt(lastExecutedHeight),
		"currentHeight", formatInt(currentHeight),
		"currentTimestamp", formatInt(time.Now().Unix()),
		"mintedAmount", formatInt(mintedEmissionRewardAmount),
		"prevLeftAmount", formatInt(prevLeftAmount),
		"distributedAmount", formatInt(distributedGNSAmount),
		"currentLeftAmount", formatInt(GetLeftGNSAmount()),
		"gnsTotalSupply", formatInt(gns.TotalSupply()),
	)

	setLastExecutedHeight(currentHeight)

	return distributedGNSAmount
}

// SetDistributionStartBlockHeight sets the block height from which emission distribution starts
// Only admin or governance can call this function
func SetDistributionStartBlockHeight(cur realm, height int64) {
	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	// this check will also prevent the overflow of int64 value
	if height < 0 {
		panic("distribution start block height cannot be negative")
	}

	oldHeight := distributionStartBlockHeight
	distributionStartBlockHeight = height

	std.Emit(
		"SetDistributionStartBlockHeight",
		"caller", caller.String(),
		"oldHeight", formatInt(oldHeight),
		"newHeight", formatInt(height),
		"currentChainHeight", formatInt(std.ChainHeight()),
	)
}
