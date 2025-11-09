package fuzz

import (
	"strconv"
	"strings"

	"gno.land/p/gnoswap/fuzz"
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

func generateRandomTicks(f *fuzz.T, currentTick int32, feeTier uint32) (int32, int32) {
	tickSpacing := defaultTickSpacings[feeTier]

	tickLower := currentTick - (currentTick % tickSpacing)
	tickUpper := currentTick + (currentTick % tickSpacing)

	inRangeType := fuzz.IntRange(0, 2).Draw(f, "inRangeType").(int)

	migrateTick := func(tick int32, tickSpacing int32) int32 {
		left := tick % tickSpacing
		if tick >= 0 {
			return tick - left
		} else {
			return tick + tickSpacing - left
		}
	}

	maxTick := migrateTick(MAX_TICK, tickSpacing)
	minTick := migrateTick(MIN_TICK, tickSpacing)

	switch inRangeType {
	case 0:
		tickLower = fuzz.Int32Range(minTick, currentTick-tickSpacing).Draw(f, "tickLower").(int32)
		tickUpper = fuzz.Int32Range(tickLower, currentTick-tickSpacing).Draw(f, "tickUpper").(int32)
	case 1:
		tickLower = fuzz.Int32Range(minTick, currentTick-tickSpacing).Draw(f, "tickLower").(int32)
		tickUpper = fuzz.Int32Range(currentTick+tickSpacing, maxTick).Draw(f, "tickUpper").(int32)
	case 2:
		tickUpper = fuzz.Int32Range(currentTick+tickSpacing, maxTick).Draw(f, "tickUpper").(int32)
		tickLower = fuzz.Int32Range(currentTick+tickSpacing, tickUpper-tickSpacing).Draw(f, "tickLower").(int32)
	}
	tickLower = migrateTick(tickLower, tickSpacing)
	tickUpper = migrateTick(tickUpper, tickSpacing)

	if tickLower == tickUpper {
		tickUpper = tickLower + tickSpacing
	}

	return tickLower, tickUpper
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
