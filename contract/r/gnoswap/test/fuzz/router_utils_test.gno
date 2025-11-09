package fuzz

import (
	"strings"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/pool"
)

func generateRoutePathArr(f *fuzz.T, inputTokenPath, outputTokenPath string, maxRoutePathCount int, maxHops int) string {
	routePathCount := fuzz.IntRange(1, maxRoutePathCount).Draw(f, "maxRoutePathCount").(int)

	routePathArr := []string{}

	for i := 0; i < routePathCount; i++ {
		routePathArr = append(routePathArr, generateRoutePath(f, inputTokenPath, outputTokenPath, maxHops))
	}

	return strings.Join(routePathArr, ",")
}

// generateRoutePath creates a random multi-hop routing path
// Ensures no duplicate token pairs are used across hops
func generateRoutePath(f *fuzz.T, inputTokenPath, outputTokenPath string, maxHops int) string {
	numHops := fuzz.IntRange(1, maxHops).Draw(f, "numHops").(int)

	if numHops == 1 {
		return generateSingleHop(f, inputTokenPath, outputTokenPath)
	}

	var route []string
	currentToken := inputTokenPath
	usedPairs := make(map[string]bool) // Track used token pairs

	for i := 0; i < numHops; i++ {
		var nextToken string
		if i == numHops-1 {
			// Last hop: current -> output
			nextToken = outputTokenPath

			// Check if last hop would create a duplicate pair
			lastPairKey := normalizeTokenPair(currentToken, nextToken)
			if usedPairs[lastPairKey] {
				// Duplicate detected at last hop, terminate route early
				break
			}
		} else {
			// Intermediate hop: current -> random intermediate token
			// Pass usedPairs to avoid duplicate pairs
			nextToken = generateIntermediateTokenWithPairs(f, currentToken, outputTokenPath, usedPairs)
			if nextToken == "" {
				// Fallback: if no valid intermediate token found, go directly to output
				nextToken = outputTokenPath

				// Check if this fallback creates a duplicate
				fallbackPairKey := normalizeTokenPair(currentToken, nextToken)
				if usedPairs[fallbackPairKey] {
					// Can't complete route without duplicates, terminate early
					break
				}
			}
		}

		// Mark this pair as used
		pairKey := normalizeTokenPair(currentToken, nextToken)
		usedPairs[pairKey] = true

		poolId := generatePoolIdentifier(f, currentToken, nextToken)
		route = append(route, poolId)
		currentToken = nextToken
	}

	return strings.Join(route, "*POOL*")
}

// normalizeTokenPair creates a normalized pair key for tracking used pairs
// Returns tokens in alphabetical order regardless of swap direction
func normalizeTokenPair(token0, token1 string) string {
	if strings.Compare(token0, token1) > 0 {
		return token1 + ":" + token0
	}
	return token0 + ":" + token1
}

// generateSingleHop creates a single hop pool identifier
func generateSingleHop(f *fuzz.T, token0Path, token1Path string) string {
	return generatePoolIdentifier(f, token0Path, token1Path)
}

// generatePoolIdentifier creates a pool identifier maintaining swap direction order
// Note: Token order follows swap direction (token0 -> token1), not alphabetical order
// This aligns with router's validateRoutePath policy
func generatePoolIdentifier(f *fuzz.T, token0Path, token1Path string) string {
	feeTier := generateFeeTier(f)
	return ufmt.Sprintf("%s:%s:%d", token0Path, token1Path, feeTier)
}

// generateIntermediateToken selects a random intermediate token for multi-hop routing
func generateIntermediateToken(f *fuzz.T, currentToken, targetToken string) string {
	availableTokens := make(map[string]bool)

	for token, _ := range defaultTokenPaths {
		if token != currentToken && token != targetToken {
			availableTokens[token] = true
		}
	}

	if len(availableTokens) == 0 {
		return ""
	}

	return generateTokenPathByList(f, availableTokens)
}

// generateIntermediateTokenWithPairs selects a random intermediate token that avoids creating duplicate token pairs
func generateIntermediateTokenWithPairs(f *fuzz.T, currentToken, targetToken string, usedPairs map[string]bool) string {
	availableTokens := make(map[string]bool)

	for token, _ := range defaultTokenPaths {
		if token == currentToken || token == targetToken {
			continue
		}

		// Check if this token would create a duplicate pair with currentToken
		pairKey := normalizeTokenPair(currentToken, token)
		if usedPairs[pairKey] {
			continue
		}

		availableTokens[token] = true
	}

	if len(availableTokens) == 0 {
		return ""
	}

	return generateTokenPathByList(f, availableTokens)
}

// generateRandomRoutePath creates a completely random routing path (for stress testing)
func generateRandomRoutePath(f *fuzz.T, maxHops int) string {
	inputToken := generateTokenPath(f)
	outputToken := generateTokenPath(f)

	for inputToken == outputToken {
		outputToken = generateTokenPath(f)
	}

	return generateRoutePath(f, inputToken, outputToken, maxHops)
}

func generateRouteQuoteArr(f *fuzz.T, pathCount int) string {
	if pathCount <= 0 {
		return ""
	}

	// Generate random percentages that sum to 100
	percentages := make([]int, pathCount)

	if pathCount == 1 {
		percentages[0] = 100
	} else {
		// Generate random values and normalize to sum to 100
		remaining := 100
		minPercentage := 10 // Minimum 10% per path

		for i := 0; i < pathCount-1; i++ {
			// Calculate max possible value for this iteration
			// Each remaining path needs at least minPercentage
			maxValue := remaining - (pathCount-i-1)*minPercentage

			if maxValue < minPercentage {
				maxValue = minPercentage
			}

			// Generate value in increments of 10
			numOptions := (maxValue-minPercentage)/10 + 1
			if numOptions <= 0 {
				numOptions = 1
			}

			randomIndex := fuzz.IntRange(0, numOptions-1).Draw(f, "percentageIndex").(int)
			value := minPercentage + randomIndex*10

			percentages[i] = value
			remaining -= value
		}

		// Last element gets the remaining percentage
		percentages[pathCount-1] = remaining

		// Sort in ascending order
		for i := 0; i < len(percentages)-1; i++ {
			for j := i + 1; j < len(percentages); j++ {
				if percentages[i] > percentages[j] {
					percentages[i], percentages[j] = percentages[j], percentages[i]
				}
			}
		}
	}

	// Convert to string array
	quoteArr := make([]string, pathCount)
	for i, pct := range percentages {
		quoteArr[i] = ufmt.Sprintf("%d", pct)
	}

	return strings.Join(quoteArr, ",")
}

// setupRouterMintPositionByRoutePath sets up a router pool and position for each route path.
func setupRouterMintPositionByRoutePath(ft *fuzz.T, routePathArr string) {
	routePaths := strings.Split(routePathArr, ",")
	for _, routePath := range routePaths {
		for _, routePool := range strings.Split(routePath, "*POOL*") {
			token0Path, token1Path, feeTier := parsePoolPathAlign(routePool)

			setupCreatePool(ft, token0Path, token1Path, feeTier)

			// generate parameters for position
			poolPath := pool.GetPoolPath(token0Path, token1Path, feeTier)
			tickLower, tickUpper := generateInRangeTick(ft, pool.GetSlot0Tick(poolPath), feeTier)
			amountDesired := int64(1_000_000_000_000)

			// setup position
			setupMintPosition(
				ft,
				token0Path,
				token1Path,
				feeTier,
				tickLower,
				tickUpper,
				amountDesired,
			)
		}
	}
}
