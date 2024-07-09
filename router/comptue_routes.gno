package router

import (
	"sort"

	pl "gno.land/r/gnoswap/pool"

	u256 "gno.land/p/gnoswap/uint256"
)

// PoolWithMeta is a struct that contains poolPath, token0Path, token1Path, fee, tokenPair, and liquidity
// It's used to store the pool information and sort the pools by liquidity
type PoolWithMeta struct {
	poolPath   string
	token0Path string
	token1Path string
	fee        int
	tokenPair  string
	liquidity  *u256.Uint
}
type ByLiquidity []PoolWithMeta

func (p ByLiquidity) Len() int           { return len(p) }
func (p ByLiquidity) Swap(i, j int)      { p[i], p[j] = p[j], p[i] }
func (p ByLiquidity) Less(i, j int) bool { return p[i].liquidity.Gt(p[j].liquidity) }

// BuildRoute is a struct that contains route, tokenIn, and tokenOut
// It's used to store the route information
type BuildRoute struct {
	route    []PoolWithMeta
	tokenIn  string
	tokenOut string
}

func computeAllRoutes(
	inputTokenPath string,
	outputTokenPath string,
	maxHops int,
	pools []PoolWithMeta,
) []BuildRoute {

	routes := _computeAllRoutes(
		inputTokenPath,
		outputTokenPath,
		[]BuildRoute{},
		pools,
		maxHops,
	)

	return routes
}

func _computeAllRoutes(
	inputTokenPath string,
	outputTokenPath string,
	buildRoute []BuildRoute, // BuildRoute
	pools []PoolWithMeta,
	maxHops int,
) []BuildRoute {
	poolUsed := make([]bool, len(pools))

	routes := []BuildRoute{}

	tokenVisited := make(map[string]bool, 0)
	tokenVisited[inputTokenPath] = true

	computeRoutes(
		inputTokenPath,
		outputTokenPath,
		[]PoolWithMeta{}, // currentRoute
		poolUsed,
		tokenVisited, // tokenVisited
		"",           // _previousTokenOut
		//
		maxHops,
		pools,
		//
		&routes,
	)

	return routes
}

func computeRoutes(
	inputTokenPath string,
	outputTokenPath string,
	currentRoute []PoolWithMeta,
	poolsUsed []bool,
	tokenVisited map[string]bool,
	_previousTokenOut string,
	maxHops int,
	pools []PoolWithMeta,
	routes *[]BuildRoute,
) *[]BuildRoute {

	routeLen := len(currentRoute)

	if routeLen > maxHops {
		return routes
	}

	if (routeLen > 0) && (currentRoute[routeLen-1].hasToken(outputTokenPath)) {
		buildRoute := BuildRoute{}
		buildRoute.route = append([]PoolWithMeta{}, currentRoute...)
		buildRoute.tokenIn = inputTokenPath
		buildRoute.tokenOut = outputTokenPath
		*routes = append(*routes, buildRoute)
		return routes
	}

	for i, pool := range pools {
		if poolsUsed[i] {
			continue
		}

		curPool := pool

		var previousTokenOut string
		if _previousTokenOut == "" { // first iteration
			previousTokenOut = inputTokenPath
		} else {
			previousTokenOut = _previousTokenOut
		}

		if !curPool.hasToken(previousTokenOut) {
			continue
		}

		var currentTokenOut string
		if curPool.token0Path == previousTokenOut {
			currentTokenOut = curPool.token1Path
		} else {
			currentTokenOut = curPool.token0Path
		}

		if tokenVisited[currentTokenOut] {
			continue
		}

		tokenVisited[currentTokenOut] = true
		currentRoute = append(currentRoute, curPool)
		poolsUsed[i] = true

		computeRoutes(
			inputTokenPath,
			outputTokenPath,
			currentRoute,
			poolsUsed,
			tokenVisited,
			currentTokenOut,
			//
			maxHops,
			pools,
			//
			routes,
		)

		poolsUsed[i] = false
		currentRoute = currentRoute[:len(currentRoute)-1]

		delete(tokenVisited, currentTokenOut)
	}

	return routes
}

func (pool PoolWithMeta) hasToken(token string) bool {
	return pool.token0Path == token || pool.token1Path == token
}

func findCandidatePools() []PoolWithMeta {
	poolList := pl.PoolGetPoolList()

	poolWithMetas := []PoolWithMeta{}
	for _, poolPath := range poolList {
		token0Path, token1Path, pFee := poolPathWithFeeDivide(poolPath)

		pool := pl.GetPoolFromPoolPath(poolPath)
		liquidity := pool.PoolGetLiquidity()
		poolWithMetas = append(poolWithMetas, PoolWithMeta{
			poolPath,
			token0Path,
			token1Path,
			pFee,
			token0Path + ":" + token1Path,
			liquidity,
		})
	}

	groupedPools := groupPoolsByTokenPair(poolWithMetas)
	top2ByGroup := selectTop2ByGroup(groupedPools)

	candidatePools := []PoolWithMeta{}
	for _, pools := range top2ByGroup {
		candidatePools = append(candidatePools, pools...)
	}

	return candidatePools
}

// group pools by tokenPair
func groupPoolsByTokenPair(pools []PoolWithMeta) map[string][]PoolWithMeta {
	groupedPools := make(map[string][]PoolWithMeta)

	for _, pool := range pools {
		groupedPools[pool.tokenPair] = append(groupedPools[pool.tokenPair], pool)
	}

	return groupedPools
}

// select the top 2 liquidity values per each group
func selectTop2ByGroup(groupedPools map[string][]PoolWithMeta) map[string][]PoolWithMeta {
	top2ByGroup := make(map[string][]PoolWithMeta)

	for tokenPair, pools := range groupedPools {
		// Use sort.Sort with ByLiquidity interface
		sort.Sort(ByLiquidity(pools))

		// Select the top 2 liquidity values
		top2 := pools[:min(2, len(pools))]
		top2ByGroup[tokenPair] = top2
	}

	return top2ByGroup
}
