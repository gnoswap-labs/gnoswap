package fuzz

import (
	"testing"
	"time"

	"gno.land/p/gnoswap/fuzz"
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/staker"
	"gno.land/r/onbloc/obl"
)

func generateInternalIncentiveTierByRange(ft *fuzz.T, minTier uint64, maxTier uint64) uint64 {
	return fuzz.Uint64Range(minTier, maxTier).Draw(ft, "poolTier").(uint64)
}

func setupInternalIncentivePoolAndPosition(ft *fuzz.T) (string, uint64, uint64) {
	return setupInternalIncentivePoolAndPositionByRange(ft, 0, 3)
}

func setupInternalIncentivePoolAndPositionByRange(ft *fuzz.T, minTier uint64, maxTier uint64) (string, uint64, uint64) {
	poolPath, internalIncentiveTier := setupInternalIncentivePoolByRange(ft, minTier, maxTier)
	token0Path, token1Path, feeTier := parsePoolPathAlign(poolPath)
	tickLower, tickUpper := generateInRangeTick(ft, pool.GetSlot0Tick(poolPath), feeTier)
	amountDesired := int64(1_000_000_000_000)
	positionID, _, _, _ := setupMintPosition(ft, token0Path, token1Path, feeTier, tickLower, tickUpper, amountDesired)

	return poolPath, internalIncentiveTier, positionID
}

// setupInternalIncentivePool sets up a router pool and position for each route path.
func setupInternalIncentivePoolByRange(ft *fuzz.T, minTier uint64, maxTier uint64) (string, uint64) {
	token0Path, token1Path := generateTokenPair(ft)
	feeTier := generateFeeTier(ft)
	poolPath := setupCreatePool(ft, token0Path, token1Path, feeTier)

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	internalIncentiveTier := generateInternalIncentiveTierByRange(ft, minTier, maxTier)
	staker.SetPoolTier(cross, poolPath, internalIncentiveTier)

	return poolPath, internalIncentiveTier
}

func setupExternalRewardPoolAndPosition(ft *fuzz.T) (string, string, uint64) {
	poolPath, incentiveID := setupExternalRewardPool(ft)
	token0Path, token1Path, feeTier := parsePoolPathAlign(poolPath)
	tickLower, tickUpper := generateInRangeTick(ft, pool.GetSlot0Tick(poolPath), feeTier)
	amountDesired := int64(1_000_000)
	positionID, _, _, _ := setupMintPosition(ft, token0Path, token1Path, feeTier, tickLower, tickUpper, amountDesired)

	return poolPath, incentiveID, positionID
}

// setupExternalRewardPool sets up a router pool and position for each route path.
func setupExternalRewardPool(ft *fuzz.T) (string, string) {
	token0Path, token1Path := generateTokenPair(ft)
	feeTier := generateFeeTier(ft)
	poolPath := setupCreatePool(ft, token0Path, token1Path, feeTier)
	incentivizeAmount := int64(1_000_000_000)

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	mintTestToken(oblPath, incentivizeAmount)

	stakerAddr := access.MustGetAddress(prabc.ROLE_STAKER.String())
	obl.Approve(cross, stakerAddr, incentivizeAmount)
	incentiveStartTimestamp := time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour).Unix()
	incentiveEndTimestamp := incentiveStartTimestamp + 180*24*60*60

	staker.CreateExternalIncentive(
		cross,
		poolPath,
		oblPath,
		incentivizeAmount,
		incentiveStartTimestamp,
		incentiveEndTimestamp,
	)

	incentiveID := ufmt.Sprintf("%s:%d:%d", adminAddr, time.Now().Unix(), defaultStakerStore.incentiveCounter.Get())

	return poolPath, incentiveID
}

func setupStakePosition(ft *fuzz.T, positionID uint64) uint64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	staker.StakeToken(cross, positionID, "")

	return positionID
}
