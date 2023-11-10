package router

import (
	"strconv"
	"strings"

	p "gno.land/r/pool"

	"gno.land/p/demo/ufmt"
)

func findSwapPaths(
	inputTokenPath string,
	outputTokenPath string,
) (swapPaths SwapPaths) {
	tokenPairs := TokenPairs{}
	poolList := p.PoolGetPoolList()

	for i, poolPath := range poolList {
		token0Path, token1Path, pFee := poolPathWithFeeDivide(poolPath)

		{
			k := token0Path
			v := token1Path + ":" + strconv.Itoa(pFee)

			tokenPairs[k] = append(tokenPairs[k], v)
		}

		{
			k := token1Path
			v := token0Path + ":" + strconv.Itoa(pFee)

			tokenPairs[k] = append(tokenPairs[k], v)
		}
	}

	swapPaths = getSwapPaths(tokenPairs, inputTokenPath, outputTokenPath)
	return swapPaths
}

func getSwapPaths(
	tokenPairs TokenPairs,
	inputTokenPath string,
	outputTokenPath string,
) (swapPaths SwapPaths) {
	swapPaths = make(SwapPaths, 0)

	// check if there is path that starts with input
	require(len(tokenPairs[inputTokenPath]) != 0, ufmt.Sprintf("[ROUTER] find_path.gno__getSwapPaths() || len(tokenPairs[inputTokenPath]) == 0, inputTokenPath: %s", inputTokenPath))

	// find direct path
	for _, output := range tokenPairs[inputTokenPath] {
		if strings.HasPrefix(output, outputTokenPath) {
			outputPath, outputFee := singlePoolPathWithFeeDivide(output)
			directPath := inputTokenPath + "," + outputFee + "," + outputPath
			swapPaths[len(swapPaths)] = directPath // swapPaths = append(swapPaths, directPath)

			tokenPairs[inputTokenPath] = removeItemFromStringArray(tokenPairs[inputTokenPath], output)
		}
	}

	firstToken := ""
	findPath(tokenPairs, inputTokenPath, outputTokenPath, "", 2, &swapPaths, &firstToken)
	findPath(tokenPairs, inputTokenPath, outputTokenPath, "", 3, &swapPaths, &firstToken)

	return swapPaths
}

func findPath(
	tokenPairs TokenPairs,
	currentTokenPath string,
	outputTokenPath string,
	currentPath string,
	remainingHops int,
	swapPaths *SwapPaths,
	firstToken *string,
) {
	if *firstToken == "" {
		*firstToken = currentTokenPath
	}

	if remainingHops == 0 {
		if strings.HasPrefix(currentTokenPath, outputTokenPath) {
			swapPaths[len(*swapPaths)] = (*firstToken + "," + currentPath)
		}
		return
	}

	for _, next := range tokenPairs[currentTokenPath] {
		nextPath, nextFee := singlePoolPathWithFeeDivide(next)
		newPath := currentPath
		if currentPath != "" {
			newPath += ","
		}
		newPath += nextFee + "," + nextPath
		findPath(tokenPairs, nextPath, outputTokenPath, newPath, remainingHops-1, swapPaths, firstToken)
	}
}
