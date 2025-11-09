package fuzz

import (
	"strconv"
	"strings"
	"testing"
	"time"

	"gno.land/p/gnoswap/fuzz"
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// Generate methods
func generateTokenPath(f *fuzz.T) string {
	return generateTokenPathByList(f, defaultTokenPaths)
}

func generateTokenPair(f *fuzz.T) (string, string) {
	token0Path := generateTokenPath(f)

	currentTokenPaths := make(map[string]bool)
	for tokenPath, _ := range defaultTokenPaths {
		if tokenPath != token0Path {
			currentTokenPaths[tokenPath] = true
		}
	}

	token1Path := generateTokenPathByList(f, currentTokenPaths)

	return token0Path, token1Path
}

// Generate methods
func generateTokenPathByList(f *fuzz.T, tokenPaths map[string]bool) string {
	tokenPathIndex := fuzz.IntRange(0, len(tokenPaths)-1).Draw(f, "tokenPath").(int)

	currentIndex := 0
	for tokenPath, _ := range tokenPaths {
		if currentIndex == tokenPathIndex {
			return tokenPath
		}

		currentIndex++
	}

	return ""
}

func generateFeeTier(f *fuzz.T) uint32 {
	feeTierIndex := fuzz.IntRange(0, len(defaultFeeTiers)-1).Draw(f, "feeTier").(int)
	return defaultFeeTiers[feeTierIndex]
}

func generateTick(f *fuzz.T) int32 {
	return generateTickRangeWithFeeTier(f, MIN_TICK, MAX_TICK, 100)
}

func generateTickWithFeeTier(f *fuzz.T, feeTier uint32) int32 {
	return generateTickRangeWithFeeTier(f, MIN_TICK, MAX_TICK, feeTier)
}

func generateTickRangeWithFeeTier(f *fuzz.T, minTick, maxTick int32, feeTier uint32) int32 {
	tickSpacing := defaultTickSpacings[feeTier]
	tick := fuzz.Int32Range(minTick, maxTick).Draw(f, "tick").(int32)

	left := tick % tickSpacing

	if tick >= 0 {
		tick = tick - left
	} else {
		tick = tick + tickSpacing - left
	}

	if tick >= maxTick {
		tick = maxTick - tickSpacing
	}

	return tick
}

func generateInRangeTick(f *fuzz.T, currentTick int32, feeTier uint32) (int32, int32) {
	tickSpacing := defaultTickSpacings[feeTier]
	currentTick = currentTick - (currentTick % tickSpacing)

	tickLowerDiff := fuzz.Int32Range(1, 1000).Draw(f, "tickLowerDiff").(int32) * tickSpacing
	tickUpperDiff := fuzz.Int32Range(1, 1000).Draw(f, "tickLowerDiff").(int32) * tickSpacing

	tickLower := currentTick - tickLowerDiff
	tickUpper := currentTick + tickUpperDiff

	return tickLower, tickUpper
}

func parsePoolPath(poolPath string) (string, string, uint32) {
	parts := strings.Split(poolPath, ":")
	if len(parts) != 3 {
		return "", "", 0
	}

	result, err := strconv.ParseUint(parts[2], 10, 32)
	if err != nil {
		return "", "", 0
	}

	return parts[0], parts[1], uint32(result)
}

func parsePoolPathAlign(poolPath string) (string, string, uint32) {
	token0Path, token1Path, feeTier := parsePoolPath(poolPath)
	if strings.Compare(token0Path, token1Path) > 0 {
		return token1Path, token0Path, feeTier
	}

	return token0Path, token1Path, feeTier
}

// setupCreatePool creates a pool if it doesn't exist and sets the realm to the admin realm.
func setupCreatePool(
	ft *fuzz.T,
	token0Path string,
	token1Path string,
	feeTier uint32,
) string {
	poolPath := pool.GetPoolPath(token0Path, token1Path, feeTier)
	if !pool.ExistsPoolPath(poolPath) {
		testing.SetRealm(testing.NewUserRealm(adminAddr))

		currentTick := fuzz.Int32Range(-10000, 10000).Draw(ft, "currentTick").(int32)
		startPrice := common.TickMathGetSqrtRatioAtTick(currentTick)
		pool.CreatePool(
			cross,
			token0Path,
			token1Path,
			feeTier,
			startPrice.ToString(),
		)
	}

	return poolPath
}

// setupMintPosition mints a position and sets the realm to the admin realm.
func setupMintPosition(
	ft *fuzz.T,
	token0Path string,
	token1Path string,
	feeTier uint32,
	tickLower int32,
	tickUpper int32,
	amountDesired int64,
) (uint64, string, string, string) {
	mintTestToken(token0Path, amountDesired)
	mintTestToken(token1Path, amountDesired)

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	poolAddr := access.MustGetAddress(prabc.ROLE_POOL.String())
	common.SafeGRC20Approve(cross, token0Path, poolAddr, amountDesired)
	common.SafeGRC20Approve(cross, token1Path, poolAddr, amountDesired)

	return position.Mint(
		cross,
		token0Path,
		token1Path,
		feeTier,
		tickLower,
		tickUpper,
		ufmt.Sprintf("%d", amountDesired),
		ufmt.Sprintf("%d", amountDesired),
		"0",
		"0",
		time.Now().Add(time.Hour).Unix(),
		adminAddr,
		adminAddr,
		"",
	)
}
