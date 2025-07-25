package emission

import (
	"std"
	"time"

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
)

// MintAndDistributeGns mints new GNS tokens and distributes them to targets
// Returns the total amount of GNS distributed
func MintAndDistributeGns(cur realm) int64 {
	halt.AssertIsNotHaltedEmission()

	currentHeight := std.ChainHeight()
	lastMintedHeight := gns.LastMintedHeight()
	if lastMintedHeight >= currentHeight {
		// Skip if we've already minted tokens at this height
		return 0
	}

	// Mint new tokens and add any leftover amounts from previous distribution
	mintedEmissionRewardAmount := gns.MintGns(cross, emissionAddr)

	distributableAmount := mintedEmissionRewardAmount
	prevLeftAmount := GetLeftGNSAmount()
	if hasLeftGNSAmount() {
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

// GetLeftGNSAmount returns the amount of undistributed GNS tokens
func GetLeftGNSAmount() int64 {
	return leftGNSAmount
}

// setLeftGNSAmount updates the undistributed GNS token amount
func setLeftGNSAmount(amount int64) {
	leftGNSAmount = amount
}

// GetLastExecutedHeight returns the last block height when distribution was executed
func GetLastExecutedHeight() int64 {
	return lastExecutedHeight
}

// setLastExecutedHeight updates the last executed block height
func setLastExecutedHeight(height int64) {
	lastExecutedHeight = height
}

// hasLeftGNSAmount checks if there are any undistributed GNS tokens
func hasLeftGNSAmount() bool {
	return leftGNSAmount > 0
}
